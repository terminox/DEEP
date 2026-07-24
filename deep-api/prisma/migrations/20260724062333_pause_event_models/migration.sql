-- CreateEnum
CREATE TYPE "PeaceMessageStatus" AS ENUM ('PUBLISHED', 'HIDDEN');

-- CreateTable
CREATE TABLE "pause_config" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Bangkok',
    "lobbyStart" TEXT NOT NULL DEFAULT '20:30:00',
    "welcomeStart" TEXT NOT NULL DEFAULT '20:39:50',
    "meditationStart" TEXT NOT NULL DEFAULT '20:40:00',
    "feedbackStart" TEXT NOT NULL DEFAULT '20:50:00',
    "windowEnd" TEXT NOT NULL DEFAULT '21:00:00',
    "lobbyAudioPath" TEXT NOT NULL DEFAULT '/media/audio/global-pause.mp3',
    "meditationAudioPath" TEXT NOT NULL DEFAULT '/media/audio/inner-light.mp3',
    "meditationDurationSeconds" INTEGER NOT NULL DEFAULT 600,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pause_config_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pause_welcome_messages" (
    "id" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "pause_welcome_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pause_intention_options" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "displayOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "pause_intention_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "peace_messages" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "displayName" TEXT NOT NULL,
    "countryISO" TEXT,
    "text" TEXT NOT NULL,
    "status" "PeaceMessageStatus" NOT NULL DEFAULT 'PUBLISHED',
    "pauseDate" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "peace_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pause_reflections" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "pauseDate" TEXT NOT NULL,
    "intention" TEXT,
    "mood" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pause_reflections_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pause_intention_options_key_key" ON "pause_intention_options"("key");

-- CreateIndex
CREATE INDEX "peace_messages_pauseDate_status_createdAt_idx" ON "peace_messages"("pauseDate", "status", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "pause_reflections_userId_pauseDate_key" ON "pause_reflections"("userId", "pauseDate");

-- AddForeignKey
ALTER TABLE "peace_messages" ADD CONSTRAINT "peace_messages_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pause_reflections" ADD CONSTRAINT "pause_reflections_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
