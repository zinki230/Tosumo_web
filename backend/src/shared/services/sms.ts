import { config } from '@shared/config';

export async function sendSMS(params: {
  to: string;
  message: string;
}): Promise<void> {
  if (process.env.NODE_ENV === 'test' || !config.sms.apiKey) return;

  try {
    const response = await fetch('https://api.africastalking.com/version1/messaging', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'ApiKey': config.sms.apiKey,
        'Accept': 'application/json',
      },
      body: new URLSearchParams({
        username: config.sms.username,
        to: params.to,
        message: params.message,
      }),
    });

    if (!response.ok) {
      console.error('SMS send failed:', await response.text());
    }
  } catch (error) {
    console.error('Failed to send SMS:', error);
  }
}

export async function sendVerificationSMS(phone: string, code: string): Promise<void> {
  await sendSMS({
    to: phone,
    message: `Your TOSUMO verification code is: ${code}. Valid for 10 minutes.`,
  });
}
