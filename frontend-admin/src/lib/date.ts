import { useSyncExternalStore } from 'react';

/**
 * The one place the admin panel formats and parses dates. Everything is shown and entered in WIB
 * (Asia/Jakarta, UTC+7) whatever the viewer's device timezone, matching the backend's day
 * boundaries. Use these helpers instead of toLocale*String / getHours etc. on a Date.
 *
 * Input: an ISO timestamp from the API, a Date, epoch ms, or a date-only "YYYY-MM-DD" (taken as
 * that calendar day in WIB). Empty input formats as "-".
 */

export const TIMEZONE = 'Asia/Jakarta';
const LOCALE = 'id-ID';
const EMPTY = '-';

export type DateInput = string | number | Date | null | undefined;

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

export function toDate(value: DateInput): Date | null {
  if (value === null || value === undefined || value === '') return null;
  const d = typeof value === 'string' && DATE_ONLY.test(value) ? new Date(`${value}T00:00:00+07:00`) : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

const formatters = new Map<string, Intl.DateTimeFormat>();

function format(value: DateInput, options: Intl.DateTimeFormatOptions, locale = LOCALE): string {
  const d = toDate(value);
  if (!d) return EMPTY;
  const key = locale + JSON.stringify(options);
  let f = formatters.get(key);
  if (!f) {
    f = new Intl.DateTimeFormat(locale, { timeZone: TIMEZONE, ...options });
    formatters.set(key, f);
  }
  return f.format(d);
}

/** "25 Okt 2026" (short), "25 Oktober 2026" (long), "Minggu, 25 Oktober 2026" (full). */
export function formatDate(value: DateInput, style: 'short' | 'long' | 'full' = 'short'): string {
  return format(value, {
    weekday: style === 'full' ? 'long' : undefined,
    day: 'numeric',
    month: style === 'short' ? 'short' : 'long',
    year: 'numeric',
  });
}

/** "25 Okt 2026, 14.32"; with `{ year: false }` "25 Okt, 14.32". */
export function formatDateTime(value: DateInput, { year = true }: { year?: boolean } = {}): string {
  return format(value, {
    day: 'numeric',
    month: 'short',
    year: year ? 'numeric' : undefined,
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** "14.32" */
export function formatTime(value: DateInput): string {
  return format(value, { hour: '2-digit', minute: '2-digit' });
}

/** WIB calendar date and 24h time, e.g. { date: '2026-10-25', time: '14:32' }: for inputs and comparisons. */
export function wibParts(value: DateInput): { date: string; time: string } {
  const d = toDate(value);
  if (!d) return { date: '', time: '' };
  return {
    date: format(d, { year: 'numeric', month: '2-digit', day: '2-digit' }, 'en-CA'),
    time: format(d, { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }, 'en-GB'),
  };
}

/** A WIB date (+ time) from date/time inputs, as the ISO timestamp the API expects. */
export function fromWib(date: string, time = '00:00'): string {
  return new Date(`${date}T${time}:00+07:00`).toISOString();
}

/** Today (or today + offsetDays) in WIB as YYYY-MM-DD, matching the backend's date filters. */
export function todayWib(offsetDays = 0): string {
  return wibParts(Date.now() + offsetDays * 86_400_000).date;
}

/**
 * One shared ticking clock per interval. `subscribe` / `snapshot` are created once per clock so
 * useSyncExternalStore sees stable functions (a new subscribe each render would resubscribe, re-read
 * the clock and render again, forever).
 */
type Clock = {
  now: number;
  listeners: Set<() => void>;
  timer: ReturnType<typeof setInterval> | null;
  subscribe: (listener: () => void) => () => void;
  snapshot: () => number;
};
const clocks = new Map<number, Clock>();
const serverNow = () => 0;

function clockFor(ms: number): Clock {
  const existing = clocks.get(ms);
  if (existing) return existing;

  const c: Clock = {
    now: 0,
    listeners: new Set(),
    timer: null,
    subscribe: (listener) => {
      c.listeners.add(listener);
      if (!c.timer) {
        c.now = Date.now();
        c.timer = setInterval(() => {
          c.now = Date.now();
          c.listeners.forEach((l) => l());
        }, ms);
        // React re-reads the snapshot right after subscribing, so the new time shows without a notify here.
      }
      return () => {
        c.listeners.delete(listener);
        if (c.listeners.size === 0 && c.timer) {
          clearInterval(c.timer);
          c.timer = null;
        }
      };
    },
    snapshot: () => c.now,
  };
  clocks.set(ms, c);
  return c;
}

/**
 * Current time (epoch ms), re-rendering every `ms`; one shared interval per `ms`. It is 0 during
 * prerender and the very first render (Next.js must not bake a clock reading into the page), so
 * treat 0 as "not known yet".
 */
export function useNow(ms = 1000): number {
  const clock = clockFor(ms);
  return useSyncExternalStore(clock.subscribe, clock.snapshot, serverNow);
}

/** Whether two moments fall on the same WIB calendar day. */
export function sameWibDay(a: DateInput, b: DateInput): boolean {
  return wibParts(a).date !== '' && wibParts(a).date === wibParts(b).date;
}
