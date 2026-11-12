-- Preserve existing center scope by linking each previously verified patient
-- to the verified center of the doctor who verified them. The doctor’s primary
-- center is preferred; if they have only one active verified center, use it.
-- Existing visits and consultations are left untouched.

WITH verified_patient_centers AS (
  SELECT p."id" AS "patientId", destination."institutionId"
  FROM "Patient" p
  JOIN LATERAL (
    SELECT d."id"
    FROM "Doctor" d
    WHERE d."id" = p."verifiedBy" OR d."userId" = p."verifiedBy"
    ORDER BY CASE WHEN d."id" = p."verifiedBy" THEN 0 ELSE 1 END
    LIMIT 1
  ) doctor ON TRUE
  JOIN LATERAL (
    SELECT di."institutionId"
    FROM "DoctorInstitution" di
    JOIN "Institution" i
      ON i."id" = di."institutionId"
      AND i."isVerified" = TRUE
      AND i."deletedAt" IS NULL
    WHERE di."doctorId" = doctor."id"
      AND (
        di."isPrimary" = TRUE
        OR NOT EXISTS (
          SELECT 1
          FROM "DoctorInstitution" other_di
          JOIN "Institution" other_i
            ON other_i."id" = other_di."institutionId"
            AND other_i."isVerified" = TRUE
            AND other_i."deletedAt" IS NULL
          WHERE other_di."doctorId" = doctor."id"
          GROUP BY other_di."doctorId"
          HAVING COUNT(DISTINCT other_di."institutionId") > 1
        )
      )
    ORDER BY di."isPrimary" DESC, di."createdAt" ASC
    LIMIT 1
  ) destination ON TRUE
  WHERE p."isVerified" = TRUE
    AND p."deletedAt" IS NULL
)
INSERT INTO "MedicalCard" ("id", "patientId", "cardNumber", "issueDate", "createdAt", "updatedAt")
SELECT
  'verification-migration-card-' || p."id",
  p."id",
  'TOS-MIG-' || p."id",
  COALESCE(p."verifiedAt", p."updatedAt", p."createdAt"),
  NOW(),
  NOW()
FROM "Patient" p
JOIN verified_patient_centers vpc ON vpc."patientId" = p."id"
WHERE NOT EXISTS (
  SELECT 1 FROM "MedicalCard" card WHERE card."patientId" = p."id"
)
ON CONFLICT ("patientId") DO NOTHING;

WITH verified_patient_centers AS (
  SELECT
    p."id" AS "patientId",
    COALESCE(p."verifiedAt", p."updatedAt", p."createdAt") AS "verifiedDate",
    doctor."id" AS "doctorId",
    destination."institutionId"
  FROM "Patient" p
  JOIN LATERAL (
    SELECT d."id"
    FROM "Doctor" d
    WHERE d."id" = p."verifiedBy" OR d."userId" = p."verifiedBy"
    ORDER BY CASE WHEN d."id" = p."verifiedBy" THEN 0 ELSE 1 END
    LIMIT 1
  ) doctor ON TRUE
  JOIN LATERAL (
    SELECT di."institutionId"
    FROM "DoctorInstitution" di
    JOIN "Institution" i
      ON i."id" = di."institutionId"
      AND i."isVerified" = TRUE
      AND i."deletedAt" IS NULL
    WHERE di."doctorId" = doctor."id"
      AND (
        di."isPrimary" = TRUE
        OR NOT EXISTS (
          SELECT 1
          FROM "DoctorInstitution" other_di
          JOIN "Institution" other_i
            ON other_i."id" = other_di."institutionId"
            AND other_i."isVerified" = TRUE
            AND other_i."deletedAt" IS NULL
          WHERE other_di."doctorId" = doctor."id"
          GROUP BY other_di."doctorId"
          HAVING COUNT(DISTINCT other_di."institutionId") > 1
        )
      )
    ORDER BY di."isPrimary" DESC, di."createdAt" ASC
    LIMIT 1
  ) destination ON TRUE
  WHERE p."isVerified" = TRUE
    AND p."deletedAt" IS NULL
)
INSERT INTO "Visit" (
  "id", "medicalCardId", "doctorId", "institutionId", "visitDate", "notes", "symptoms", "createdAt", "updatedAt"
)
SELECT
  'verification-migration-visit-' || vpc."patientId" || '-' || vpc."institutionId",
  card."id",
  vpc."doctorId",
  vpc."institutionId",
  vpc."verifiedDate",
  'Association migrée depuis une vérification antérieure de la carte patient.',
  ARRAY[]::TEXT[],
  NOW(),
  NOW()
FROM verified_patient_centers vpc
JOIN "MedicalCard" card ON card."patientId" = vpc."patientId"
WHERE NOT EXISTS (
  SELECT 1
  FROM "Visit" existing
  WHERE existing."medicalCardId" = card."id"
    AND existing."doctorId" = vpc."doctorId"
    AND existing."institutionId" = vpc."institutionId"
)
ON CONFLICT ("id") DO NOTHING;
