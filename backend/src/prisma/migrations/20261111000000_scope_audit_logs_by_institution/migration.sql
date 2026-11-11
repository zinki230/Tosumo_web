ALTER TABLE "AuditLog"
ADD COLUMN "institutionId" TEXT;

CREATE INDEX "AuditLog_institutionId_createdAt_idx"
ON "AuditLog"("institutionId", "createdAt");
