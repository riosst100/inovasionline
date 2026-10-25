'use client';

import { useSyncExternalStore } from 'react';
import { apiRequest } from './api';
import { onAdminChange } from './realtime';
import { InstantOrderQueue } from '../types';

/**
 * Shared live store for GET /admin/orders/instant (instant orders not yet shipped, plus the unfinished
 * order count for the menu badge). Every component using useInstantOrders() reads the same data; while
 * at least one is mounted it refetches on each `admin.orders` WebSocket signal, with polling only as a
 * fallback. While any instant order is still `pending` (nobody started packing it) the chime repeats
 * until an admin moves it to "sedang disiapkan / dikemas"; an order passing its ship-by deadline gets
 * one urgent chime.
 */

/** Fallback when the WebSocket is down; normally the `admin.orders` signal triggers refetches. */
const POLL_MS = 60_000;
/** Faster while ringing, so without the socket the sound still stops soon after the order is packed. */
const RINGING_POLL_MS = 15_000;
const RING_MS = 5_000;
const SOUND_KEY = 'admin_instant_order_sound';

/** How many instant orders nobody has started packing yet. */
export const unpacked = (queue: InstantOrderQueue | null) => queue?.unpacked ?? 0;

type State = { queue: InstantOrderQueue | null; sound: boolean };

const readSound = () => {
  try {
    return typeof window === 'undefined' || localStorage.getItem(SOUND_KEY) !== 'off';
  } catch {
    return true;
  }
};

const SERVER_STATE: State = { queue: null, sound: true };
let state: State = { queue: null, sound: readSound() };
const listeners = new Set<() => void>();
let pollTimer: ReturnType<typeof setTimeout> | null = null;
let ringTimer: ReturnType<typeof setInterval> | null = null;
let unlisten: (() => void) | null = null;
// Module-level so moving between admin pages doesn't re-announce late orders.
const lateAnnounced = new Set<string>();

function emit(next: Partial<State>) {
  state = { ...state, ...next };
  listeners.forEach((l) => l());
}

export async function refreshInstantOrders(): Promise<void> {
  try {
    const queue = await apiRequest<InstantOrderQueue>('/admin/orders/instant');
    const now = Date.now();
    const late = queue.orders.filter((o) => Date.parse(o.deadline_at) < now && !lateAnnounced.has(o.id));
    late.forEach((o) => lateAnnounced.add(o.id));

    // Unpacked orders already ring every few seconds; only add the urgent chime for newly late ones.
    if (state.sound && late.length > 0) playChime(true);
    emit({ queue });
  } catch {
    // Keep showing the last data; the next poll retries.
  }
}

// Bumped on every start/stop, so a request still in flight from an earlier run can't spawn a second loop.
let generation = 0;

async function poll(run: number) {
  await refreshInstantOrders();
  if (run !== generation) return;
  pollTimer = setTimeout(() => poll(run), unpacked(state.queue) > 0 ? RINGING_POLL_MS : POLL_MS);
}

function ring() {
  if (state.sound && unpacked(state.queue) > 0) playChime();
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  if (!ringTimer) {
    ringTimer = setInterval(ring, RING_MS);
    unlisten = onAdminChange('admin.orders', () => void refreshInstantOrders());
    void poll(++generation);
  }
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0) {
      generation++;
      if (pollTimer) clearTimeout(pollTimer);
      if (ringTimer) clearInterval(ringTimer);
      unlisten?.();
      pollTimer = ringTimer = unlisten = null;
    }
  };
}

export function useInstantOrders(): State {
  return useSyncExternalStore(subscribe, () => state, () => SERVER_STATE);
}

export function setInstantOrderSound(on: boolean) {
  try {
    localStorage.setItem(SOUND_KEY, on ? 'on' : 'off');
  } catch {
    // Private mode: the choice lasts for this tab only.
  }
  emit({ sound: on });
  // Clicking the toggle is the user gesture browsers need before audio may play.
  if (on) playChime();
}

let audioCtx: AudioContext | null = null;

function audio(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  if (!audioCtx) {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return null;
    audioCtx = new Ctx();
  }
  return audioCtx;
}

// Browsers keep audio suspended until the user interacts with the page; resume on the first click.
if (typeof window !== 'undefined') {
  window.addEventListener('pointerdown', () => void audio()?.resume(), { passive: true });
}

/** Short two-tone chime; `urgent` repeats it for an order past its deadline. */
export function playChime(urgent = false) {
  const ctx = audio();
  if (!ctx) return;
  void ctx.resume();
  const notes = urgent ? [880, 660, 880, 660] : [660, 880];
  notes.forEach((freq, i) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const t = ctx.currentTime + i * 0.18;
    osc.type = 'sine';
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.25, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.17);
  });
}

/** Ticking clock: "12:05", "1:04:09", "7h 04:12:05" (h = hari). */
export function formatClock(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  const days = Math.floor(s / 86400);
  const hours = Math.floor((s % 86400) / 3600);
  const pad = (n: number) => String(n).padStart(2, '0');
  const mmss = `${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
  if (days) return `${days}h ${pad(hours)}:${mmss}`;
  return hours ? `${hours}:${mmss}` : mmss;
}

export type Urgency = 'late' | 'soon' | 'ok';

/**
 * Red ("late") once past the ship-by limit, orange ("soon") from half of it: with the default
 * 30-minute limit, orange after 15 minutes of waiting and red after 30.
 */
export function urgency(deadlineAt: string, dispatchMinutes: number, now: number): Urgency {
  const left = Date.parse(deadlineAt) - now;
  if (left < 0) return 'late';
  return left <= (dispatchMinutes * 60_000) / 2 ? 'soon' : 'ok';
}
