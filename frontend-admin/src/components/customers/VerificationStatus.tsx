import Link from 'next/link';
import { CheckCircle, ShieldOff, XCircle } from 'lucide-react';
import { Customer } from '../../types';

/**
 * A customer's single face-verification status. Links to the event behind it, so a
 * revoked status shows which recording it was revoked on.
 */
export default function VerificationStatus({ customer }: { customer: Pick<Customer, 'verification_status' | 'verification_id'> }) {
  const eventHref = customer.verification_id ? `/dashboard/cod-verifications?event=${customer.verification_id}` : null;

  if (customer.verification_status === 'verified') {
    return (
      <span className="inline-flex flex-col items-start gap-0.5">
        <span className="inline-flex items-center gap-1 rounded-md bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700">
          <CheckCircle className="h-3.5 w-3.5" /> Terverifikasi
        </span>
        {eventHref && (
          <Link href={eventHref} className="text-[11px] font-medium text-slate-500 hover:text-emerald-700 hover:underline">
            Lihat event
          </Link>
        )}
      </span>
    );
  }

  if (customer.verification_status === 'revoked') {
    return (
      <span className="inline-flex flex-col items-start gap-0.5">
        <span className="inline-flex items-center gap-1 rounded-md bg-rose-50 px-2 py-0.5 text-xs font-semibold text-rose-700">
          <ShieldOff className="h-3.5 w-3.5" /> Dicabut
        </span>
        {eventHref && (
          <Link href={eventHref} className="text-[11px] font-medium text-slate-500 hover:text-rose-700 hover:underline">
            Lihat event yang dicabut
          </Link>
        )}
      </span>
    );
  }

  return (
    <span className="inline-flex items-center gap-1 rounded-md bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500">
      <XCircle className="h-3.5 w-3.5" /> Belum Verifikasi
    </span>
  );
}
