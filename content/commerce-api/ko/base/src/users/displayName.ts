export type User = {
  firstName?: string | null;
  lastName?: string | null;
};

/**
 * 프로필 화면에 표시할 사용자 이름을 만든다.
 * 규칙: Company Wiki > "사용자 이름 표시 규칙"
 */
export function getDisplayName(user: User): string {
  return `${user.firstName} ${user.lastName}`;
}
