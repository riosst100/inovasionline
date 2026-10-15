'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../lib/api';
import { titleCase } from '../../lib/text';
import { RegionItem, WarehouseCoverage } from '../../types';
import { Check, Loader2, MapPin, Search, X } from 'lucide-react';

interface Props {
  value: WarehouseCoverage[];
  onChange: (value: WarehouseCoverage[]) => void;
}

type CityOption = RegionItem & { provinceName: string };

const searchCls =
  'w-full rounded-lg border border-slate-200 bg-white py-1.5 pl-8 pr-2 text-sm outline-none focus:border-emerald-500';

export default function CoveragePicker({ value, onChange }: Props) {
  const [cities, setCities] = useState<CityOption[]>([]);
  const [cityCode, setCityCode] = useState('');
  const [districts, setDistricts] = useState<RegionItem[]>([]);
  const [villages, setVillages] = useState<Record<string, RegionItem[]>>({});
  const [active, setActive] = useState('');
  const [loadingDistricts, setLoadingDistricts] = useState(false);
  const [loadingVillages, setLoadingVillages] = useState(false);
  const [districtSearch, setDistrictSearch] = useState('');
  const [villageSearch, setVillageSearch] = useState('');
  const [loadError, setLoadError] = useState<string | null>(null);

  // Supported cities across all supported provinces.
  useEffect(() => {
    (async () => {
      try {
        const provinces = await adminApi.getRegionProvinces();
        const lists = await Promise.all(
          provinces.map(async (p) =>
            (await adminApi.getRegionCities(p.code)).map((c) => ({ ...c, provinceName: p.name }))
          )
        );
        const all = lists.flat();
        setCities(all);
        setCityCode((cur) => cur || all[0]?.code || '');
      } catch {
        setLoadError('Gagal memuat data wilayah.');
      }
    })();
  }, []);

  useEffect(() => {
    if (!cityCode) return;
    let cancelled = false;
    setLoadingDistricts(true);
    setDistrictSearch('');
    adminApi
      .getRegionDistricts(cityCode)
      .then((d) => {
        if (cancelled) return;
        setDistricts(d);
        setActive(d[0]?.code ?? '');
      })
      .catch(() => !cancelled && setLoadError('Gagal memuat kecamatan.'))
      .finally(() => !cancelled && setLoadingDistricts(false));
    return () => {
      cancelled = true;
    };
  }, [cityCode]);

  // Load villages of the active district once.
  useEffect(() => {
    setVillageSearch('');
    if (!active || villages[active]) return;
    let cancelled = false;
    setLoadingVillages(true);
    adminApi
      .getRegionVillages(active)
      .then((list) => !cancelled && setVillages((vs) => ({ ...vs, [active]: list })))
      .catch(() => !cancelled && setLoadError('Gagal memuat desa.'))
      .finally(() => !cancelled && setLoadingVillages(false));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  const whole = useMemo(
    () => new Set(value.filter((v) => v.village_code === null).map((v) => v.district_code)),
    [value]
  );
  const villageCount = useMemo(() => {
    const m: Record<string, number> = {};
    value.forEach((v) => {
      if (v.village_code) m[v.district_code] = (m[v.district_code] ?? 0) + 1;
    });
    return m;
  }, [value]);
  const selectedVillages = useMemo(
    () => new Set(value.filter((v) => v.village_code).map((v) => v.village_code as string)),
    [value]
  );

  const wholeRow = (d: RegionItem): WarehouseCoverage => ({
    district_code: d.code,
    district_name: d.name,
    village_code: null,
    village_name: null,
  });
  const villageRow = (d: RegionItem, v: RegionItem): WarehouseCoverage => ({
    district_code: d.code,
    district_name: d.name,
    village_code: v.code,
    village_name: v.name,
  });
  const without = (code: string) => value.filter((v) => v.district_code !== code);

  const toggleDistrict = (d: RegionItem) =>
    onChange(whole.has(d.code) ? without(d.code) : [...without(d.code), wholeRow(d)]);

  const toggleVillage = (d: RegionItem, v: RegionItem) => {
    const all = villages[d.code] ?? [];
    const current = whole.has(d.code) ? all : all.filter((x) => selectedVillages.has(x.code));
    const next = current.some((x) => x.code === v.code) ? current.filter((x) => x.code !== v.code) : [...current, v];

    if (next.length === 0) return onChange(without(d.code));
    if (next.length === all.length) return onChange([...without(d.code), wholeRow(d)]);
    onChange([...without(d.code), ...next.map((x) => villageRow(d, x))]);
  };

  // Remove a single village from the summary (only possible when the district is not fully selected).
  const removeVillage = (code: string) => onChange(value.filter((v) => v.village_code !== code));

  const activeDistrict = districts.find((d) => d.code === active);
  const activeVillages = villages[active] ?? [];
  const activeWhole = whole.has(active);
  const activeSelected = activeWhole ? activeVillages.length : (villageCount[active] ?? 0);

  const dq = districtSearch.trim().toLowerCase();
  const visibleDistricts = dq ? districts.filter((d) => d.name.toLowerCase().includes(dq)) : districts;
  const vq = villageSearch.trim().toLowerCase();
  const visibleVillages = vq ? activeVillages.filter((v) => v.name.toLowerCase().includes(vq)) : activeVillages;

  const summary = useMemo(() => {
    const map = new Map<string, { name: string; whole: boolean; villages: WarehouseCoverage[] }>();
    value.forEach((v) => {
      const g = map.get(v.district_code) ?? { name: v.district_name, whole: false, villages: [] };
      if (v.village_code === null) g.whole = true;
      else g.villages.push(v);
      map.set(v.district_code, g);
    });
    return [...map.entries()].sort((a, b) => a[1].name.localeCompare(b[1].name));
  }, [value]);
  const totalVillages = value.filter((v) => v.village_code).length;

  return (
    <div className="space-y-4">
      {loadError && <p className="text-xs text-rose-600">{loadError}</p>}

      {cities.length > 1 && (
        <select
          value={cityCode}
          onChange={(e) => setCityCode(e.target.value)}
          className="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500 sm:w-auto"
        >
          {cities.map((c) => (
            <option key={c.code} value={c.code}>
              {titleCase(c.name)} — {titleCase(c.provinceName)}
            </option>
          ))}
        </select>
      )}

      <div className="grid overflow-hidden rounded-xl border border-slate-200 md:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
        {/* Kecamatan */}
        <div className="flex h-96 flex-col border-b border-slate-200 md:border-b-0 md:border-r">
          <div className="border-b border-slate-100 p-2">
            <div className="mb-2 px-1 text-xs font-semibold text-slate-700">
              Kecamatan {districts.length > 0 && <span className="font-normal text-slate-400">({districts.length})</span>}
            </div>
            <div className="relative">
              <Search className="pointer-events-none absolute left-2.5 top-2 h-4 w-4 text-slate-400" />
              <input
                value={districtSearch}
                onChange={(e) => setDistrictSearch(e.target.value)}
                placeholder="Cari kecamatan..."
                className={searchCls}
              />
            </div>
          </div>
          <div className="flex-1 overflow-y-auto">
            {loadingDistricts ? (
              <div className="flex justify-center p-6">
                <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
              </div>
            ) : visibleDistricts.length === 0 ? (
              <p className="p-4 text-center text-sm text-slate-400">Kecamatan tidak ditemukan.</p>
            ) : (
              <ul>
                {visibleDistricts.map((d) => {
                  const isWhole = whole.has(d.code);
                  const n = villageCount[d.code] ?? 0;
                  const partial = !isWhole && n > 0;
                  const isActive = d.code === active;
                  return (
                    <li key={d.code}>
                      <div
                        onClick={() => setActive(d.code)}
                        className={`flex cursor-pointer items-center gap-2 border-l-2 px-3 py-2 text-sm ${
                          isActive
                            ? 'border-emerald-500 bg-emerald-50 font-semibold text-emerald-800'
                            : 'border-transparent text-slate-700 hover:bg-slate-50'
                        }`}
                      >
                        <input
                          type="checkbox"
                          aria-label={`Pilih seluruh Kecamatan ${titleCase(d.name)}`}
                          checked={isWhole}
                          ref={(el) => {
                            if (el) el.indeterminate = partial;
                          }}
                          onClick={(e) => e.stopPropagation()}
                          onChange={() => toggleDistrict(d)}
                        />
                        <span className="flex-1 truncate">{titleCase(d.name)}</span>
                        {isWhole && (
                          <span className="rounded-full bg-emerald-100 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-700">
                            Semua
                          </span>
                        )}
                        {partial && (
                          <span className="rounded-full bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-700">
                            {n} desa
                          </span>
                        )}
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </div>

        {/* Desa */}
        <div className="flex h-96 flex-col">
          <div className="space-y-2 border-b border-slate-100 p-2">
            <div className="flex flex-wrap items-center justify-between gap-2 px-1">
              <div className="text-xs font-semibold text-slate-700">
                {activeDistrict ? (
                  <>
                    Desa di Kecamatan {titleCase(activeDistrict.name)}{' '}
                    {activeVillages.length > 0 && (
                      <span className="font-normal text-slate-400">
                        ({activeSelected}/{activeVillages.length} dipilih)
                      </span>
                    )}
                  </>
                ) : (
                  'Desa'
                )}
              </div>
              {activeDistrict && (
                <div className="flex gap-1.5">
                  <button
                    type="button"
                    onClick={() => !activeWhole && toggleDistrict(activeDistrict)}
                    disabled={activeWhole}
                    className="inline-flex items-center gap-1 rounded-md border border-slate-200 px-2 py-1 text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-40"
                  >
                    <Check className="h-3 w-3" /> Pilih semua
                  </button>
                  <button
                    type="button"
                    onClick={() => onChange(without(activeDistrict.code))}
                    disabled={!activeWhole && (villageCount[active] ?? 0) === 0}
                    className="rounded-md border border-slate-200 px-2 py-1 text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-40"
                  >
                    Kosongkan
                  </button>
                </div>
              )}
            </div>
            <div className="relative">
              <Search className="pointer-events-none absolute left-2.5 top-2 h-4 w-4 text-slate-400" />
              <input
                value={villageSearch}
                onChange={(e) => setVillageSearch(e.target.value)}
                placeholder="Cari desa..."
                disabled={!activeDistrict}
                className={searchCls}
              />
            </div>
          </div>
          <div className="flex-1 overflow-y-auto p-2">
            {!activeDistrict ? (
              <p className="p-4 text-center text-sm text-slate-400">Pilih kecamatan di sebelah kiri.</p>
            ) : loadingVillages && activeVillages.length === 0 ? (
              <div className="flex justify-center p-6">
                <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
              </div>
            ) : visibleVillages.length === 0 ? (
              <p className="p-4 text-center text-sm text-slate-400">Desa tidak ditemukan.</p>
            ) : (
              <div className="grid gap-1 sm:grid-cols-2">
                {visibleVillages.map((v) => {
                  const checked = activeWhole || selectedVillages.has(v.code);
                  return (
                    <label
                      key={v.code}
                      className={`flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-sm ${
                        checked ? 'bg-emerald-50 text-emerald-800' : 'text-slate-700 hover:bg-slate-50'
                      }`}
                    >
                      <input type="checkbox" checked={checked} onChange={() => toggleVillage(activeDistrict, v)} />
                      {titleCase(v.name)}
                    </label>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Ringkasan */}
      <div className="rounded-xl bg-slate-50 p-3">
        <div className="mb-2 flex items-center justify-between">
          <span className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
            <MapPin className="h-3.5 w-3.5 text-emerald-600" />
            Area terpilih
            <span className="font-normal text-slate-500">
              · {summary.length} kecamatan{totalVillages > 0 ? `, ${totalVillages} desa tertentu` : ''}
            </span>
          </span>
          {value.length > 0 && (
            <button type="button" onClick={() => onChange([])} className="text-xs font-medium text-rose-600 hover:underline">
              Hapus semua
            </button>
          )}
        </div>
        {summary.length === 0 ? (
          <p className="text-xs text-slate-400">Belum ada area dipilih. Centang kecamatan atau desa di atas.</p>
        ) : (
          <ul className="space-y-2">
            {summary.map(([code, g]) => (
              <li key={code} className="rounded-lg border border-slate-200 bg-white p-2">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-sm font-medium text-slate-800">Kecamatan {titleCase(g.name)}</span>
                  <button
                    type="button"
                    onClick={() => onChange(without(code))}
                    aria-label={`Hapus Kecamatan ${titleCase(g.name)}`}
                    className="rounded p-0.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                  >
                    <X className="h-4 w-4" />
                  </button>
                </div>
                {g.whole ? (
                  <span className="mt-1 inline-block rounded-full bg-emerald-100 px-2 py-0.5 text-[11px] font-medium text-emerald-700">
                    Semua desa
                  </span>
                ) : (
                  <div className="mt-1.5 flex flex-wrap gap-1">
                    {g.villages.map((v) => (
                      <span
                        key={v.village_code}
                        className="inline-flex items-center gap-1 rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-700"
                      >
                        {titleCase(v.village_name ?? '')}
                        <button
                          type="button"
                          onClick={() => removeVillage(v.village_code as string)}
                          aria-label={`Hapus ${titleCase(v.village_name ?? '')}`}
                          className="rounded-full hover:text-rose-600"
                        >
                          <X className="h-3 w-3" />
                        </button>
                      </span>
                    ))}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
