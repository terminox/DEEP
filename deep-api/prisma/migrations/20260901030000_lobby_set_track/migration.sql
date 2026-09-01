-- Fuku's lounge gets its own track. Until now lobbyAudioPath defaulted to the
-- meditation's own file, which nothing ever played; the lounge now broadcasts
-- Theme → Light merged into one 262 s set, and needs its length the same way
-- the meditation needs its own: measured off the file, never typed.

-- AlterTable
ALTER TABLE "pause_config" ADD COLUMN "lobbyDurationSeconds" INTEGER NOT NULL DEFAULT 262;

ALTER TABLE "pause_config" ALTER COLUMN "lobbyAudioPath" SET DEFAULT '/media/audio/global-pause-lobby.mp3';

-- The singleton row predates both, so the new default alone would not move it:
-- it still points at the meditation track, and a lounge playing the meditation
-- theme in the run-up to the meditation is not the set that was written.
-- Only rows still sitting on the old default are moved — an operator who has
-- already chosen a lobby track in the admin keeps it.
UPDATE "pause_config"
SET "lobbyAudioPath"       = '/media/audio/global-pause-lobby.mp3',
    "lobbyDurationSeconds" = 262
WHERE "id" = 1
  AND "lobbyAudioPath" = '/media/audio/global-pause.mp3';
