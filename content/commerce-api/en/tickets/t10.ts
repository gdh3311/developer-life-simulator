// Sign-up email check: one @, a dot in the domain, no spaces.
export function isEmail(s: string): boolean {
  return /^[a-z0-9.]+@[a-z0-9]+\.[a-z]+$/.test(s);
}
