// The response tail every award-bearing route shares: a fresh wallet plus a
// snapshot of the user's selected plant. One assembler keeps the five call
// sites (practice sync, sound listens, pause claim, peace messages, spends)
// emitting exactly the same field names.
import { prisma } from "../prisma.js";
import { deriveStageIndex } from "./awardRules.js";
import { walletSummary } from "./awards.js";
import { serializeWallet } from "./serialize.js";

export interface PlantSnapshot {
  plantId: string;
  sunlight: number;
  currentStageIndex: number;
}

/**
 * The user's selected plant at its earned stage, or null when no plant is
 * selected yet (awards may still have granted hearts with no plant to credit).
 */
export async function plantSnapshot(userId: string): Promise<PlantSnapshot | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { selectedPlantId: true },
  });
  const plantId = user?.selectedPlantId;
  if (!plantId) return null;

  const [progress, stages] = await Promise.all([
    prisma.userPlantProgress.findUnique({
      where: { userId_plantId: { userId, plantId } },
    }),
    prisma.plantStage.findMany({
      where: { plantId },
      orderBy: { displayOrder: "asc" },
    }),
  ]);
  const sunlight = progress?.sunlight ?? 0;
  return { plantId, sunlight, currentStageIndex: deriveStageIndex(stages, sunlight) };
}

/**
 * `{ wallet, plant }` as routes return them, fetched fresh — call AFTER any
 * grants so the numbers already include them. `dayKey` is the user-local day
 * the wallet's "earned today" reads against.
 */
export async function rewardSnapshot(userId: string, dayKey: string) {
  const [wallet, plant] = await Promise.all([
    walletSummary(userId, dayKey),
    plantSnapshot(userId),
  ]);
  return { wallet: serializeWallet(wallet), plant };
}
