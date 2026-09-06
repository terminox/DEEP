-- Global Pause used to be one event a day, defined by four wall-clock columns on
-- the pause_config singleton. It is now a list of daily slots; the config keeps
-- only what every slot shares (timezone, audio, measured lengths).
--
-- DEPLOY ORDER — this one is backwards from the usual, and it matters.
-- infra/README.md runs `pulumi up` before the migrate job, which is right when a
-- migration only removes something the new code stopped reading. Here the new
-- revision cannot serve GET /pause/schedule at all until pause_slots exists, so
-- for THIS release the migrate job must run FIRST.
--
-- Run it outside 20:30-21:00 Bangkok as well. Everything below is additive and
-- safe for the previous revision except the attendance index swap: the old
-- recordAttendance says ON CONFLICT ("userId","pauseDate") and needs that exact
-- unique index. It only executes during a meditation phase, so with the window
-- closed the old revision never touches the table.

-- CreateTable
CREATE TABLE "pause_slots" (
    "id" TEXT NOT NULL,
    "lobbyStart" TEXT NOT NULL,
    "welcomeStart" TEXT NOT NULL,
    "meditationStart" TEXT NOT NULL,
    "windowEnd" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pause_slots_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pause_slots_meditationStart_key" ON "pause_slots"("meditationStart");

-- Carry the singleton's four columns across as the first slot, so this deploy
-- does not move tonight's pause by a single second.
INSERT INTO "pause_slots" ("id", "lobbyStart", "welcomeStart", "meditationStart", "windowEnd", "updatedAt")
SELECT '00000000-0000-4000-8000-000000000001',
       "lobbyStart", "welcomeStart", "meditationStart", "windowEnd", NOW()
  FROM "pause_config"
 WHERE "id" = 1;

-- A database that has never materialised the singleton (a fresh install) still
-- needs a slot: give it the same defaults the schema used to carry.
INSERT INTO "pause_slots" ("id", "lobbyStart", "welcomeStart", "meditationStart", "windowEnd", "updatedAt")
SELECT '00000000-0000-4000-8000-000000000001', '20:30:00', '20:39:50', '20:40:00', '21:00:00', NOW()
 WHERE NOT EXISTS (SELECT 1 FROM "pause_slots");

-- Attendance is evidence for one OCCURRENCE, not for a day. Without the
-- discriminator, a member who catches the start of the morning meditation and
-- the end of the evening one holds a span that reads as full coverage of both.
ALTER TABLE "pause_attendances" ADD COLUMN "slotId" TEXT;

UPDATE "pause_attendances"
   SET "slotId" = '00000000-0000-4000-8000-000000000001'
 WHERE "slotId" IS NULL;

ALTER TABLE "pause_attendances" ALTER COLUMN "slotId" SET NOT NULL;

-- DropIndex
DROP INDEX "pause_attendances_userId_pauseDate_key";

-- CreateIndex
CREATE UNIQUE INDEX "pause_attendances_userId_pauseDate_slotId_key" ON "pause_attendances"("userId", "pauseDate", "slotId");

-- AlterEnum
-- Safe inside this migration's transaction on PG 12+ precisely because nothing
-- below inserts a draft using the new value.
ALTER TYPE "DraftEntity" ADD VALUE 'PAUSE_SLOT';
