'use client';

import { useSyncExternalStore } from 'react';
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';
import { API_BASE } from './api';

/**
 * WebSocket link to Laravel Reverb for live admin data. The backend (App\Events\AdminDataChanged)
 * only signals which data changed; listeners refetch it through the normal, permission-checked API.
 * Defaults match the local docker stack (reverb on localhost:8080).
 */

const KEY = process.env.NEXT_PUBLIC_REVERB_APP_KEY || 'inovasionline-key';
const HOST = process.env.NEXT_PUBLIC_REVERB_HOST || 'localhost';
const PORT = Number(process.env.NEXT_PUBLIC_REVERB_PORT || 8080);
const TLS = (process.env.NEXT_PUBLIC_REVERB_SCHEME || 'http') === 'https';
const AUTH_URL = `${API_BASE.replace(/\/api\/?$/, '')}/broadcasting/auth`;

/** Changes saved within this window after a signal are throttled server-side, so refetch once more. */
const TRAILING_REFETCH_MS = 2000;

export type AdminChannel = 'admin.orders' | 'admin.dashboard';

let echo: Echo<'reverb'> | null = null;
let connected = false;
const statusListeners = new Set<() => void>();

function connection(): Echo<'reverb'> | null {
  if (typeof window === 'undefined') return null;
  if (!echo) {
    echo = new Echo({
      broadcaster: 'reverb',
      Pusher,
      key: KEY,
      wsHost: HOST,
      wsPort: PORT,
      wssPort: PORT,
      forceTLS: TLS,
      enabledTransports: ['ws', 'wss'],
      // The admin session is an HttpOnly cookie, so private channels are authorized with it.
      authorizer: (channel: { name: string }) => ({
        authorize: (socketId: string, callback: (error: Error | null, data: { auth: string } | null) => void) => {
          fetch(AUTH_URL, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify({ socket_id: socketId, channel_name: channel.name }),
          })
            .then((res) => (res.ok ? res.json() : Promise.reject(new Error(`Broadcast auth ${res.status}`))))
            .then((data) => callback(null, data))
            .catch((error) => callback(error, null));
        },
      }),
    });
    echo.connector.pusher.connection.bind('state_change', ({ current }: { current: string }) => {
      connected = current === 'connected';
      statusListeners.forEach((l) => l());
    });
  }
  return echo;
}

/**
 * Calls `onChange` when the backend signals a change on `channel`, and once more shortly after.
 * Returns the unsubscribe function.
 */
export function onAdminChange(channel: AdminChannel, onChange: () => void): () => void {
  const ws = connection();
  if (!ws) return () => {};

  let trailing: ReturnType<typeof setTimeout> | null = null;
  const handler = () => {
    onChange();
    if (trailing) clearTimeout(trailing);
    trailing = setTimeout(onChange, TRAILING_REFETCH_MS);
  };
  const ch = ws.private(channel);
  ch.listen('.admin.changed', handler);

  return () => {
    if (trailing) clearTimeout(trailing);
    ch.stopListening('.admin.changed', handler);
  };
}

/** Whether the WebSocket is connected; while it isn't, pages fall back to periodic refresh. */
export function useRealtimeConnected(): boolean {
  return useSyncExternalStore(
    (listener) => {
      connection();
      statusListeners.add(listener);
      return () => statusListeners.delete(listener);
    },
    () => connected,
    () => false,
  );
}
