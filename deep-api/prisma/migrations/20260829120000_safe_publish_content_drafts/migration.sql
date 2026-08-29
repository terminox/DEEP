-- CreateEnum
CREATE TYPE "DraftOp" AS ENUM ('CREATE', 'UPDATE', 'DELETE');

-- CreateEnum
CREATE TYPE "DraftEntity" AS ENUM ('SOUND_CATEGORY', 'SOUND_COLLECTION', 'SOUND_TRACK', 'TRACK_LYRICS', 'PLANT', 'PLANT_STAGE', 'PAUSE_CONFIG', 'PAUSE_WELCOME_MESSAGE', 'PAUSE_INTENTION');

-- Visibility for sound content. Publishing is what makes new content live, so
-- these exist only to pull LIVE content down without deleting it - which means
-- DEFAULT true, and every existing row stays visible.
ALTER TABLE "sound_categories" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "sound_collections" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "sound_tracks" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

-- plants.isActive meant "published" and defaulted false so half-built plants
-- could not leak into the picker. Staging now owns that job - an unpublished
-- plant has no row at all - so the flag means the same thing as the three above
-- and defaults the same way. Existing rows keep whatever value they hold.
ALTER TABLE "plants" ALTER COLUMN "isActive" SET DEFAULT true;

-- CreateTable
CREATE TABLE "content_drafts" (
    "id" TEXT NOT NULL,
    "entity" "DraftEntity" NOT NULL,
    "entityId" TEXT NOT NULL,
    "op" "DraftOp" NOT NULL,
    "patch" JSONB,
    "baseVersion" TIMESTAMP(3),
    "label" TEXT NOT NULL,
    "parentKey" TEXT,
    "authorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_drafts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "content_drafts_parentKey_idx" ON "content_drafts"("parentKey");

-- One draft row per record: repeat edits coalesce instead of piling up.
CREATE UNIQUE INDEX "content_drafts_entity_entityId_key" ON "content_drafts"("entity", "entityId");

-- AddForeignKey
ALTER TABLE "content_drafts" ADD CONSTRAINT "content_drafts_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
