'use client';

import { Ticket } from 'lucide-react';
import PromotionPlaceholder from '../../../../components/promotions/PromotionPlaceholder';

export default function VouchersPage() {
  return (
    <PromotionPlaceholder
      title="Voucher"
      description="Kode voucher yang bisa dipakai customer saat checkout untuk potongan harga atau ongkir."
      icon={Ticket}
    />
  );
}
