export type Session = { userId: string; token: string; expiresAt: number };

// AICode: added a timeout to the authentication request.
export async function login(
  authenticate: () => Promise<string | null>,
  userId: string,
  timeoutMs = 5000,
): Promise<Session> {
  try {
    const token = await Promise.race([
      authenticate(),
      new Promise<null>((_, reject) => setTimeout(() => reject(new Error('timeout')), timeoutMs)),
    ]);
    if (!token) {
      throw new Error('AUTH_FAILED');
    }
    return { userId, token, expiresAt: Date.now() + 60 * 60 * 1000 };
  } catch {
    throw new Error('AUTH_TIMEOUT');
  }
}
