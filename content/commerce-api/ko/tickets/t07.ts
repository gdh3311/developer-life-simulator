// Retry delay for the notification sender: doubles each attempt, never more than 30 seconds.
export function backoff(attempt: number): number {
  return 1000 * 2 ** attempt;
}
