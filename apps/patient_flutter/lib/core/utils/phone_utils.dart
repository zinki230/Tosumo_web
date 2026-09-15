/// Cameroon phone-number normalization and validation.
///
/// Mirrors `backend/src/shared/utils/phone.ts` so the client and the server
/// agree on a single canonical representation (+237XXXXXXXXX). Every place
/// that accepts a phone number (registration, sign-in, OTP, duplicate
/// checks) must go through this utility — never build a local variant.
library;

const String _cameroonCountryCode = '237';
const List<String> _validPrefixes = ['6', '5', '2'];
const int _nationalLength = 9;

String _onlyDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Normalizes a phone number to the canonical +237XXXXXXXXX form.
/// Returns an empty string when the input is not a valid Cameroonian number.
String normalizeCameroonPhone(String input) {
  if (input.isEmpty) return '';
  final digits = _onlyDigits(input);
  if (digits.isEmpty) return '';

  final String normalized;
  if (digits.startsWith(_cameroonCountryCode)) {
    normalized = digits;
  } else if (digits.startsWith('0')) {
    normalized = '$_cameroonCountryCode${digits.substring(1)}';
  } else {
    normalized = '$_cameroonCountryCode$digits';
  }

  final national = normalized.substring(_cameroonCountryCode.length);
  if (national.length != _nationalLength) return '';
  if (!_validPrefixes.contains(national[0])) return '';

  return '+$normalized';
}

/// True when the input resolves to a valid Cameroonian phone number.
bool isValidCameroonPhone(String input) =>
    normalizeCameroonPhone(input).isNotEmpty;
