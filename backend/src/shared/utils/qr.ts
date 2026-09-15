import jwt from 'jsonwebtoken';
import { config } from '@shared/config';
import { generateId } from '@shared/utils/helpers';
import {
  QrTokenInvalidError,
  QrTokenExpiredError,
  QrTokenUsedError,
} from '@shared/utils/errors';

/**
 * In-memory record of QR tokens that have already been redeemed. Single-use
 * enforcement is best-effort: it survives restarts of a single instance and is
 * scoped per backend process. For multi-instance production this should be a
 * shared store (Redis); the graceful fallback below keeps a re-scan safe even
 * when a token was already used but the doctor already holds access.
 */
const usedTokens = new Set<string>();

const QR_TOKEN_TYPE = 'patient_card_qr';

export interface QrTokenPayload {
  patientId: string;
  cardNumber: string;
}

export interface QrTokenResult {
  patientId: string;
  cardNumber: string;
  jti: string;
  used: boolean;
}

export function generateQrToken(payload: QrTokenPayload): {
  token: string;
  expiresAt: string;
} {
  const jti = generateId();
  const expiresAt = new Date(
    Date.now() + config.qr.tokenExpiresInMinutes * 60_000,
  );
  const token = jwt.sign(
    {
      sub: payload.patientId,
      card: payload.cardNumber,
      jti,
      type: QR_TOKEN_TYPE,
    },
    config.qr.tokenSecret,
    { expiresIn: `${config.qr.tokenExpiresInMinutes}m` } as jwt.SignOptions,
  );
  return { token, expiresAt: expiresAt.toISOString() };
}

export function verifyQrToken(token: string): QrTokenResult {
  if (!token || typeof token !== 'string') {
    throw new QrTokenInvalidError('QR code invalide.');
  }

  let decoded: jwt.JwtPayload;
  try {
    decoded = jwt.verify(token, config.qr.tokenSecret) as jwt.JwtPayload;
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new QrTokenExpiredError();
    }
    throw new QrTokenInvalidError('QR code invalide.');
  }

  if (
    decoded.type !== QR_TOKEN_TYPE ||
    typeof decoded.sub !== 'string' ||
    typeof decoded.card !== 'string' ||
    typeof decoded.jti !== 'string'
  ) {
    throw new QrTokenInvalidError('QR code invalide.');
  }

  return {
    patientId: decoded.sub,
    cardNumber: decoded.card,
    jti: decoded.jti,
    used: isQrTokenUsed(decoded.jti),
  };
}

export function markQrTokenUsed(jti: string): void {
  usedTokens.add(jti);
}

export function isQrTokenUsed(jti: string): boolean {
  return usedTokens.has(jti);
}
