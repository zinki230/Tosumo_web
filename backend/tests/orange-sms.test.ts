import { resetOrangeTokenForTests, sendVerificationSMS } from '../src/shared/services/sms';

describe('Orange Cameroon SMS API', () => {
  beforeEach(() => {
    resetOrangeTokenForTests();
    jest.restoreAllMocks();
  });

  it('uses OAuth client credentials and only reports delivery accepted after HTTP 201', async () => {
    const fetchMock = jest.spyOn(global, 'fetch')
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'access-token', expires_in: 3600 }), { status: 200 }))
      .mockResolvedValueOnce(new Response('{}', { status: 201 }));

    await sendVerificationSMS('+237690000001', '001234');

    expect(fetchMock).toHaveBeenNthCalledWith(1, 'https://api.orange.com/oauth/v3/token', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ Authorization: `Basic ${Buffer.from('test-client-id:test-client-secret').toString('base64')}` }),
    }));
    const [url, init] = fetchMock.mock.calls[1];
    expect(url).toContain('/smsmessaging/v1/outbound/tel%3A%2B2370000/requests');
    expect(init?.headers).toEqual(expect.objectContaining({ Authorization: 'Bearer access-token' }));
    expect(JSON.parse(String(init?.body)).outboundSMSMessageRequest).toMatchObject({
      address: 'tel:+237690000001',
      senderAddress: 'tel:+2370000',
      outboundSMSTextMessage: { message: expect.stringContaining('001234') },
    });
  });

  it('does not treat an Orange credit/account rejection as a sent SMS', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    jest.spyOn(global, 'fetch')
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'access-token', expires_in: 3600 }), { status: 200 }))
      .mockResolvedValueOnce(new Response('private provider details', { status: 403 }));

    await expect(sendVerificationSMS('+237690000001', '001234'))
      .rejects.toThrow('Vérifiez le contrat et le solde');
  });

  it('refreshes an expired access token and retries once', async () => {
    const fetchMock = jest.spyOn(global, 'fetch')
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'expired-token', expires_in: 3600 }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ code: 42, message: 'Expired credentials' }), { status: 401 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'fresh-token', expires_in: 3600 }), { status: 200 }))
      .mockResolvedValueOnce(new Response('{}', { status: 201 }));

    await sendVerificationSMS('+237690000001', '001234');

    expect(fetchMock).toHaveBeenCalledTimes(4);
    expect(fetchMock.mock.calls[3][1]?.headers).toEqual(expect.objectContaining({
      Authorization: 'Bearer fresh-token',
    }));
  });
});
