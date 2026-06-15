// Browser-side client for the Go backend (aggregator + user-sync).
// In the browser these must be absolute URLs reachable from the client, so they
// come from NEXT_PUBLIC_* env vars (baked at build time / read at runtime).

export const AGGREGATOR_URL =
  process.env.NEXT_PUBLIC_AGGREGATOR_URL || 'http://localhost:8000';
export const USERSYNC_URL =
  process.env.NEXT_PUBLIC_USERSYNC_URL || 'http://localhost:8001';

export interface AudiusTrack {
  id: string;
  title: string;
  artist: string;
  duration: number;
  artworkUrl: string;
}

export interface PlaylistTrack {
  ref: string;
  title: string;
  artist: string;
  position: number;
}

export interface Playlist {
  name: string;
  tracks: PlaylistTrack[];
}

function artworkOf(j: any): string {
  const a = j?.artwork;
  if (a && typeof a === 'object') return a['480x480'] || a['150x150'] || '';
  return '';
}

export async function searchTracks(query: string): Promise<AudiusTrack[]> {
  const r = await fetch(`${AGGREGATOR_URL}/search?query=${encodeURIComponent(query)}`);
  if (!r.ok) throw new Error(`search failed: ${r.status}`);
  const data = (await r.json()) as any[];
  return (data || []).map((j) => ({
    id: String(j.id ?? ''),
    title: String(j.title ?? ''),
    artist: String(j.user?.name ?? ''),
    duration: typeof j.duration === 'number' ? j.duration : 0,
    artworkUrl: artworkOf(j),
  }));
}

export function streamUrl(id: string): string {
  return `${AGGREGATOR_URL}/stream/${id}`;
}

// ---- auth (JWT held in memory + localStorage) ----

const TOKEN_KEY = 'omnitune_token';

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return window.localStorage.getItem(TOKEN_KEY);
}
function setToken(t: string) {
  if (typeof window !== 'undefined') window.localStorage.setItem(TOKEN_KEY, t);
}
export function logout() {
  if (typeof window !== 'undefined') window.localStorage.removeItem(TOKEN_KEY);
}

async function auth(path: string, username: string, password: string): Promise<void> {
  const r = await fetch(`${USERSYNC_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!r.ok) throw new Error(`auth failed (${r.status}): ${(await r.text()).trim()}`);
  const { token } = await r.json();
  if (token) setToken(token);
}

export const register = (u: string, p: string) => auth('/auth/register', u, p);
export const login = (u: string, p: string) => auth('/auth/login', u, p);

export async function syncPlaylist(name: string, tracks: PlaylistTrack[]): Promise<void> {
  const token = getToken();
  if (!token) throw new Error('not logged in');
  const r = await fetch(`${USERSYNC_URL}/sync/playlist`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ name, tracks }),
  });
  if (!r.ok) throw new Error(`sync failed (${r.status})`);
}

export async function fetchPlaylists(): Promise<Playlist[]> {
  const token = getToken();
  if (!token) throw new Error('not logged in');
  const r = await fetch(`${USERSYNC_URL}/playlists`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!r.ok) throw new Error(`fetch failed (${r.status})`);
  return (await r.json()) as Playlist[];
}
