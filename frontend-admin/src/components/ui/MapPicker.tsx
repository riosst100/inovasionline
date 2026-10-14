'use client';

import React, { useEffect, useRef, useState } from 'react';
import type { Map as LeafletMap, Marker } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Crosshair, Loader2, Search } from 'lucide-react';

interface Props {
  latitude: number | null;
  longitude: number | null;
  onChange: (lat: number, lng: number) => void;
}

// Indonesia centre, used until a point is picked.
const DEFAULT_CENTER: [number, number] = [-2.5, 118];
const PIN_ICON = {
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [25, 41] as [number, number],
  iconAnchor: [12, 41] as [number, number],
};

export default function MapPicker({ latitude, longitude, onChange }: Props) {
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<LeafletMap | null>(null);
  const marker = useRef<Marker | null>(null);
  const leaflet = useRef<typeof import('leaflet') | null>(null);
  const onChangeRef = useRef(onChange);
  const [query, setQuery] = useState('');
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  useEffect(() => {
    onChangeRef.current = onChange;
  });

  const place = (lat: number, lng: number, pan = true) => {
    const L = leaflet.current;
    if (!L || !map.current) return;
    if (!marker.current) {
      marker.current = L.marker([lat, lng], { draggable: true, icon: L.icon(PIN_ICON) }).addTo(map.current);
      marker.current.on('dragend', () => {
        const p = marker.current!.getLatLng();
        onChangeRef.current(p.lat, p.lng);
      });
    } else {
      marker.current.setLatLng([lat, lng]);
    }
    if (pan) map.current.setView([lat, lng], Math.max(map.current.getZoom(), 15));
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const L = await import('leaflet');
      if (cancelled || !el.current || map.current) return;
      leaflet.current = L;

      const hasPoint = latitude !== null && longitude !== null;
      const m = L.map(el.current).setView(hasPoint ? [latitude, longitude] : DEFAULT_CENTER, hasPoint ? 15 : 5);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap',
      }).addTo(m);
      m.on('click', (e) => {
        place(e.latlng.lat, e.latlng.lng, false);
        onChangeRef.current(e.latlng.lat, e.latlng.lng);
      });
      map.current = m;
      if (hasPoint) place(latitude, longitude, false);
    })();
    return () => {
      cancelled = true;
      map.current?.remove();
      map.current = null;
      marker.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Keep the pin in sync when coordinates are typed in the form.
  useEffect(() => {
    if (latitude === null || longitude === null || !map.current) return;
    const cur = marker.current?.getLatLng();
    if (cur && cur.lat === latitude && cur.lng === longitude) return;
    place(latitude, longitude);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latitude, longitude]);

  const search = async () => {
    if (!query.trim()) return;
    setBusy(true);
    setNote(null);
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=id&q=${encodeURIComponent(query.trim())}`
      );
      const rows: { lat: string; lon: string }[] = await res.json();
      if (!rows.length) {
        setNote('Lokasi tidak ditemukan.');
      } else {
        const lat = Number(rows[0].lat);
        const lng = Number(rows[0].lon);
        place(lat, lng);
        onChange(lat, lng);
      }
    } catch {
      setNote('Gagal mencari lokasi.');
    } finally {
      setBusy(false);
    }
  };

  const locate = () => {
    if (!navigator.geolocation) {
      setNote('Browser tidak mendukung geolokasi.');
      return;
    }
    setNote(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        place(pos.coords.latitude, pos.coords.longitude);
        onChange(pos.coords.latitude, pos.coords.longitude);
      },
      () => setNote('Tidak dapat mengambil lokasi Anda.')
    );
  };

  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              search();
            }
          }}
          placeholder="Cari alamat atau tempat..."
          className="min-w-0 flex-1 rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
        />
        <button
          type="button"
          onClick={search}
          disabled={busy}
          className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
        >
          {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />} Cari
        </button>
        <button
          type="button"
          onClick={locate}
          title="Gunakan lokasi saya"
          className="rounded-lg border border-slate-200 px-3 py-2 text-slate-600 hover:bg-slate-50"
        >
          <Crosshair className="h-4 w-4" />
        </button>
      </div>
      {note && <p className="text-xs text-rose-600">{note}</p>}
      <div ref={el} className="z-0 h-72 w-full overflow-hidden rounded-xl border border-slate-200" />
      <p className="text-[11px] text-slate-400">Klik peta atau geser pin untuk menentukan titik lokasi.</p>
    </div>
  );
}
