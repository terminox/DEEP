-- CreateEnum
CREATE TYPE "TranslatableEntity" AS ENUM ('SOUND_CATEGORY', 'SOUND_COLLECTION', 'SOUND_TRACK', 'QUIZ_QUESTION', 'QUIZ_OPTION', 'PLANT', 'PLANT_STAGE', 'PAUSE_WELCOME_MESSAGE', 'PAUSE_INTENTION');

-- CreateTable
CREATE TABLE "content_translations" (
    "id" TEXT NOT NULL,
    "entity" "TranslatableEntity" NOT NULL,
    "entityId" TEXT NOT NULL,
    "languageCode" TEXT NOT NULL,
    "fields" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_translations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "content_translations_languageCode_idx" ON "content_translations"("languageCode");

-- CreateIndex
CREATE UNIQUE INDEX "content_translations_entity_entityId_languageCode_key" ON "content_translations"("entity", "entityId", "languageCode");
