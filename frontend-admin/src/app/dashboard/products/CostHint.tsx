/** Margin per unit against the selling price, so the admin sees the profit while typing the cost. */
export default function CostHint({ price, cost }: { price: string; cost: string }) {
  if (!cost) {
    return <span className="mt-1 block font-normal text-slate-400">Tidak tampil ke pembeli. Dipakai untuk menghitung laba.</span>;
  }
  const sell = Number(price || 0);
  const margin = sell - Number(cost);
  const pct = sell > 0 ? (margin / sell) * 100 : 0;
  return (
    <span className={`mt-1 block font-normal ${margin < 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
      Laba per unit: {margin < 0 ? '−' : ''}Rp{Math.abs(margin).toLocaleString('id-ID')} (
      {pct.toLocaleString('id-ID', { maximumFractionDigits: 1 })}%)
    </span>
  );
}
