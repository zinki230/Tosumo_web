-- Backfill every verified patient's existing care-center relationships.
-- Keep the verifying doctor's primary verified center and additionally expose
-- all verified patients to the institution registered with this email. The
-- institution lookup also supports accounts whose address is stored on the
-- institution administrator rather than on Institution.email.

WITH target_center AS (
  SELECT i."id" AS "institutionId"
  FROM "Institution" i
  LEFT JOIN "User" owner ON owner."id" = i."createdByUserId"
  WHERE i."deletedAt" IS NULL
    AND (
      LOWER(COALESCE(i."email", '')) = LOWER('immodev37@gmail.com')
      OR LOWER(COALESCE(owner."email", '')) = LOWER('immodev37@gmail.com')
    )
  ORDER BY
    (LOWER(COALESCE(i."email", '')) = LOWER('immodev37@gmail.com')) DESC,
    i."createdAt" ASC,
    i."id" ASC
  LIMIT 1
), verified_patients AS (
  SELECT
    p."id" AS "patientId",
    COALESCE(p."verifiedAt", p."updatedAt", p."createdAt") AS "verifiedDate",
    verifier."doctorId"
  FROM "Patient" p
  LEFT JOIN LATERAL (
    SELECT d."id" AS "doctorId"
    FROM "Doctor" d
    WHERE d."id" = p."verifiedBy" OR d."userId" = p."verifiedBy"
    ORDER BY CASE WHEN d."id" = p."verifiedBy" THEN 0 ELSE 1 END
    LIMIT 1
  ) verifier ON TRUE
  WHERE p."isVerified" = TRUE
    AND p."deletedAt" IS NULL
), primary_center_links AS (
  SELECT
    vp."patientId",
    vp."verifiedDate",
    vp."doctorId",
    di."institutionId"
  FROM verified_patients vp
  JOIN "DoctorInstitution" di ON di."doctorId" = vp."doctorId"
  JOIN "Institution" i ON i."id" = di."institutionId"
  WHERE di."isPrimary" = TRUE
    AND i."isVerified" = TRUE
    AND i."deletedAt" IS NULL
), target_center_links AS (
  SELECT
    vp."patientId",
    vp."verifiedDate",
    vp."doctorId",
    tc."institutionId"
  FROM verified_patients vp
  CROSS JOIN target_center tc
), center_links AS (
  SELECT * FROM primary_center_links
  UNION
  SELECT * FROM target_center_links
)
INSERT INTO "MedicalCard" (
  "id", "patientId", "cardNumber", "issueDate", "createdAt", "updatedAt"
)
SELECT
  'verification-migration-card-' || cl."patientId",
  cl."patientId",
  'TOS-MIG-' || cl."patientId",
  cl."verifiedDate",
  NOW(),
  NOW()
FROM center_links cl
ON CONFLICT ("patientId") DO NOTHING;

WITH target_center AS (
  SELECT i."id" AS "institutionId"
  FROM "Institution" i
  LEFT JOIN "User" owner ON owner."id" = i."createdByUserId"
  WHERE i."deletedAt" IS NULL
    AND (
      LOWER(COALESCE(i."email", '')) = LOWER('immodev37@gmail.com')
      OR LOWER(COALESCE(owner."email", '')) = LOWER('immodev37@gmail.com')
    )
  ORDER BY
    (LOWER(COALESCE(i."email", '')) = LOWER('immodev37@gmail.com')) DESC,
    i."createdAt" ASC,
    i."id" ASC
  LIMIT 1
), verified_patients AS (
  SELECT
    p."id" AS "patientId",
    COALESCE(p."verifiedAt", p."updatedAt", p."createdAt") AS "verifiedDate",
    verifier."doctorId"
  FROM "Patient" p
  LEFT JOIN LATERAL (
    SELECT d."id" AS "doctorId"
    FROM "Doctor" d
    WHERE d."id" = p."verifiedBy" OR d."userId" = p."verifiedBy"
    ORDER BY CASE WHEN d."id" = p."verifiedBy" THEN 0 ELSE 1 END
    LIMIT 1
  ) verifier ON TRUE
  WHERE p."isVerified" = TRUE
    AND p."deletedAt" IS NULL
), primary_center_links AS (
  SELECT
    vp."patientId",
    vp."verifiedDate",
    vp."doctorId",
    di."institutionId"
  FROM verified_patients vp
  JOIN "DoctorInstitution" di ON di."doctorId" = vp."doctorId"
  JOIN "Institution" i ON i."id" = di."institutionId"
  WHERE di."isPrimary" = TRUE
    AND i."isVerified" = TRUE
    AND i."deletedAt" IS NULL
), target_center_links AS (
  SELECT
    vp."patientId",
    vp."verifiedDate",
    vp."doctorId",
    tc."institutionId"
  FROM verified_patients vp
  CROSS JOIN target_center tc
), center_links AS (
  SELECT * FROM primary_center_links
  UNION
  SELECT * FROM target_center_links
)
INSERT INTO "Visit" (
  "id", "medicalCardId", "doctorId", "institutionId", "visitDate",
  "notes", "symptoms", "createdAt", "updatedAt"
)
SELECT
  'verification-migration-visit-' || cl."patientId" || '-' || cl."institutionId",
  card."id",
  cl."doctorId",
  cl."institutionId",
  cl."verifiedDate",
  'Association migrée depuis une vérification antérieure de la carte patient.',
  ARRAY[]::TEXT[],
  NOW(),
  NOW()
FROM center_links cl
JOIN "MedicalCard" card ON card."patientId" = cl."patientId"
WHERE NOT EXISTS (
  SELECT 1
  FROM "Visit" existing
  WHERE existing."medicalCardId" = card."id"
    AND existing."institutionId" = cl."institutionId"
)
ON CONFLICT ("id") DO NOTHING;
