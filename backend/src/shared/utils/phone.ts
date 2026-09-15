/**
 * Cameroon phone-number normalization and validation.
 *
 * Accepts reasonable local formats such as:
 *   +237 6 XX XX XX XX
 *   +2376XXXXXXXX
 *   06XXXXXXXX
 *   6XXXXXXXX
 *
 * and normalizes to a single canonical representation: +237XXXXXXXXX.
 */
const CAMEROON_COUNTRY_CODE = '237';

const VALID_PREFIXES = ['6', '5', '2'];
const NATIONAL_LENGTH = 9;

export function onlyDigits(input: string): string {
  return (input || '').replace(/\D/g, '');
}

/**
 * Normalizes a phone number to the canonical +237XXXXXXXXX form.
 * Returns an empty string when the input is not a valid Cameroonian number.
 */
export function normalizeCameroonPhone(input: string): string {
  if (!input) return '';
  const digits = onlyDigits(input);
  if (digits.length === 0) return '';

  let normalized: string;
  if (digits.startsWith(CAMEROON_COUNTRY_CODE)) {
    normalized = digits;
  } else if (digits.startsWith('0')) {
    normalized = CAMEROON_COUNTRY_CODE + digits.slice(1);
  } else {
    normalized = CAMEROON_COUNTRY_CODE + digits;
  }

  const national = normalized.slice(CAMEROON_COUNTRY_CODE.length);
  if (national.length !== NATIONAL_LENGTH) return '';
  if (!VALID_PREFIXES.includes(national[0])) return '';

  return `+${normalized}`;
}

/** Formatted display format: +237 690 00 00 00 */
export function formatCameroonPhone(phone: string): string {
  const canonical = normalizeCameroonPhone(phone);
  if (!canonical) return phone;
  const national = canonical.slice(4);
  return `+${CAMEROON_COUNTRY_CODE} ${national.slice(0, 3)} ${national.slice(3, 5)} ${national.slice(5, 7)} ${national.slice(7, 9)}`;
}