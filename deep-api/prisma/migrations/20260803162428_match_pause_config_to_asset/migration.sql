-- AlterTable
ALTER TABLE "pause_config" ALTER COLUMN "feedbackStart" SET DEFAULT '20:42:12',
ALTER COLUMN "meditationAudioPath" SET DEFAULT '/media/audio/global-pause.mp3',
ALTER COLUMN "meditationDurationSeconds" SET DEFAULT 132;

-- The existing singleton row was created under the old defaults (600 s window,
-- inner-light.mp3), which don't match the real meditation asset:
-- global-pause.mp3 is 132 s, so a mid-window join seeked past EOF → silence.
UPDATE "pause_config"
SET "feedbackStart"             = '20:42:12',
    "meditationAudioPath"       = '/media/audio/global-pause.mp3',
    "meditationDurationSeconds" = 132
WHERE "id" = 1;
