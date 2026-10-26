/** wa.me chat link for an Indonesian phone number (08…, +62…, 62… or 8…), or null when there is no usable number. */
export function waLink(phone?: string | null): string | null {
  let digits = (phone ?? '').replace(/\D/g, '');
  if (digits.startsWith('0')) digits = `62${digits.slice(1)}`;
  else if (digits.startsWith('8')) digits = `62${digits}`;

  return digits.length >= 9 ? `https://wa.me/${digits}` : null;
}
