export type Session = { userId: string; token: string; expiresAt: number };

export async function login(
  authenticate: () => Promise<string | null>,
  userId: string,
): Promise<Session> {
  const token = await authenticate();
  if (!token) {
    throw new Error('AUTH_FAILED');
  }
  return { userId, token, expiresAt: Date.now() + 60 * 60 * 1000 };
}
