// Sign-up email check: one @, a dot in the domain, no spaces.
export function isEmail(s: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}
