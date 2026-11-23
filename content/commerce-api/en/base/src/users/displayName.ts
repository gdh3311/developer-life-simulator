export type User = {
  firstName?: string | null;
  lastName?: string | null;
};

/**
 * Builds the user name shown on the profile screen.
 * Rules: Company Wiki > "Display name rules"
 */
export function getDisplayName(user: User): string {
  return `${user.firstName} ${user.lastName}`;
}
