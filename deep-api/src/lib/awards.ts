// The DB half of the award engine: grantAward runs one serialized, atomic
// transaction per grant (ledger row + tally + wallet + plant sunlight), and
// walletSummary assembles the wallet shape routes return. The pure rules it
// applies live in lib/awardRules.ts.
import { Prisma, type AwardKind } from "@prisma/client";
import { prisma } from "../prisma.js";
import { DAILY_HEARTS_CAP, decideAward, type CapReason } from "./awardRules.js";
import { resolveNow } from "./pauseSchedule.js";

export interface GrantAwardInput {
  userId: string;
  kind: AwardKind;
  /** The day the award is keyed on: user-local day, or pauseDate for pause kinds. */
  dayKey: string;
  /**
   * The user-local day whose tally (and 30-hearts cap) the grant counts
   * against. Defaults to `dayKey`; pause kinds pass it separately because
   * their dayKey is the global Bangkok pauseDate.
   */
  tallyDayKey?: string;
  /** sessionId | trackId; omitted kinds store "" (null would break the unique). */
  sourceId?: string;
  /** The IANA timezone the dayKey was computed in, recorded on the ledger row. */
  timezone: string;
}

export interface AwardOutcome {
  kind: AwardKind;
  granted: boolean;
  hearts: number;
  sunlight: number;
  plantId: string | null;
  cappedBy: CapReason | null;
}

// A unique-violation aborts the underlying Postgres transaction, so the
// duplicate outcome has to travel out through a rollback rather than a return.
class DuplicateAwardSignal extends Error {
  constructor(public readonly plantId: string | null) {
    super("award already granted");
    this.name = "DuplicateAwardSignal";
  }
}

/**
 * The plant the sunlight credits: the user's selected plant, else the first
 * active, non-premium default by displayOrder — persisted as the selection
 * (with a progress row) so the lazy assignment sticks. Null when the catalog
 * has no eligible plant (hearts still grant; sunlight has nowhere to land).
 */
async function resolveCreditPlant(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<string | null> {
  const user = await tx.user.findUnique({
    where: { id: userId },
    select: { selectedPlantId: true },
  });
  if (user?.selectedPlantId) return user.selectedPlantId;

  const fallback = await tx.plant.findFirst({
    where: { isActive: true, isDefault: true, isPremium: false },
    orderBy: { displayOrder: "asc" },
    select: { id: true },
  });
  if (!fallback) return null;

  await tx.user.update({
    where: { id: userId },
    data: { selectedPlantId: fallback.id },
  });
  await tx.userPlantProgress.upsert({
    where: { userId_plantId: { userId, plantId: fallback.id } },
    create: { userId, plantId: fallback.id },
    update: {},
  });
  return fallback.id;
}

/**
 * Grants one award atomically, or reports why it didn't grant. The tally row
 * is locked (`SELECT ... FOR UPDATE`) first, serializing all of a user's
 * grants for that day, so the kind count, the 30-hearts cap, and every
 * increment commit or roll back together. Replays land on the award ledger's
 * unique constraint and come back as `cappedBy: "duplicate"`.
 */
export async function grantAward(input: GrantAwardInput): Promise<AwardOutcome> {
  const { userId, kind, dayKey, timezone } = input;
  const tallyDayKey = input.tallyDayKey ?? dayKey;
  const sourceId = input.sourceId ?? "";
  const withheld = (cappedBy: CapReason, plantId: string | null = null): AwardOutcome => ({
    kind,
    granted: false,
    hearts: 0,
    sunlight: 0,
    plantId,
    cappedBy,
  });

  try {
    return await prisma.$transaction(async (tx) => {
      // Create-or-lock the day's tally row in ONE atomic statement. A Prisma
      // upsert will not do: with an empty `update` it compiles to a
      // find-then-insert, so two concurrent first-grants of the same user-day
      // both insert and one dies on the primary key (losing its award).
      // `ON CONFLICT DO UPDATE` resolves that race in the database AND takes
      // the same row lock `FOR UPDATE` would — which is what serializes the
      // rest of this transaction.
      const locked = await tx.$queryRaw<{ hearts: number }[]>`
        INSERT INTO "daily_earn_tallies" ("userId", "dayKey", "hearts", "sunlight")
        VALUES (${userId}, ${tallyDayKey}, 0, 0)
        ON CONFLICT ("userId", "dayKey") DO UPDATE
          SET "hearts" = "daily_earn_tallies"."hearts"
        RETURNING "hearts"
      `;
      const heartsTallyToday = locked[0]?.hearts ?? 0;

      const kindCountToday = await tx.award.count({ where: { userId, kind, dayKey } });
      const decision = decideAward(kind, kindCountToday, heartsTallyToday);
      if (!decision.granted) return withheld(decision.cappedBy!);

      const plantId = await resolveCreditPlant(tx, userId);

      try {
        await tx.award.create({
          data: {
            userId,
            kind,
            dayKey,
            sourceId,
            hearts: decision.hearts,
            sunlight: decision.sunlight,
            plantId,
            timezone,
            createdAt: resolveNow(),
          },
        });
      } catch (e) {
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
          throw new DuplicateAwardSignal(plantId);
        }
        throw e;
      }

      await tx.dailyEarnTally.update({
        where: { userId_dayKey: { userId, dayKey: tallyDayKey } },
        data: {
          hearts: { increment: decision.hearts },
          sunlight: { increment: decision.sunlight },
        },
      });
      await tx.userWallet.upsert({
        where: { userId },
        create: { userId, heartsBalance: decision.hearts, heartsEarned: decision.hearts },
        update: {
          heartsBalance: { increment: decision.hearts },
          heartsEarned: { increment: decision.hearts },
        },
      });
      if (plantId) {
        await tx.userPlantProgress.upsert({
          where: { userId_plantId: { userId, plantId } },
          create: { userId, plantId, sunlight: decision.sunlight },
          update: { sunlight: { increment: decision.sunlight } },
        });
      }

      return {
        kind,
        granted: true,
        hearts: decision.hearts,
        sunlight: decision.sunlight,
        plantId,
        cappedBy: null,
      };
    });
  } catch (e) {
    if (e instanceof DuplicateAwardSignal) return withheld("duplicate", e.plantId);
    throw e;
  }
}

export interface WalletSummary {
  heartsBalance: number;
  heartsEarned: number;
  heartsGiven: number;
  earnedToday: number;
  remainingToday: number;
  dailyCap: number;
  givenByCategory: Record<string, number>;
}

/**
 * The wallet shape routes serialize: lifetime totals, today's earn against
 * the daily cap (`dayKey` is the user-local day), and lifetime giving broken
 * down by spend category. Absent rows read as zero — wallets are lazy.
 */
export async function walletSummary(userId: string, dayKey: string): Promise<WalletSummary> {
  const [wallet, tally, spends] = await Promise.all([
    prisma.userWallet.findUnique({ where: { userId } }),
    prisma.dailyEarnTally.findUnique({ where: { userId_dayKey: { userId, dayKey } } }),
    prisma.heartSpend.groupBy({
      by: ["category"],
      where: { userId },
      _sum: { amount: true },
    }),
  ]);
  const earnedToday = tally?.hearts ?? 0;
  return {
    heartsBalance: wallet?.heartsBalance ?? 0,
    heartsEarned: wallet?.heartsEarned ?? 0,
    heartsGiven: wallet?.heartsGiven ?? 0,
    earnedToday,
    remainingToday: Math.max(0, DAILY_HEARTS_CAP - earnedToday),
    dailyCap: DAILY_HEARTS_CAP,
    givenByCategory: Object.fromEntries(
      spends.map((s) => [s.category, s._sum.amount ?? 0]),
    ),
  };
}
