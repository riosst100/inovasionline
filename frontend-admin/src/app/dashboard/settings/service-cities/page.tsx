'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import AdminLayout from '../../../../components/layout/AdminLayout';
import { adminApi, ApiError } from '../../../../lib/api';
import { titleCase } from '../../../../lib/text';
import { RegionItem, ServiceCityOptions } from '../../../../types';
import { AlertCircle, CheckCircle2, ChevronRight, Loader2, MapPinned, Save, Search } from 'lucide-react';

/**
 * Coverage is picked at four levels. A selected city with no district/village
 * picked under it is served as a whole; picking some narrows it to those
 * districts (entirely) and villages. Ticking everything again folds back up.
 */
export default function ServiceCitiesPage() {
  const [data, setData] = useState<ServiceCityOptions | null>(null);
  const [cities, setCities] = useState<Set<string>>(new Set());
  const [districts, setDistricts] = useState<Set<string>>(new Set());
  const [villages, setVillages] = useState<Set<string>>(new Set());
  const [initialKey, setInitialKey] = useState('');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Lazily loaded lists, plus who belongs to whom (needed to fold selections).
  const [districtList, setDistrictList] = useState<Record<string, RegionItem[]>>({});
  const [villageList, setVillageList] = useState<Record<string, RegionItem[]>>({});
  const [openCities, setOpenCities] = useState<Set<string>>(new Set());
  const [openDistricts, setOpenDistricts] = useState<Set<string>>(new Set());
  const [loadingKey, setLoadingKey] = useState<string | null>(null);
  const cityOfDistrict = useRef<Record<string, string>>({});
  const districtOfVillage = useRef<Record<string, string>>({});

  const keyOf = (c: Set<string>, d: Set<string>, v: Set<string>) =>
    JSON.stringify([[...c].sort(), [...d].sort(), [...v].sort()]);

  useEffect(() => {
    (async () => {
      try {
        const res = await adminApi.getServiceCities();
        const d = new Set<string>();
        const v = new Set<string>();
        res.areas.forEach((a) => {
          cityOfDistrict.current[a.district_code] = a.city_code;
          if (a.level === 'district') d.add(a.code);
          else {
            v.add(a.code);
            districtOfVillage.current[a.code] = a.district_code;
          }
        });
        const c = new Set(res.selected);
        setData(res);
        setCities(c);
        setDistricts(d);
        setVillages(v);
        setInitialKey(keyOf(c, d, v));
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'Gagal memuat data kota.');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const cityOfVillage = (v: string) => cityOfDistrict.current[districtOfVillage.current[v]];

  /** Picks inside a city: districts held whole plus single villages. */
  const picksOf = (city: string, d = districts, v = villages) => ({
    districts: [...d].filter((x) => cityOfDistrict.current[x] === city),
    villages: [...v].filter((x) => cityOfVillage(x) === city),
  });

  type Mode = 'none' | 'all' | 'partial';
  const modeOf = (city: string): Mode => {
    if (!cities.has(city)) return 'none';
    const p = picksOf(city);
    return p.districts.length + p.villages.length > 0 ? 'partial' : 'all';
  };

  const loadDistricts = async (city: string) => {
    if (districtList[city]) return;
    setLoadingKey(city);
    try {
      const list = await adminApi.getServiceDistricts(city);
      list.forEach((d) => (cityOfDistrict.current[d.code] = city));
      setDistrictList((cur) => ({ ...cur, [city]: list }));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat kecamatan.');
    } finally {
      setLoadingKey(null);
    }
  };

  const loadVillages = async (district: string) => {
    if (villageList[district]) return;
    setLoadingKey(district);
    try {
      const list = await adminApi.getServiceVillages(district);
      list.forEach((v) => (districtOfVillage.current[v.code] = district));
      setVillageList((cur) => ({ ...cur, [district]: list }));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Gagal memuat desa.');
    } finally {
      setLoadingKey(null);
    }
  };

  const toggleOpen = (set: Set<string>, setter: (s: Set<string>) => void, code: string, load: () => void) => {
    const next = new Set(set);
    if (next.delete(code)) {
      setter(next);
      return;
    }
    next.add(code);
    setter(next);
    load();
  };

  /** Whole-city checkbox: off when selected in any way, otherwise on for the full city. */
  const toggleCity = (city: string) => {
    const nc = new Set(cities);
    const nd = new Set([...districts].filter((x) => cityOfDistrict.current[x] !== city));
    const nv = new Set([...villages].filter((x) => cityOfVillage(x) !== city));
    if (!nc.delete(city)) nc.add(city);
    setCities(nc);
    setDistricts(nd);
    setVillages(nv);
  };

  const toggleProvince = (codes: string[]) => {
    const nc = new Set(cities);
    const all = codes.every((c) => nc.has(c) && picksOf(c).districts.length + picksOf(c).villages.length === 0);
    const gone = new Set(codes);
    codes.forEach((c) => (all ? nc.delete(c) : nc.add(c)));
    setCities(nc);
    setDistricts(new Set([...districts].filter((x) => !gone.has(cityOfDistrict.current[x]))));
    setVillages(new Set([...villages].filter((x) => !gone.has(cityOfVillage(x)))));
  };

  /**
   * Applies new picks for one city: nothing left unselects it, everything
   * picked folds back into "whole city".
   */
  const commitCity = (city: string, d: Set<string>, v: Set<string>, c = cities) => {
    const all = districtList[city] ?? [];
    const mine = [...d].filter((x) => cityOfDistrict.current[x] === city);
    const nc = new Set(c);
    let nd = d;
    let nv = v;
    const myVillages = [...v].filter((x) => cityOfVillage(x) === city);

    if (mine.length + myVillages.length === 0) {
      nc.delete(city);
    } else {
      nc.add(city);
      if (all.length > 0 && all.every((x) => d.has(x.code))) {
        nd = new Set([...d].filter((x) => cityOfDistrict.current[x] !== city));
        nv = new Set([...v].filter((x) => cityOfVillage(x) !== city));
      }
    }
    setCities(nc);
    setDistricts(nd);
    setVillages(nv);
  };

  const toggleDistrict = (city: string, district: string) => {
    const list = districtList[city] ?? [];
    const mode = modeOf(city);
    let nd = new Set(districts);
    let nv = new Set(villages);

    if (mode === 'all') {
      // Everything was served: keep every other district, drop this one.
      nd = new Set([...nd, ...list.map((x) => x.code).filter((x) => x !== district)]);
    } else if (nd.has(district)) {
      nd.delete(district);
    } else {
      nd.add(district);
      nv = new Set([...nv].filter((x) => districtOfVillage.current[x] !== district));
    }
    commitCity(city, nd, nv, mode === 'all' ? new Set(cities) : cities);
  };

  const toggleVillage = (city: string, district: string, village: string) => {
    const dList = districtList[city] ?? [];
    const vList = villageList[district] ?? [];
    const mode = modeOf(city);
    const nd = new Set(districts);
    const nv = new Set(villages);
    const districtWhole = mode === 'all' || nd.has(district);

    if (districtWhole) {
      // Break the whole district (or city) down to its villages, minus this one.
      if (mode === 'all') dList.forEach((x) => x.code !== district && nd.add(x.code));
      nd.delete(district);
      vList.forEach((x) => x.code !== village && nv.add(x.code));
    } else if (!nv.delete(village)) {
      nv.add(village);
    }

    // Every village ticked: fold into the district.
    const inDistrict = vList.filter((x) => nv.has(x.code));
    if (vList.length > 0 && inDistrict.length === vList.length) {
      vList.forEach((x) => nv.delete(x.code));
      nd.add(district);
    }
    commitCity(city, nd, nv, mode === 'all' ? new Set(cities) : cities);
  };

  const q = search.trim().toLowerCase();
  const groups = useMemo(
    () =>
      (data?.provinces ?? [])
        .map((p) => ({
          ...p,
          visible: q
            ? p.name.toLowerCase().includes(q)
              ? p.cities
              : p.cities.filter((c) => c.name.toLowerCase().includes(q))
            : p.cities,
        }))
        .filter((p) => p.visible.length > 0),
    [data, q]
  );

  const dirty = keyOf(cities, districts, villages) !== initialKey;

  const save = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const areas = [
        ...[...districts].filter((x) => cities.has(cityOfDistrict.current[x])).map((code) => ({ level: 'district' as const, code })),
        ...[...villages].filter((x) => cities.has(cityOfVillage(x))).map((code) => ({ level: 'village' as const, code })),
      ];
      await adminApi.saveServiceCities([...cities], areas);
      setInitialKey(keyOf(cities, districts, villages));
      setSuccess('Cakupan wilayah berhasil disimpan.');
    } catch (e) {
      setError(
        e instanceof ApiError
          ? (e.errors && Object.values(e.errors)[0]?.[0]) || e.message
          : 'Gagal menyimpan cakupan wilayah.'
      );
    } finally {
      setSaving(false);
    }
  };

  const Check = ({ mode, onChange }: { mode: Mode | 'on' | 'off'; onChange: () => void }) => (
    <input
      type="checkbox"
      checked={mode === 'all' || mode === 'on' || mode === 'partial'}
      ref={(el) => {
        if (el) el.indeterminate = mode === 'partial';
      }}
      onChange={onChange}
    />
  );

  return (
    <AdminLayout>
      <div className="mx-auto max-w-4xl space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Cakupan Wilayah</h1>
            <p className="text-sm text-slate-500">
              Wilayah yang dijangkau aplikasi secara keseluruhan. Pilih satu kota penuh, atau buka kota untuk memilih
              kecamatan dan desa tertentu saja. Hanya wilayah terpilih yang dapat dipilih pada alamat pengguna dan
              cakupan gudang.
            </p>
          </div>
          <button
            type="button"
            onClick={save}
            disabled={saving || loading || !dirty || cities.size === 0}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            Simpan
          </button>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-xl border border-rose-200 bg-rose-50 p-3 text-sm text-rose-700">
            <AlertCircle className="h-4 w-4" /> {error}
          </div>
        )}
        {success && (
          <div className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-700">
            <CheckCircle2 className="h-4 w-4" /> {success}
          </div>
        )}

        {loading ? (
          <div className="flex justify-center p-10">
            <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
          </div>
        ) : (
          <>
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative min-w-[200px] flex-1">
                <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Cari provinsi atau kota..."
                  className="w-full rounded-lg border border-slate-200 bg-white py-2 pl-9 pr-3 text-sm outline-none focus:border-emerald-500"
                />
              </div>
              <span className="flex items-center gap-1.5 text-sm text-slate-600">
                <MapPinned className="h-4 w-4 text-emerald-600" />
                {cities.size} kota terpilih
                {districts.size + villages.size > 0 && (
                  <span className="text-slate-400">
                    · {districts.size} kecamatan, {villages.size} desa dipilih khusus
                  </span>
                )}
              </span>
            </div>

            <div className="space-y-4">
              {groups.length === 0 && (
                <p className="rounded-2xl border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">
                  Kota tidak ditemukan.
                </p>
              )}
              {groups.map((p) => {
                const codes = p.cities.map((c) => c.code);
                const whole = codes.filter((c) => modeOf(c) === 'all').length;
                const any = codes.filter((c) => modeOf(c) !== 'none').length;
                return (
                  <section key={p.code} className="rounded-2xl border border-slate-200 bg-white shadow-sm">
                    <label className="flex cursor-pointer items-center gap-3 border-b border-slate-100 px-4 py-3">
                      <Check
                        mode={whole === codes.length ? 'all' : any > 0 ? 'partial' : 'none'}
                        onChange={() => toggleProvince(codes)}
                      />
                      <span className="flex-1 text-sm font-semibold text-slate-800">{titleCase(p.name)}</span>
                      <span className="text-xs text-slate-400">
                        {any}/{codes.length} kota
                      </span>
                    </label>
                    <div className="grid gap-1 p-2 sm:grid-cols-2 lg:grid-cols-3">
                      {p.visible.map((c) => {
                        const mode = modeOf(c.code);
                        const isOpen = openCities.has(c.code);
                        const picks = picksOf(c.code);
                        return (
                          <React.Fragment key={c.code}>
                            <div
                              className={`flex items-center gap-1 rounded-lg px-1 py-1 text-sm ${
                                mode !== 'none' ? 'bg-emerald-50 text-emerald-800' : 'text-slate-700 hover:bg-slate-50'
                              }`}
                            >
                              <button
                                type="button"
                                aria-label={isOpen ? 'Tutup kecamatan' : 'Pilih kecamatan'}
                                onClick={() =>
                                  toggleOpen(openCities, setOpenCities, c.code, () => loadDistricts(c.code))
                                }
                                className="rounded p-0.5 text-slate-400 hover:bg-white hover:text-slate-700"
                              >
                                <ChevronRight className={`h-4 w-4 transition-transform ${isOpen ? 'rotate-90' : ''}`} />
                              </button>
                              <label className="flex flex-1 cursor-pointer items-center gap-2 py-0.5">
                                <Check mode={mode} onChange={() => toggleCity(c.code)} />
                                <span className="flex-1">{titleCase(c.name)}</span>
                                {mode === 'partial' && (
                                  <span className="text-[11px] text-emerald-600">
                                    {picks.districts.length + picks.villages.length} area
                                  </span>
                                )}
                              </label>
                            </div>

                            {isOpen && (
                              <div className="col-span-full mb-1 ml-5 rounded-xl border border-slate-100 bg-slate-50/60 p-2">
                                {loadingKey === c.code || !districtList[c.code] ? (
                                  <Loader2 className="mx-auto my-2 h-4 w-4 animate-spin text-slate-400" />
                                ) : (
                                  <div className="space-y-0.5">
                                    {districtList[c.code].map((d) => {
                                      const dMode: Mode =
                                        mode === 'all' || districts.has(d.code)
                                          ? 'all'
                                          : [...villages].some((v) => districtOfVillage.current[v] === d.code)
                                            ? 'partial'
                                            : 'none';
                                      const dOpen = openDistricts.has(d.code);
                                      return (
                                        <div key={d.code}>
                                          <div className="flex items-center gap-1 rounded-lg px-1 py-0.5 text-sm text-slate-700 hover:bg-white">
                                            <button
                                              type="button"
                                              aria-label={dOpen ? 'Tutup desa' : 'Pilih desa'}
                                              onClick={() =>
                                                toggleOpen(openDistricts, setOpenDistricts, d.code, () =>
                                                  loadVillages(d.code)
                                                )
                                              }
                                              className="rounded p-0.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"
                                            >
                                              <ChevronRight
                                                className={`h-4 w-4 transition-transform ${dOpen ? 'rotate-90' : ''}`}
                                              />
                                            </button>
                                            <label className="flex flex-1 cursor-pointer items-center gap-2 py-0.5">
                                              <Check mode={dMode} onChange={() => toggleDistrict(c.code, d.code)} />
                                              {titleCase(d.name)}
                                            </label>
                                          </div>
                                          {dOpen && (
                                            <div className="ml-6 grid gap-0.5 py-1 sm:grid-cols-2">
                                              {loadingKey === d.code || !villageList[d.code] ? (
                                                <Loader2 className="my-1 h-4 w-4 animate-spin text-slate-400" />
                                              ) : (
                                                villageList[d.code].map((v) => (
                                                  <label
                                                    key={v.code}
                                                    className="flex cursor-pointer items-center gap-2 rounded px-2 py-0.5 text-[13px] text-slate-600 hover:bg-white"
                                                  >
                                                    <Check
                                                      mode={dMode === 'all' || villages.has(v.code) ? 'on' : 'off'}
                                                      onChange={() => toggleVillage(c.code, d.code, v.code)}
                                                    />
                                                    {titleCase(v.name)}
                                                  </label>
                                                ))
                                              )}
                                            </div>
                                          )}
                                        </div>
                                      );
                                    })}
                                  </div>
                                )}
                              </div>
                            )}
                          </React.Fragment>
                        );
                      })}
                    </div>
                  </section>
                );
              })}
            </div>
          </>
        )}
      </div>
    </AdminLayout>
  );
}
