import prisma from './prisma';

/**
 * Ensures the database-level unique indexes that Prisma `db push` would
 * create but which are not applied automatically by `prisma generate`.
 *
 * The deployment runs `prisma generate` only (see package.json postinstall),
 * so on an existing MongoDB the `User.phone` unique index may never have been
 * created. The backend must enforce phone uniqueness at the database level:
 * it is the last line of defense against duplicate accounts (concurrent
 * registrations, Postman, or any client that bypasses the app-level check).
 *
 * This helper is idempotent AND tolerant of pre-existing indexes: Prisma
 * (`db push`/migrations) names its indexes `User_phone_key`/`User_email_key`,
 * so `createIndexes` with a different name would raise
 * `IndexOptionsConflict` (error 85). Any existing *unique* index on the field
 * already provides the guarantee, regardless of its name; we only create an
 * index when no unique index on that field exists.
 */
export async function ensureDatabaseIndexes(): Promise<void> {
  const fields = ['phone', 'email'] as const;
  const desired = new Map<typeof fields[number], { name: string; exists: boolean }>(
    fields.map((field) => [field, { name: `${field}_unique`, exists: false }]),
  );

  try {
    const result = await prisma.$runCommandRaw({ listIndexes: 'User' });
    const indexes: Array<{ name?: string; unique?: boolean; key?: Record<string, number> }> =
      (result as { cursor?: { firstBatch?: Array<Record<string, unknown>> } })
        .cursor?.firstBatch ?? [];

    for (const idx of indexes) {
      const key = idx.key ?? {};
      for (const field of fields) {
        if (key[field] === 1 && idx.unique === true) {
          const entry = desired.get(field);
          if (entry) entry.exists = true;
          if (idx.name && idx.name !== entry?.name) {
            console.info(
              `[indexes] Unique index on User.${field} already enforced by ` +
                `"${idx.name}" (DB-level uniqueness confirmed).`,
            );
          }
        }
      }
    }
  } catch (error) {
    console.warn(
      `Could not inspect existing indexes on User (${fields.join(', ')}). ` +
        'Duplicate registrations are still blocked by the service layer.',
      error instanceof Error ? error.message : error,
    );
    return;
  }

  const missing = [...desired].filter(([, entry]) => !entry.exists);
  if (missing.length === 0) {
    console.info('[indexes] Unique database indexes on User (phone, email) already present.');
    return;
  }

  try {
    await prisma.$runCommandRaw({
      createIndexes: 'User',
      indexes: missing.map(([field, entry]) => ({
        key: { [field]: 1 },
        name: entry.name,
        unique: true,
      })),
    });
    console.info(
      `[indexes] Created unique indexes: ${missing.map(([, e]) => e.name).join(', ')}.`,
    );
  } catch (error) {
    console.warn(
      'Could not create missing unique indexes on User ' +
        `(${missing.map(([, e]) => e.name).join(', ')}). ` +
        'Duplicate registrations are still blocked by the service layer, but ' +
        'run `prisma db push` once to guarantee database-level enforcement.',
      error instanceof Error ? error.message : error,
    );
  }
}