-- CreateEnum
CREATE TYPE "AwardKind" AS ENUM ('SESSION_COMPLETED', 'TRACK_COMPLETED', 'PAUSE_ATTENDED', 'PEACE_MESSAGE', 'DAILY_CHECKIN');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "selectedPlantId" TEXT,
ADD COLUMN     "timezone" TEXT;

-- Rename mind_trees → plants IN PLACE (hand-edited from Prisma's DROP/CREATE):
-- the seeded rows and their string slugs ("oak"…) must carry over.
ALTER TABLE "mind_trees" RENAME TO "plants";
ALTER TABLE "plants" RENAME CONSTRAINT "mind_trees_pkey" TO "plants_pkey";

-- New columns. isDefault/isActive are added with DEFAULT true so the existing
-- seeded plants become live onboarding defaults, then flipped to the schema's
-- DEFAULT false so future admin-created plants start unpublished.
ALTER TABLE "plants" ADD COLUMN "isPremium" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "plants" ADD COLUMN "isDefault" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "plants" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "plants" ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "plants" ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "plants" ALTER COLUMN "isDefault" SET DEFAULT false;
ALTER TABLE "plants" ALTER COLUMN "isActive" SET DEFAULT false;
-- @updatedAt is app-managed; Prisma's schema expects no DB default here.
ALTER TABLE "plants" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- CreateTable
CREATE TABLE "plant_stages" (
    "id" TEXT NOT NULL,
    "plantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "sunlightRequired" INTEGER NOT NULL DEFAULT 0,
    "mascotPath" TEXT,
    "mascotBgPath" TEXT,
    "heroVideoPath" TEXT,

    CONSTRAINT "plant_stages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_plant_progress" (
    "userId" TEXT NOT NULL,
    "plantId" TEXT NOT NULL,
    "sunlight" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "user_plant_progress_pkey" PRIMARY KEY ("userId","plantId")
);

-- CreateTable
CREATE TABLE "awards" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "kind" "AwardKind" NOT NULL,
    "dayKey" TEXT NOT NULL,
    "sourceId" TEXT NOT NULL DEFAULT '',
    "hearts" INTEGER NOT NULL,
    "sunlight" INTEGER NOT NULL,
    "plantId" TEXT,
    "timezone" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "awards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_earn_tallies" (
    "userId" TEXT NOT NULL,
    "dayKey" TEXT NOT NULL,
    "hearts" INTEGER NOT NULL DEFAULT 0,
    "sunlight" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "daily_earn_tallies_pkey" PRIMARY KEY ("userId","dayKey")
);

-- CreateTable
CREATE TABLE "user_wallets" (
    "userId" TEXT NOT NULL,
    "heartsBalance" INTEGER NOT NULL DEFAULT 0,
    "heartsEarned" INTEGER NOT NULL DEFAULT 0,
    "heartsGiven" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "user_wallets_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "heart_spends" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "category" TEXT NOT NULL,
    "projectId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "heart_spends_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pause_attendances" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "pauseDate" TEXT NOT NULL,
    "firstSeenAt" TIMESTAMP(3) NOT NULL,
    "lastSeenAt" TIMESTAMP(3) NOT NULL,
    "beats" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "pause_attendances_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "plant_stages_plantId_displayOrder_idx" ON "plant_stages"("plantId", "displayOrder");

-- CreateIndex
CREATE INDEX "awards_userId_createdAt_idx" ON "awards"("userId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "awards_userId_kind_dayKey_sourceId_key" ON "awards"("userId", "kind", "dayKey", "sourceId");

-- CreateIndex
CREATE INDEX "heart_spends_userId_createdAt_idx" ON "heart_spends"("userId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "pause_attendances_userId_pauseDate_key" ON "pause_attendances"("userId", "pauseDate");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_selectedPlantId_fkey" FOREIGN KEY ("selectedPlantId") REFERENCES "plants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plant_stages" ADD CONSTRAINT "plant_stages_plantId_fkey" FOREIGN KEY ("plantId") REFERENCES "plants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_plant_progress" ADD CONSTRAINT "user_plant_progress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_plant_progress" ADD CONSTRAINT "user_plant_progress_plantId_fkey" FOREIGN KEY ("plantId") REFERENCES "plants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "awards" ADD CONSTRAINT "awards_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_earn_tallies" ADD CONSTRAINT "daily_earn_tallies_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_wallets" ADD CONSTRAINT "user_wallets_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "heart_spends" ADD CONSTRAINT "heart_spends_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pause_attendances" ADD CONSTRAINT "pause_attendances_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: users whose onboarding answer names a real plant have that plant
-- selected, with a zero-sunlight progress row so the garden renders instantly.
UPDATE "users" u
SET "selectedPlantId" = op."mindTree"
FROM "onboarding_profiles" op
WHERE op."userId" = u."id"
  AND op."mindTree" IS NOT NULL
  AND EXISTS (SELECT 1 FROM "plants" p WHERE p."id" = op."mindTree");

INSERT INTO "user_plant_progress" ("userId", "plantId", "sunlight")
SELECT u."id", u."selectedPlantId", 0
FROM "users" u
WHERE u."selectedPlantId" IS NOT NULL
ON CONFLICT ("userId", "plantId") DO NOTHING;

