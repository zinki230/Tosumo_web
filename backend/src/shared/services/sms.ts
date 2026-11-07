import { config } from '@shared/config';
import { AppError } from '@shared/utils/errors';

const ORANGE_API = 'https://api.orange.com';
const TOKEN_URL = `${ORANGE_API}/oauth/v3/token`;

type OrangeToken = { value: string; expiresAt: number };
let token: OrangeToken | undefined;
let tokenRequest: Promise<string> | undefined;

async function getAccessToken(forceRefresh = false): Promise<string> {
  const { orangeClientId, orangeClientSecret } = config.sms;
  if (!orangeClientId || !orangeClientSecret) {
    throw new AppError('Le service SMS Orange n’est pas configuré.', 503);
  }
  if (!forceRefresh && token && token.expiresAt > Date.now() + 30_000) return token.value;
  if (tokenRequest) return tokenRequest;

  tokenRequest = (async () => {
    const auth = Buffer.from(`${orangeClientId}:${orangeClientSecret}`).toString('base64');
    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({ grant_type: 'client_credentials' }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      console.error('Orange OAuth token request failed', { status: response.status });
      throw new AppError('Le service SMS Orange est temporairement indisponible.', 502);
    }
    const body = (await response.json()) as { access_token?: string; expires_in?: string | number };
    if (!body.access_token) throw new AppError('Réponse OAuth Orange invalide.', 502);
    const lifetime = Number(body.expires_in || 3600) * 1000;
    token = { value: body.access_token, expiresAt: Date.now() + lifetime };
    return body.access_token;
  })();
  try {
    return await tokenRequest;
  } finally {
    tokenRequest = undefined;
  }
}

export async function sendVerificationSMS(phone: string, code: string): Promise<void> {
  const sender = config.sms.orangeSenderAddress;
  if (!/^tel:\+237\d+$/.test(sender)) {
    throw new AppError('Le numéro expéditeur Orange est mal configuré.', 503);
  }
  const message = `Votre code de vérification TOSUMO est ${code}. Il expire dans 5 minutes.`;
  const url = `${ORANGE_API}/smsmessaging/v1/outbound/${encodeURIComponent(sender)}/requests`;

  for (let attempt = 0; attempt < 2; attempt++) {
    const accessToken = await getAccessToken(attempt > 0);
    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ outboundSMSMessageRequest: {
          address: `tel:${phone}`,
          senderAddress: sender,
          outboundSMSTextMessage: { message },
        } }),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      console.error('Orange SMS request failed before receiving a response');
      throw new AppError('Échec de l’envoi du SMS. Veuillez réessayer.', 502);
    }
    if (response.status === 401 && attempt === 0) {
      token = undefined;
      continue;
    }
    if (response.status === 201) return;
    // Never log provider response bodies: they can contain recipient data.
    console.error('Orange SMS rejected the message', { status: response.status });
    if (response.status === 403 || response.status === 402) {
      throw new AppError('Le compte SMS Orange ne peut pas envoyer de message. Vérifiez le contrat et le solde.', 503);
    }
    throw new AppError('Orange n’a pas accepté l’envoi du SMS.', 502);
  }
  throw new AppError('Le service SMS Orange est temporairement indisponible.', 502);
}

/** Reset cached OAuth credentials for isolated tests. */
export function resetOrangeTokenForTests(): void {
  token = undefined;
  tokenRequest = undefined;
}
