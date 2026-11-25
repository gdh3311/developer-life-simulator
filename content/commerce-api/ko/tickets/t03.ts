// Masks the middle of a Korean mobile number for receipts: 010-****-5678.
export function maskPhone(phone: string): string {
  return phone.slice(0, -4) + '****';
}
