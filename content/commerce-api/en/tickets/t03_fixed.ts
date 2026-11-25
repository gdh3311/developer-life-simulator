// Masks the middle of a Korean mobile number for receipts: 010-****-5678.
export function maskPhone(phone: string): string {
  const digits = phone.replace(/-/g, '');
  if (!/^01\d{8,9}$/.test(digits)) return phone;
  return `${digits.slice(0, 3)}-****-${digits.slice(-4)}`;
}
