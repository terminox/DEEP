-- DEEP Premium: the per-user subscription standing RevenueCat reports, and an
-- append-only log of its webhook events keyed on RevenueCat's own event id.
-- Purely additive; safe to run before or after the new revision rolls out.

-- CreateEnum
CREATE TYPE "RevenueCatEventOutcome" AS ENUM ('APPLIED', 'STALE', 'UNKNOWN_USER', 'SANDBOX_IGNORED', 'UNRECOGNISED', 'IRRELEVANT');

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "entitlementId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "store" TEXT NOT NULL,
    "environment" TEXT NOT NULL,
    "periodType" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "gracePeriodExpiresAt" TIMESTAMP(3),
    "willRenew" BOOLEAN NOT NULL,
    "billingIssueDetectedAt" TIMESTAMP(3),
    "unsubscribedAt" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "lastEventAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "revenuecat_events" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "environment" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "userId" TEXT,
    "eventAt" TIMESTAMP(3) NOT NULL,
    "payload" JSONB NOT NULL,
    "outcome" "RevenueCatEventOutcome" NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "revenuecat_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_userId_key" ON "subscriptions"("userId");

-- CreateIndex
CREATE INDEX "revenuecat_events_userId_idx" ON "revenuecat_events"("userId");

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
