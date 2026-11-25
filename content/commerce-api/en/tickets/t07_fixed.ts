// Retry delay for the notification sender: doubles each attempt, never more than 30 seconds.
export function backoff(attempt: number): number {
  if (attempt < 0) return 0;
  return Math.min(30_000, 1000 * 2 ** attempt);
}
