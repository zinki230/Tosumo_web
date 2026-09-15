import path from 'path';
import { addAliases } from 'module-alias';

/**
 * Registers `@shared` / `@modules` path aliases relative to this file's
 * location, so the same code resolves correctly in both environments:
 *
 * - `tsx src/server.ts` (dev): __dirname = src/            -> src/shared, src/modules
 * - `node dist/server.js` (prod): __dirname = dist/        -> dist/shared, dist/modules
 *
 * This replaces the previous `import 'module-alias/register'`, which always
 * read the package.json `_moduleAliases` mapping and therefore forced even
 * the dev server to load the stale compiled `dist/` build — silently hiding
 * any un-rebuilt source changes (e.g. the User index fix below).
 *
 * Keep this import FIRST in any entry file so aliases exist before any
 * `@shared` / `@modules` import is evaluated.
 */
addAliases({
  '@modules': path.join(__dirname, 'modules'),
  '@shared': path.join(__dirname, 'shared'),
});