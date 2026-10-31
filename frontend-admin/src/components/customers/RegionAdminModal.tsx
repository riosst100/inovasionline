'use client';

import React, { useEffect, useState } from 'react';
import { Loader2, Pencil, ShieldCheck, Trash2 } from 'lucide-react';
import { adminApi } from '../../lib/api';
import { CommunityRole, Customer, RegionItem } from '../../types';

const LEVEL_LABELS: Record<string, string> = { city: 'Kab/Kota', district: 'Kecamatan', village: 'Desa' };

const DEFAULT_BADGE_TEXT = 'Admin <wilayah>';

/**
 * Appoints a customer to a city, district or village (the deepest region picked) with a community role, which
 * sets what they may delete there, and a freely worded badge such as "Kepala Desa <wilayah>". They also join
 * that region's chat.
 */
export default function RegionAdminModal({
  customer,
  onClose,
  onUpdated,
}: {
  customer: Customer;
  onClose: () => void;
  onUpdated: (updated: Customer) => void;
}) {
  const [provinces, setProvinces] = useState<RegionItem[]>([]);
  const [cities, setCities] = useState<RegionItem[]>([]);
  const [districts, setDistricts] = useState<RegionItem[]>([]);
  const [villages, setVillages] = useState<RegionItem[]>([]);
  const [province, setProvince] = useState('');
  const [city, setCity] = useState('');
  const [district, setDistrict] = useState('');
  const [village, setVillage] = useState('');
  const [roles, setRoles] = useState<CommunityRole[]>([]);
  const [roleId, setRoleId] = useState('');
  const [badgeText, setBadgeText] = useState(DEFAULT_BADGE_TEXT);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getRegionProvinces().then(setProvinces).catch(() => setProvinces([]));
    adminApi
      .getCommunityRoles()
      .then((res) => {
        setRoles(res.roles);
        setRoleId((current) => current || res.roles[0]?.id || '');
      })
      .catch(() => setRoles([]));
  }, []);

  const editBadgeText = (id: string, current: string) => {
    const text = window.prompt('Teks badge (<wilayah> diganti nama wilayah):', current);
    if (text === null || !text.trim()) return;
    run(() => adminApi.updateCustomerRegionAdmin(customer.id, id, { badge_text: text.trim() }));
  };

  const pickProvince = async (code: string) => {
    setProvince(code);
    setCity('');
    setDistrict('');
    setVillage('');
    setCities(code ? await adminApi.getRegionCities(code) : []);
    setDistricts([]);
    setVillages([]);
  };

  const pickCity = async (code: string) => {
    setCity(code);
    setDistrict('');
    setVillage('');
    setDistricts(code ? await adminApi.getRegionDistricts(code) : []);
    setVillages([]);
  };

  const pickDistrict = async (code: string) => {
    setDistrict(code);
    setVillage('');
    setVillages(code ? await adminApi.getRegionVillages(code) : []);
  };

  const regionCode = village || district || city;

  const run = async (action: () => Promise<Customer>) => {
    try {
      setBusy(true);
      setError('');
      onUpdated(await action());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal menyimpan admin wilayah.');
    } finally {
      setBusy(false);
    }
  };

  const select = (
    label: string,
    value: string,
    items: RegionItem[],
    onChange: (code: string) => void,
    disabled = false
  ) => (
    <label className="block text-xs font-semibold text-slate-700">
      {label}
      <select
        value={value}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full rounded-xl border border-slate-200 p-2.5 text-sm outline-none focus:border-emerald-500 disabled:bg-slate-50"
      >
        <option value="">— Pilih —</option>
        {items.map((r) => (
          <option key={r.code} value={r.code}>
            {r.name}
          </option>
        ))}
      </select>
    </label>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
        <h3 className="text-lg font-extrabold text-slate-900">Admin wilayah: {customer.name}</h3>
        <p className="mt-1 text-xs text-slate-500">
          Mendapat badge di aplikasi dan ikut grup chat wilayahnya. Yang boleh dihapus (postingan, komentar, chat)
          mengikuti peran, yang diatur di tombol Peran Komunitas.
        </p>

        <div className="mt-4 space-y-2">
          {customer.region_admins.length === 0 ? (
            <p className="text-xs text-slate-400">Belum menjadi admin wilayah mana pun.</p>
          ) : (
            customer.region_admins.map((a) => (
              <div key={a.id} className="flex items-center justify-between gap-2 rounded-xl border border-slate-200 px-3 py-2">
                <div className="min-w-0">
                  <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-800">
                    <ShieldCheck className="h-4 w-4 shrink-0 text-emerald-600" /> {a.label}
                    <button
                      onClick={() => editBadgeText(a.id, a.badge_text)}
                      disabled={busy}
                      title="Ubah teks badge"
                      className="rounded p-0.5 text-slate-400 hover:text-slate-700"
                    >
                      <Pencil className="h-3.5 w-3.5" />
                    </button>
                  </span>
                  <div className="mt-1 flex items-center gap-2 text-[11px] text-slate-400">
                    {LEVEL_LABELS[a.region_level]} {a.region_name} ·
                    <select
                      value={a.community_role_id ?? ''}
                      disabled={busy}
                      onChange={(e) =>
                        run(() => adminApi.updateCustomerRegionAdmin(customer.id, a.id, { community_role_id: e.target.value }))
                      }
                      className="rounded border border-slate-200 px-1 py-0.5 text-[11px] text-slate-700"
                    >
                      {roles.map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <button
                  onClick={() => run(() => adminApi.removeCustomerRegionAdmin(customer.id, a.id))}
                  disabled={busy}
                  className="rounded-lg p-1.5 text-red-600 hover:bg-red-50 disabled:opacity-50"
                  title="Cabut"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))
          )}
        </div>

        <div className="mt-5 space-y-2 border-t border-slate-100 pt-4">
          <p className="text-xs font-bold text-slate-900">Tambah wilayah</p>
          {select('Provinsi', province, provinces, pickProvince)}
          {select('Kabupaten/Kota', city, cities, pickCity, !province)}
          {select('Kecamatan (opsional)', district, districts, pickDistrict, !city)}
          {select('Desa/Kelurahan (opsional)', village, villages, setVillage, !district)}
          {select(
            'Peran',
            roleId,
            roles.map((r) => ({ code: r.id, name: r.name })),
            setRoleId
          )}
          <label className="block text-xs font-semibold text-slate-700">
            Teks badge
            <input
              value={badgeText}
              maxLength={60}
              onChange={(e) => setBadgeText(e.target.value)}
              placeholder="mis. Kepala Desa <wilayah>"
              className="mt-1 w-full rounded-xl border border-slate-200 p-2.5 text-sm outline-none focus:border-emerald-500"
            />
            <span className="mt-1 block text-[11px] font-normal text-slate-400">
              &lt;wilayah&gt; otomatis diganti nama wilayah yang dipilih.
            </span>
          </label>
        </div>

        {error && <p className="mt-3 text-xs font-semibold text-red-600">{error}</p>}

        <div className="mt-5 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
          >
            Tutup
          </button>
          <button
            onClick={() =>
              run(() =>
                adminApi.addCustomerRegionAdmin(customer.id, {
                  region_code: regionCode,
                  community_role_id: roleId,
                  badge_text: badgeText.trim() || DEFAULT_BADGE_TEXT,
                })
              )
            }
            disabled={busy || !regionCode || !roleId}
            className="inline-flex items-center gap-1 rounded-lg bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {busy && <Loader2 className="h-3.5 w-3.5 animate-spin" />} Jadikan Admin
          </button>
        </div>
      </div>
    </div>
  );
}
