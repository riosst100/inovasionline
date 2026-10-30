'use client';

import React from 'react';
import { MapPin } from 'lucide-react';
import LastSeen from './LastSeen';
import { formatDateTime } from '../../lib/date';
import { GuestInstallDetail } from '../../types';

function show(value: unknown): string {
  if (value === null || value === undefined || value === '') return '-';
  if (typeof value === 'boolean') return value ? 'Ya' : 'Tidak';
  if (Array.isArray(value)) return value.length ? value.join(', ') : '-';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function Section({ title, rows }: { title: string; rows: [string, React.ReactNode][] }) {
  return (
    <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-xs">
      <h3 className="mb-3 text-sm font-extrabold text-slate-900">{title}</h3>
      <dl className="divide-y divide-slate-100 text-xs md:text-sm">
        {rows.map(([label, value]) => (
          <div key={label} className="flex flex-col gap-0.5 py-2 sm:flex-row sm:gap-4">
            <dt className="w-56 shrink-0 font-semibold text-slate-500">{label}</dt>
            <dd className="min-w-0 break-all text-slate-900">{value}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

/** Every device / network / location fact stored for one app install (guest or logged-in). */
export default function InstallDetailView({ g }: { g: GuestInstallDetail }) {
  const dt = (v: string | null) => (v ? formatDateTime(new Date(v)) : '-');
  const hasLocation = g.latitude != null && g.longitude != null;
  const mapUrl = hasLocation ? `https://www.google.com/maps?q=${g.latitude},${g.longitude}` : '';

  return (
    <div className="grid gap-4 lg:grid-cols-2">
            <Section
              title="Identitas Install"
              rows={[
                ['Status', g.user ? `Sudah terhubung ke akun ${g.user.name}` : 'Guest (belum daftar / login)'],
                ['Install ID', g.install_id],
                ['Device ID', show(g.device_id)],
                ['Platform', show(g.platform)],
                ['Versi Aplikasi', g.app_version ? `${g.app_version}${g.build_number ? ` (build ${g.build_number})` : ''}` : '-'],
                ['Layar Saat Ini', show(g.current_screen)],
                ['Terakhir Online', <LastSeen key="ls" at={g.last_seen_at} />],
                ['Pertama Terlihat', dt(g.first_seen_at)],
                ['Dibuat', dt(g.created_at)],
                ['Diperbarui', dt(g.updated_at)],
              ]}
            />

            <Section
              title="Perangkat"
              rows={[
                ['Nama Perangkat', show(g.device_name)],
                ['Merek', show(g.device_brand)],
                ['Model', show(g.device_model)],
                ['Versi OS', show(g.os_version)],
                ['Emulator', show(g.is_emulator)],
              ]}
            />

            <Section
              title="Jaringan"
              rows={[
                ['IP Terakhir', show(g.ip_address)],
                ['IP Pertama', show(g.first_ip_address)],
                ['User Agent', show(g.user_agent)],
              ]}
            />

            <Section
              title="Lokasi"
              rows={
                hasLocation
                  ? [
                      ['Latitude', String(g.latitude)],
                      ['Longitude', String(g.longitude)],
                      ['Akurasi', g.location_accuracy != null ? `${Math.round(g.location_accuracy)} m` : '-'],
                      ['Waktu Lokasi', dt(g.location_at)],
                      [
                        'Peta',
                        <a key="map" href={mapUrl} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 font-semibold text-emerald-700 hover:underline">
                          <MapPin className="h-3.5 w-3.5" /> Buka di Google Maps
                        </a>,
                      ],
                    ]
                  : [['Lokasi', 'Belum ada. Pengguna belum memberi izin lokasi atau belum ada posisi tersimpan di perangkat.']]
              }
            />

            <div className="lg:col-span-2">
              <Section
                title="Detail Perangkat Lainnya (dilaporkan aplikasi)"
                rows={
                  g.device_details && Object.keys(g.device_details).length
                    ? Object.entries(g.device_details).map(([k, v]) => [k, show(v)] as [string, React.ReactNode])
                    : [['Detail', '-']]
                }
              />
            </div>

            <Section
              title={`Perangkat Sama, Install Lain (${g.same_device_installs.length})`}
              rows={
                g.same_device_installs.length
                  ? g.same_device_installs.map((i) => [
                      i.install_id.slice(0, 12),
                      `${i.user_id ? 'Punya akun' : 'Guest'} · ${dt(i.last_seen_at)}`,
                    ] as [string, React.ReactNode])
                  : [['Install lain', 'Tidak ada']]
              }
            />

            <Section
              title={`Kontak Dibagikan (${g.contacts_count})`}
              rows={
                g.contacts.length
                  ? g.contacts.map((c) => [show(c.name), c.phone] as [string, React.ReactNode])
                  : [['Kontak', 'Tidak ada']]
              }
            />
          </div>
  );
}
