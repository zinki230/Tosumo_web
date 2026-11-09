import twilio, { Twilio } from 'twilio';
import { config } from '@shared/config';
import { AppError } from '@shared/utils/errors';

let client: Twilio | undefined;

function getTwilioClient(): Twilio {
  const { twilioAccountSid, twilioAuthToken } = config.sms;
  if (!twilioAccountSid || !twilioAuthToken) {
    throw new AppError('Twilio SMS n’est pas configuré. Renseignez TWILIO_ACCOUNT_SID et TWILIO_AUTH_TOKEN.', 503);
  }
  return client ??= twilio(twilioAccountSid, twilioAuthToken);
}

export async function sendVerificationSMS(phone: string, code: string): Promise<void> {
  const { twilioFromNumber, twilioMessagingServiceSid } = config.sms;
  if (!twilioMessagingServiceSid && !/^\+[1-9]\d{7,14}$/.test(twilioFromNumber)) {
    throw new AppError('Configurez TWILIO_FROM_NUMBER au format E.164 ou TWILIO_MESSAGING_SERVICE_SID.', 503);
  }
  try {
    await getTwilioClient().messages.create({
      to: phone,
      ...(twilioMessagingServiceSid
        ? { messagingServiceSid: twilioMessagingServiceSid }
        : { from: twilioFromNumber }),
      body: `Votre code de vérification TOSUMO est ${code}. Il expire dans 5 minutes. Ne le partagez avec personne.`,
    });
  } catch (error) {
    const status = typeof error === 'object' && error !== null && 'status' in error ? Number(error.status) : undefined;
    console.error('Twilio SMS send failed', { status });
    throw new AppError('Twilio n’a pas accepté l’envoi du SMS. Vérifiez votre compte, votre expéditeur et les permissions pays.', 502);
  }
}
