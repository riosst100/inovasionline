'use client';

import React, { Suspense, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { CustomerDetail, LoginMethod } from '../../../../types';
import {
  AlertCircle,
  ArrowLeft,
  Ban,
  BellRing,
  CheckCircle,
  Globe,
  History,
  KeyRound,
  Loader2,
  LogOut,
  Monitor,
  Smartphone,
  User as UserIcon,
  XCircle,
} from 'lucide-react';

const METHOD_LABELS: Record<LoginMethod, string> = {
  password: 'Password',
  google: 'Google',
  register: 'Registrasi',
};

const fmtDate = (iso: string | null | undefined) =>
  iso
    ? new Date(iso).toLocaleString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '-';

function timeAgo(iso: string | null): string {
  if (!iso) return '-';
  const diff = Math.max(0, Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'Baru saja';
  if (diff < 3600) return `${Math.floor(diff / 60)} menit lalu`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`;
  return `${Math.floor(diff / 86400)} hari lalu`;
}

const isMobileDevice = (device: string | null, ua: string | null) =>
  /Android|iOS|iPhone|iPad|Mobile/i.test(`${device ?? ''} ${ua ?? ''}`) || (ua ?? '').startsWith('Dart/');

function Card({ title, icon: Icon, children }: {
  title: string;
  icon: React.ElementType;
  children: React.ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-xs">
      <div className="flex items-center gap-2 border-b border-slate-100 px-5 py-3.5">
        <Icon className="h-4 w-4 text-emerald-600" />
        <h3 className="text-sm font-bold text-slate-900">{title}</h3>
      </div>
      {children}
    </section>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-[11px] font-bold uppercase tracking-wider text-slate-400">{label}</dt>
      <dd className="mt-0.5 break-words text-sm font-medium text-slate-800">{children}</dd>
    </div>
  );
}

function VerifiedBadge({ at }: { at: string | null }) {
  return at ? (
    <span className="inline-flex items-center gap-1 text-emerald-700">
      <CheckCircle className="h-3.5 w-3.5" /> {fmtDate(at)}
    </span>
  ) : (
    <span className="inline-flex items-center gap-1 text-slate-400">
      <XCircle className="h-3.5 w-3.5" /> Belum
    </span>
  );
}

const Empty = ({ text }: { text: string }) => <p className="p-6 text-center text-sm text-slate-400">{text}</p>;

function CustomerDetailPageContent() {
  const { id } = useParams<{ id: string }>();
  const [data, setData] = useState<CustomerDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busySession, setBusySession] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setData(await adminApi.getCustomerDetail(id));
      setError(null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat detail customer.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  const revoke = async (sessionId: string, device: string) => {
    if (!confirm(`Hentikan sesi "${device}"? Customer akan logout dari perangkat tersebut.`)) return;
    try {
      setBusySession(sessionId);
      await adminApi.revokeCustomerSession(id, sessionId);
      await load();
    } catch (e) {
      window.alert(e instanceof ApiError ? e.message : 'Gagal menghentikan sesi.');
    } finally {
      setBusySession(null);
    }
  };

  const c = data?.customer;

  return (
    <AdminLayout>
      <div className="space-y-6">
        <Link
          href="/dashboard/customers"
          className="inline-flex items-center gap-1 text-xs font-semibold text-slate-500 hover:text-slate-800"
        >
          <ArrowLeft className="h-4 w-4" /> Kembali ke daftar pelanggan
        </Link>

        {loading ? (
          <div className="flex justify-center p-16">
            <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
          </div>
        ) : error || !data || !c ? (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error ?? 'Customer tidak ditemukan.'}
          </div>
        ) : (
          <>
            {/* Header */}
            <div className="flex flex-wrap items-center gap-4">
              {c.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={c.avatar_url} alt="" className="h-14 w-14 rounded-full object-cover" />
              ) : (
                <div className="flex h-14 w-14 items-center justify-center rounded-full bg-slate-200 text-base font-bold text-slate-700">
                  {c.name.slice(0, 2).toUpperCase()}
                </div>
              )}
              <div className="min-w-0">
                <h2 className="text-xl md:text-2xl font-extrabold text-slate-900">{c.name}</h2>
                <div className="mt-1 flex flex-wrap items-center gap-1.5">
                  {c.is_blocked ? (
                    <span
                      title={c.block_reason || undefined}
                      className="inline-flex items-center gap-1 rounded-md bg-red-50 px-2 py-0.5 text-xs font-semibold text-red-700"
                    >
                      <Ban className="h-3.5 w-3.5" /> Diblokir
                    </span>
                  ) : (
                    <span className="rounded-md bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700">Aktif</span>
                  )}
                  {c.is_verified && (
                    <span className="rounded-md bg-sky-50 px-2 py-0.5 text-xs font-semibold text-sky-700">KYC Terverifikasi</span>
                  )}
                  {(c.banned_features ?? []).map((f) => (
                    <span key={f} className="rounded-md bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-700">
                      Banned: {f}
                    </span>
                  ))}
                </div>
              </div>
            </div>

            <div className="grid gap-6 lg:grid-cols-2">
              {/* Customer detail */}
              <Card title="Detail Customer" icon={UserIcon}>
                <dl className="grid grid-cols-1 gap-4 p-5 sm:grid-cols-2">
                  <Field label="Email">{c.email || '-'}</Field>
                  <Field label="No. Telepon">{c.phone || '-'}</Field>
                  <Field label="Jenis Kelamin">
                    {c.gender === 'male' ? 'Laki-laki' : c.gender === 'female' ? 'Perempuan' : c.gender || '-'}
                  </Field>
                  <Field label="Tanggal Lahir">
                    {c.date_of_birth ? new Date(c.date_of_birth).toLocaleDateString('id-ID', { dateStyle: 'long' }) : '-'}
                  </Field>
                  <Field label="Alamat">{c.address_label || '-'}</Field>
                  <Field label="Saldo Dompet">
                    Rp {Number(c.wallet_balance ?? 0).toLocaleString('id-ID')}
                  </Field>
                  <Field label="Terdaftar Sejak">{fmtDate(c.created_at)}</Field>
                  <Field label="ID">{<span className="font-mono text-xs">{c.id}</span>}</Field>
                  {c.is_blocked && <Field label="Alasan Blokir">{c.block_reason || '-'}</Field>}
                  {(c.banned_features ?? []).length > 0 && <Field label="Alasan Banned">{c.ban_reason || '-'}</Field>}
                </dl>
              </Card>

              {/* Login detail */}
              <Card title="Detail Login" icon={KeyRound}>
                <dl className="grid grid-cols-1 gap-4 p-5 sm:grid-cols-2">
                  <Field label="Metode Login">
                    <div className="flex flex-wrap gap-1">
                      {data.login.has_password && (
                        <span className="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-700">Password</span>
                      )}
                      {data.login.google_linked && (
                        <span className="rounded-md bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-700">Google</span>
                      )}
                      {!data.login.has_password && !data.login.google_linked && '-'}
                    </div>
                  </Field>
                  <Field label="Email Terverifikasi"><VerifiedBadge at={data.login.email_verified_at} /></Field>
                  <Field label="Telepon Terverifikasi"><VerifiedBadge at={data.login.phone_verified_at} /></Field>
                  <Field label="Login Terakhir">
                    {data.login.last_login_at ? (
                      <>
                        {fmtDate(data.login.last_login_at)}
                        <span className="block text-xs text-slate-400">
                          via {METHOD_LABELS[data.login.last_login_method!] ?? data.login.last_login_method}
                          {data.login.last_login_ip ? ` · IP ${data.login.last_login_ip}` : ''}
                        </span>
                      </>
                    ) : (
                      '-'
                    )}
                  </Field>
                  <Field label="Total Login Tercatat">{data.login.login_count}x</Field>
                  <Field label="Sesi Aktif">{data.login.active_session_count}</Field>
                </dl>
              </Card>
            </div>

            {/* Active sessions / devices */}
            <Card
              title={`Perangkat & Sesi Aktif (${data.sessions.length})`}
              icon={Smartphone}
            >
              {data.sessions.length === 0 ? (
                <Empty text="Tidak ada sesi aktif." />
              ) : (
                <div className="divide-y divide-slate-100">
                  {data.sessions.map((s) => {
                    const Icon = isMobileDevice(s.device, s.user_agent) ? Smartphone : Monitor;
                    return (
                      <div key={`${s.type}-${s.id}`} className="flex items-center gap-4 px-5 py-4">
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-600">
                          <Icon className="h-5 w-5" />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="font-semibold text-slate-900">{s.device}</span>
                            <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase text-slate-500">
                              {s.type === 'web' ? 'Web' : 'Token'}
                            </span>
                          </div>
                          <p className="text-xs text-slate-500">
                            Terakhir aktif {timeAgo(s.last_active_at)}
                            {s.ip_address ? ` · IP ${s.ip_address}` : ''}
                            {s.created_at ? ` · Login ${fmtDate(s.created_at)}` : ''}
                          </p>
                          {s.user_agent && (
                            <p className="truncate text-[11px] text-slate-400" title={s.user_agent}>{s.user_agent}</p>
                          )}
                        </div>
                        <button
                          onClick={() => revoke(s.id, s.device)}
                          disabled={busySession !== null}
                          className="inline-flex shrink-0 items-center gap-1 rounded-lg border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-50 disabled:opacity-50"
                        >
                          {busySession === s.id ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <LogOut className="h-3.5 w-3.5" />}
                          Hentikan
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </Card>

            <div className="grid gap-6 lg:grid-cols-2">
              {/* IP addresses */}
              <Card title={`Alamat IP (${data.ip_addresses.length})`} icon={Globe}>
                {data.ip_addresses.length === 0 ? (
                  <Empty text="Belum ada IP tercatat." />
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-xs">
                      <thead className="border-b border-slate-100 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                        <tr>
                          <th className="px-5 py-2.5">IP</th>
                          <th className="px-5 py-2.5">Login</th>
                          <th className="px-5 py-2.5">Sesi Aktif</th>
                          <th className="px-5 py-2.5">Terakhir Terlihat</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {data.ip_addresses.map((ip) => (
                          <tr key={ip.ip_address}>
                            <td className="px-5 py-3 font-mono font-semibold text-slate-800">{ip.ip_address}</td>
                            <td className="px-5 py-3 text-slate-600">{ip.login_count}x</td>
                            <td className="px-5 py-3 text-slate-600">{ip.active_sessions}</td>
                            <td className="px-5 py-3 text-slate-500" title={`Pertama: ${fmtDate(ip.first_seen_at)}`}>
                              {fmtDate(ip.last_seen_at)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </Card>

              {/* Push notification devices */}
              <Card title={`Perangkat Notifikasi (${data.push_devices.length})`} icon={BellRing}>
                {data.push_devices.length === 0 ? (
                  <Empty text="Belum ada perangkat terdaftar untuk notifikasi." />
                ) : (
                  <div className="divide-y divide-slate-100">
                    {data.push_devices.map((d) => (
                      <div key={d.id} className="flex items-center gap-3 px-5 py-3">
                        <Smartphone className="h-4 w-4 shrink-0 text-slate-400" />
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-semibold capitalize text-slate-800">{d.platform}</p>
                          <p className="truncate font-mono text-[11px] text-slate-400">{d.token_preview}</p>
                        </div>
                        <div className="text-right text-[11px] text-slate-500">
                          <p>Terdaftar {fmtDate(d.registered_at)}</p>
                          <p>Diperbarui {timeAgo(d.updated_at)}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </Card>
            </div>

            {/* Login history */}
            <Card title="Riwayat Login (50 terakhir)" icon={History}>
              {data.login_history.length === 0 ? (
                <Empty text="Belum ada riwayat login tercatat." />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="border-b border-slate-100 bg-slate-50/80 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                      <tr>
                        <th className="px-5 py-2.5">Waktu</th>
                        <th className="px-5 py-2.5">Metode</th>
                        <th className="px-5 py-2.5">Perangkat</th>
                        <th className="px-5 py-2.5">IP</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {data.login_history.map((log) => (
                        <tr key={log.id}>
                          <td className="whitespace-nowrap px-5 py-3 text-slate-600">{fmtDate(log.created_at)}</td>
                          <td className="px-5 py-3">
                            <span className="rounded-md bg-slate-100 px-2 py-0.5 font-semibold text-slate-700">
                              {METHOD_LABELS[log.method] ?? log.method}
                            </span>
                          </td>
                          <td className="px-5 py-3 text-slate-700" title={log.user_agent || undefined}>
                            {log.device || '-'}
                            <span className="ml-1 text-slate-400">({log.client === 'mobile' ? 'App' : 'Web'})</span>
                          </td>
                          <td className="px-5 py-3 font-mono text-slate-600">{log.ip_address || '-'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Card>
          </>
        )}
      </div>
    </AdminLayout>
  );
}

// useParams() must sit inside <Suspense> or prerendering the dynamic route fails the build.
export default function CustomerDetailPage() {
  return (
    <Suspense>
      <CustomerDetailPageContent />
    </Suspense>
  );
}
