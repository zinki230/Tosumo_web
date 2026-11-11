ALTER TABLE "Visit"
ADD COLUMN "doctorId" TEXT;

ALTER TABLE "Visit"
ADD CONSTRAINT "Visit_doctorId_fkey"
FOREIGN KEY ("doctorId") REFERENCES "Doctor"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Visit_institutionId_visitDate_idx"
ON "Visit"("institutionId", "visitDate");

CREATE INDEX "Visit_doctorId_visitDate_idx"
ON "Visit"("doctorId", "visitDate");

ALTER TABLE "Consultation"
ADD COLUMN "institutionId" TEXT;

ALTER TABLE "Consultation"
ADD CONSTRAINT "Consultation_institutionId_fkey"
FOREIGN KEY ("institutionId") REFERENCES "Institution"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Consultation_institutionId_consultationDate_idx"
ON "Consultation"("institutionId", "consultationDate");
