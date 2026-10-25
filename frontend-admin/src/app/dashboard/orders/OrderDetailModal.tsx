'use client';

import React, { useEffect, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Loader2, QrCode, X } from 'lucide-react';
import { apiRequest } from '../../../lib/api';
import { useLabels } from '../../../lib/labels';
import { useOrderTabs, PAYMENT_LABELS, rupiah } from './orderShared';
import { formatDateTime } from '../../../lib/date';

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 py-1 text-sm">
      <span className="shrink-0 text-slate-500">{label}</span>
      <span className="text-right font-medium text-slate-800">{children}</span>
    </div>
  );
}

function Section({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-slate-200 p-4">
      {title && <h4 className="mb-2 text-sm font-bold text-slate-900">{title}</h4>}
      {children}
    </div>
  );
}

const byLabel = (by?: string) =>
  !by ? '' : by === 'system' ? 'Sistem' : by === 'buyer' ? 'Pembeli' : by.startsWith('admin') ? 'Admin' : by;

export default function OrderDetailModal({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const [order, setOrder] = useState<any>(null);
  const [error, setError] = useState('');
  const [showQr, setShowQr] = useState(false);
  const tabs = useOrderTabs();
  const { get: getLabel } = useLabels();

  useEffect(() => {
    apiRequest<any>(`/admin/orders/${orderId}`)
      .then(setOrder)
      .catch((e) => setError(e instanceof Error ? e.message : 'Gagal memuat detail pesanan.'));
  }, [orderId]);

  const tab = tabs.find((t) => t.value === order?.status);
  const pay = order && (PAYMENT_LABELS[order.payment_status] ?? { label: order.payment_status, cls: 'bg-slate-100 text-slate-600' });
  const addr = order?.delivery_address;
  const fullAddress = addr
    ? [addr.address_detail, addr.village_name, addr.district_name, addr.city_name, addr.province_name]
        .filter((x) => x && String(x).trim())
        .join(', ')
    : '';
  const slot = order?.delivery_slot;
  const packages: any[] = order?.packages ?? [];
  const qrItems: { label: string; value: string }[] = packages.some((p) => p.qr_code)
    ? packages
        .filter((p) => p.qr_code)
        .map((p) => ({ label: `Paket ${p.number} dari ${packages.length}`, value: p.qr_code }))
    : order?.qr_code
    ? [{ label: order.order_number, value: order.qr_code }]
    : [];
  const findItem = (id: any) => order.items?.find((i: any) => String(i.id) === String(id));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4" onClick={onClose}>
      <div
        className="flex max-h-[90vh] w-full max-w-2xl flex-col rounded-2xl bg-white shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <h3 className="text-base font-extrabold text-slate-900">{order?.order_number ?? 'Detail Pesanan'}</h3>
          <button onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="space-y-3 overflow-y-auto p-5">
          {!order && !error && (
            <div className="flex justify-center py-12 text-emerald-600">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          )}
          {error && <p className="py-8 text-center text-sm text-red-600">{error}</p>}

          {order && (
            <>
              <Section>
                <div className="mb-2 flex items-center justify-between">
                  <span className="text-xs text-slate-500">{formatDateTime(order.created_at)}</span>
                  <span className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${tab?.badge ?? 'bg-slate-100 text-slate-600'}`}>
                    {tab?.label ?? order.status}
                  </span>
                </div>
                <Row label="Pembeli">{order.user?.name ?? '-'}</Row>
                <Row label="Pembayaran">
                  {order.payment_method?.name ?? '-'}{' '}
                  <span className={`ml-1 rounded-full px-2 py-0.5 text-[11px] font-bold ${pay.cls}`}>{pay.label}</span>
                </Row>
                {order.paid_at && <Row label="Dibayar">{formatDateTime(order.paid_at)}</Row>}
                {qrItems.length > 0 && (
                  <button
                    onClick={() => setShowQr(true)}
                    className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl border border-emerald-600 py-2 text-sm font-bold text-emerald-700 hover:bg-emerald-50"
                  >
                    <QrCode className="h-4 w-4" /> Lihat QR Code
                  </button>
                )}
              </Section>

              {packages.length > 0 && (
                <Section title={`Paket (${packages.length})`}>
                  {packages.map((p) => (
                    <div key={p.number} className="py-1 text-sm">
                      <p className="font-semibold">{packages.length > 1 ? `Paket ${p.number} dari ${packages.length}` : 'Paket 1'}</p>
                      {(p.items ?? []).map((l: any, i: number) => {
                        const it = findItem(l.order_item_id);
                        return (
                          <p key={i} className="text-xs text-slate-600">
                            {l.quantity} × {it?.product_name ?? '-'}
                            {it?.variant_name ? ` (${it.variant_name})` : ''}
                          </p>
                        );
                      })}
                    </div>
                  ))}
                </Section>
              )}

              <Section title="Pengiriman">
                <Row label="Metode">{order.shipping_method?.name ?? order.delivery_method ?? '-'}</Row>
                {order.shipping_method?.type && (
                  <Row label="Jenis">{getLabel('shipping_type', order.shipping_method.type).label}</Row>
                )}
                {order.delivery_date && <Row label="Tanggal">{order.delivery_date}</Row>}
                {slot && <Row label="Slot">{`${slot.label ?? ''} (${slot.start_time} - ${slot.end_time})`}</Row>}
                {addr?.recipient_name && <Row label="Penerima">{addr.recipient_name}</Row>}
                {addr?.recipient_phone && <Row label="Telepon">{addr.recipient_phone}</Row>}
                {fullAddress && <p className="mt-1 text-sm text-slate-700">{fullAddress}</p>}
              </Section>

              <Section title={`Produk (${order.items?.length ?? 0})`}>
                <div className="divide-y divide-slate-100">
                  {(order.items ?? []).map((it: any) => (
                    <div key={it.id} className="flex items-start gap-3 py-2">
                      {it.product_image_url && (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={it.product_image_url} alt="" className="h-12 w-12 rounded-lg object-cover" />
                      )}
                      <div className="min-w-0 flex-1 text-sm">
                        <p className="font-semibold text-slate-800">{it.product_name}</p>
                        {it.variant_name && <p className="text-xs text-slate-500">{it.variant_name}</p>}
                        <p className="text-xs text-slate-500">
                          {it.quantity} × {rupiah(it.unit_price)}
                        </p>
                        {it.notes && <p className="text-xs italic">Catatan: {it.notes}</p>}
                      </div>
                      <span className="text-sm font-semibold">{rupiah(it.line_total)}</span>
                    </div>
                  ))}
                </div>
                <div className="mt-2 border-t border-slate-100 pt-2">
                  <Row label="Subtotal">{rupiah(order.subtotal)}</Row>
                  {order.discount_total > 0 && <Row label="Diskon">- {rupiah(order.discount_total)}</Row>}
                  <Row label="Ongkir">{rupiah(order.shipping_fee)}</Row>
                  {order.service_fee > 0 && <Row label="Biaya layanan">{rupiah(order.service_fee)}</Row>}
                  <Row label="Total">
                    <span className="font-extrabold text-emerald-700">{rupiah(order.grand_total)}</span>
                  </Row>
                </div>
              </Section>

              {(order.customer_notes || order.admin_notes) && (
                <Section title="Catatan">
                  {order.customer_notes && <Row label="Pembeli">{order.customer_notes}</Row>}
                  {order.admin_notes && <Row label="Admin">{order.admin_notes}</Row>}
                </Section>
              )}

              {Array.isArray(order.status_history) && order.status_history.length > 0 && (
                <Section title="Riwayat Status">
                  {[...order.status_history].reverse().map((h: any, i: number) => (
                    <div key={i} className="flex justify-between gap-3 py-1 text-sm">
                      <span>{tabs.find((t) => t.value === h.status)?.label ?? h.status}</span>
                      <span className="text-xs text-slate-500">
                        {[h.at ? formatDateTime(h.at) : '', byLabel(h.by)].filter(Boolean).join(' · ')}
                      </span>
                    </div>
                  ))}
                </Section>
              )}
            </>
          )}
        </div>
      </div>

      {showQr && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-slate-900/60 p-4"
          onClick={(e) => {
            e.stopPropagation();
            setShowQr(false);
          }}
        >
          <div
            className="max-h-[90vh] w-full max-w-sm overflow-y-auto rounded-2xl bg-white p-5 text-center shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-3 flex items-center justify-between">
              <h4 className="font-extrabold text-slate-900">QR Code {order?.order_number}</h4>
              <button onClick={() => setShowQr(false)} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100">
                <X className="h-5 w-5" />
              </button>
            </div>
            {qrItems.map((q) => (
              <div key={q.label} className="mb-4 flex flex-col items-center gap-1">
                <QRCodeSVG value={q.value} size={220} level="M" />
                <span className="text-sm font-semibold text-slate-700">{q.label}</span>
              </div>
            ))}
            <p className="text-xs text-slate-500">
              {packages.length > 1
                ? `Tempel QR di paket yang sesuai. Driver scan salah satu QR dan wajib membawa semua ${packages.length} paket.`
                : 'Driver scan QR ini saat mengambil dan menyerahkan paket.'}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
