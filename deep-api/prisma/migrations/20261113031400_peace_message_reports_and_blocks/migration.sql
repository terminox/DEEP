-- CreateEnum
CREATE TYPE "PeaceMessageReportReason" AS ENUM ('OFFENSIVE', 'HARASSMENT', 'SPAM', 'OTHER');

-- CreateTable
CREATE TABLE "peace_message_reports" (
    "id" TEXT NOT NULL,
    "messageId" TEXT NOT NULL,
    "reporterId" TEXT NOT NULL,
    "reason" "PeaceMessageReportReason" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "peace_message_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_blocks" (
    "id" TEXT NOT NULL,
    "blockerId" TEXT NOT NULL,
    "blockedId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "peace_message_reports_messageId_idx" ON "peace_message_reports"("messageId");

-- CreateIndex
CREATE INDEX "peace_message_reports_reporterId_idx" ON "peace_message_reports"("reporterId");

-- CreateIndex
CREATE UNIQUE INDEX "peace_message_reports_messageId_reporterId_key" ON "peace_message_reports"("messageId", "reporterId");

-- CreateIndex
CREATE INDEX "user_blocks_blockerId_idx" ON "user_blocks"("blockerId");

-- CreateIndex
CREATE INDEX "user_blocks_blockedId_idx" ON "user_blocks"("blockedId");

-- CreateIndex
CREATE UNIQUE INDEX "user_blocks_blockerId_blockedId_key" ON "user_blocks"("blockerId", "blockedId");

-- AddForeignKey
ALTER TABLE "peace_message_reports" ADD CONSTRAINT "peace_message_reports_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "peace_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "peace_message_reports" ADD CONSTRAINT "peace_message_reports_reporterId_fkey" FOREIGN KEY ("reporterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blockerId_fkey" FOREIGN KEY ("blockerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_blockedId_fkey" FOREIGN KEY ("blockedId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
