export type User = {
  firstName?: string | null;
  lastName?: string | null;
  nickname?: string | null;
};

/**
 * Builds the user name shown on the profile screen.
 * Rules: Company Wiki > "Display name rules"
 */
export function getDisplayName(user: User): string {
  if (user.nickname) {
    return user.nickname;
  }
  return `${user.firstName} ${user.lastName}`;
}
