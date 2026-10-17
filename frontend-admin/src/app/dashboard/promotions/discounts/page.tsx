'use client';

import { Percent } from 'lucide-react';
import PromotionPlaceholder from '../../../../components/promotions/PromotionPlaceholder';

export default function DiscountsPage() {
  return (
    <PromotionPlaceholder
      title="Diskon"
      description="Potongan harga produk atau kategori dalam periode tertentu."
      icon={Percent}
    />
  );
}
