'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import {
  AudiusTrack,
  Playlist,
  fetchPlaylists,
  getToken,
  login,
  logout,
  register,
  searchTracks,
  streamUrl,
  syncPlaylist,
} from '@/lib/api';
import { WasmAudioPlayer } from '@/lib/wasmPlayer';

const EQ_FREQS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
const EQ_PRESETS: Record<string, number[]> = {
  Flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  Rock: [4, 3, -1, -2, -1, 1, 3, 4, 4, 4],
  Pop: [-1, 1, 3, 4, 3, 0, -1, -1, -1, -1],
  Bass: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  Vocal: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
};

function fmt(sec: number): string {
  if (!isFinite(sec) || sec < 0) sec = 0;
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export default function Home() {
  const playerRef = useRef<WasmAudioPlayer | null>(null);

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<AudiusTrack[]>([]);
  const [searching, setSearching] = useState(false);

  const [queue, setQueue] = useState<AudiusTrack[]>([]);
  const [currentIdx, setCurrentIdx] = useState(-1);
  const [current, setCurrent] = useState<AudiusTrack | null>(null);
  const [playing, setPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);

  const [showEq, setShowEq] = useState(false);
  const [eqPreset, setEqPreset] = useState('Flat');
  const [eqGains, setEqGains] = useState<number[]>(Array(10).fill(0));

  const [loggedIn, setLoggedIn] = useState(false);
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [status, setStatus] = useState('Ready');
  const [wasmReady, setWasmReady] = useState(false);

  useEffect(() => {
    playerRef.current = new WasmAudioPlayer();
    setLoggedIn(!!getToken());
    const id = setInterval(() => {
      const p = playerRef.current;
      if (!p || !p.ready) return;
      const isP = p.isPlaying();
      setPosition(p.position());
      setDuration(p.duration() || 0);
      if (!isP && playing) {
        // track ended → auto-advance
        setPlaying(false);
        next();
      }
    }, 250);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playing]);

  const doSearch = useCallback(async () => {
    if (!query.trim()) return;
    setSearching(true);
    setStatus(`Searching "${query}"...`);
    try {
      const r = await searchTracks(query.trim());
      setResults(r);
      setStatus(`${r.length} results`);
    } catch (e: any) {
      setStatus(`Search error: ${e.message}`);
    } finally {
      setSearching(false);
    }
  }, [query]);

  const playTrack = useCallback(async (track: AudiusTrack, q?: AudiusTrack[], idx?: number) => {
    const p = playerRef.current;
    if (!p) return;
    setStatus(`Buffering "${track.title}"...`);
    try {
      const ok = await p.loadUrl(streamUrl(track.id));
      if (!ok) {
        setStatus('Failed to load stream');
        return;
      }
      p.setVolume(volume);
      eqGains.forEach((g, i) => p.setEqBandGain(i, g));
      p.play();
      setCurrent(track);
      setPlaying(true);
      setWasmReady(true);
      setStatus('');
      if (q) {
        setQueue(q);
        setCurrentIdx(idx ?? q.findIndex((t) => t.id === track.id));
      }
    } catch (e: any) {
      setStatus(`Stream error: ${e.message}`);
    }
  }, [volume, eqGains]);

  const togglePlay = () => {
    const p = playerRef.current;
    if (!p || !p.ready) return;
    if (p.isPlaying()) {
      p.pause();
      setPlaying(false);
    } else {
      p.play();
      setPlaying(true);
    }
  };

  const stop = () => {
    playerRef.current?.stop();
    setPlaying(false);
    setPosition(0);
  };

  const next = () => {
    if (queue.length === 0) return;
    const n = (currentIdx + 1) % queue.length;
    playTrack(queue[n], queue, n);
  };
  const prev = () => {
    if (queue.length === 0) return;
    const n = (currentIdx - 1 + queue.length) % queue.length;
    playTrack(queue[n], queue, n);
  };

  const onSeek = (v: number) => {
    playerRef.current?.seek(v);
    setPosition(v);
  };
  const onVolume = (v: number) => {
    setVolume(v);
    playerRef.current?.setVolume(v);
  };
  const applyPreset = (name: string) => {
    const g = EQ_PRESETS[name];
    if (!g) return;
    setEqPreset(name);
    setEqGains([...g]);
    g.forEach((val, i) => playerRef.current?.setEqBandGain(i, val));
  };
  const onEq = (i: number, v: number) => {
    const g = [...eqGains];
    g[i] = v;
    setEqGains(g);
    setEqPreset('Custom');
    playerRef.current?.setEqBandGain(i, v);
  };

  const doAuth = async (kind: 'login' | 'register') => {
    const u = prompt('Username');
    const pw = u ? prompt('Password') : null;
    if (!u || !pw) return;
    try {
      await (kind === 'login' ? login(u, pw) : register(u, pw));
      setLoggedIn(true);
      setStatus('Logged in');
    } catch (e: any) {
      setStatus(`${e.message}`);
    }
  };

  const saveCloud = async () => {
    if (!loggedIn) return setStatus('Log in first');
    try {
      await syncPlaylist(
        'Web Queue',
        queue.map((t, i) => ({ ref: `audius:${t.id}`, title: t.title, artist: t.artist, position: i })),
      );
      setStatus(`Synced ${queue.length} tracks`);
    } catch (e: any) {
      setStatus(`${e.message}`);
    }
  };
  const loadCloud = async () => {
    if (!loggedIn) return setStatus('Log in first');
    try {
      setPlaylists(await fetchPlaylists());
      setStatus('Loaded cloud playlists');
    } catch (e: any) {
      setStatus(`${e.message}`);
    }
  };

  return (
    <div className="flex min-h-screen flex-col">
      {/* Header */}
      <header className="flex items-center gap-3 border-b border-panelBorder bg-black px-4 py-3">
        <span className="text-accent text-xl">▣</span>
        <h1 className="text-sm font-semibold tracking-wider text-white">OmniTune TT Next · Web</h1>
        <span className="rounded bg-panel px-2 py-0.5 text-[10px] text-accent">WASM core</span>
        <div className="ml-auto flex items-center gap-2 text-xs">
          {loggedIn ? (
            <>
              <span className="text-accent">● cloud</span>
              <button className="text-white/60 hover:text-white" onClick={() => { logout(); setLoggedIn(false); }}>Logout</button>
            </>
          ) : (
            <>
              <button className="text-white/70 hover:text-accent" onClick={() => doAuth('login')}>Login</button>
              <button className="text-white/70 hover:text-accent" onClick={() => doAuth('register')}>Register</button>
            </>
          )}
        </div>
      </header>

      {/* Search */}
      <div className="flex gap-2 p-4">
        <input
          className="flex-1 rounded bg-panel px-3 py-2 text-sm text-white outline-none ring-1 ring-panelBorder focus:ring-accent"
          placeholder="Search millions of tracks on Audius..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && doSearch()}
        />
        <button className="rounded bg-accentDim px-4 py-2 text-sm font-semibold text-black hover:bg-accent" onClick={doSearch}>
          {searching ? '…' : 'Search'}
        </button>
        <button className="rounded bg-panel px-3 py-2 text-sm text-white/80 ring-1 ring-panelBorder hover:text-accent" onClick={() => setShowEq((s) => !s)}>
          EQ
        </button>
        <button className="rounded bg-panel px-3 py-2 text-sm text-white/80 ring-1 ring-panelBorder hover:text-accent" onClick={saveCloud}>↑ Cloud</button>
        <button className="rounded bg-panel px-3 py-2 text-sm text-white/80 ring-1 ring-panelBorder hover:text-accent" onClick={loadCloud}>↓ Cloud</button>
      </div>

      {/* Equalizer */}
      {showEq && (
        <div className="mx-4 mb-2 rounded border border-panelBorder bg-panel p-3">
          <div className="mb-2 flex items-center gap-2">
            <span className="text-xs font-bold tracking-wider text-white">EQUALIZER</span>
            <select
              className="ml-auto rounded bg-bg px-2 py-1 text-xs text-accent outline-none"
              value={EQ_PRESETS[eqPreset] ? eqPreset : 'Custom'}
              onChange={(e) => applyPreset(e.target.value)}
            >
              {Object.keys(EQ_PRESETS).map((k) => <option key={k} value={k}>{k}</option>)}
              {!EQ_PRESETS[eqPreset] && <option value="Custom">Custom</option>}
            </select>
          </div>
          <div className="flex items-end justify-between gap-2">
            {EQ_FREQS.map((f, i) => (
              <div key={f} className="flex flex-1 flex-col items-center gap-1">
                <span className="text-[9px] text-white/40">{eqGains[i].toFixed(0)}</span>
                <input
                  type="range" min={-12} max={12} step={1} value={eqGains[i]}
                  onChange={(e) => onEq(i, Number(e.target.value))}
                  // vertical sliders
                  className="h-24"
                  style={{ writingMode: 'vertical-lr' as any, direction: 'rtl' }}
                />
                <span className="text-[9px] text-accent">{f < 1000 ? f : `${f / 1000}k`}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Results + cloud playlists */}
      <main className="flex flex-1 gap-4 overflow-hidden px-4 pb-4">
        <section className="flex-[2] overflow-y-auto rounded border border-panelBorder bg-panel">
          <div className="border-b border-panelBorder px-3 py-2 text-xs font-bold tracking-wider text-white">
            RESULTS
          </div>
          {results.length === 0 ? (
            <p className="p-6 text-center text-sm text-white/40">Search to stream from Audius</p>
          ) : (
            <ul>
              {results.map((t, i) => (
                <li
                  key={t.id}
                  className={`flex cursor-pointer items-center gap-3 border-b border-panelBorder/50 px-3 py-2 hover:bg-white/5 ${current?.id === t.id ? 'bg-accent/10' : ''}`}
                  onClick={() => playTrack(t, results, i)}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  {t.artworkUrl ? <img src={t.artworkUrl} alt="" className="h-10 w-10 rounded object-cover" /> : <div className="h-10 w-10 rounded bg-lcd" />}
                  <div className="min-w-0 flex-1">
                    <p className={`truncate text-sm ${current?.id === t.id ? 'text-accent' : 'text-white'}`}>{t.title}</p>
                    <p className="truncate text-xs text-white/40">{t.artist}</p>
                  </div>
                  <span className="text-xs text-white/40">{fmt(t.duration)}</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="flex-1 overflow-y-auto rounded border border-panelBorder bg-panel">
          <div className="border-b border-panelBorder px-3 py-2 text-xs font-bold tracking-wider text-white">
            CLOUD PLAYLISTS
          </div>
          {playlists.length === 0 ? (
            <p className="p-6 text-center text-sm text-white/40">Login + ↓ Cloud to load</p>
          ) : (
            playlists.map((pl) => (
              <div key={pl.name} className="border-b border-panelBorder/50 px-3 py-2">
                <p className="text-sm text-accent">{pl.name} ({pl.tracks.length})</p>
                {pl.tracks.map((tr, i) => (
                  <p key={i} className="truncate text-xs text-white/50">{tr.title || tr.ref} — {tr.artist}</p>
                ))}
              </div>
            ))
          )}
        </section>
      </main>

      {/* Now playing bar */}
      <footer className="border-t border-panelBorder bg-lcd px-4 py-3">
        <div className="flex items-center gap-4">
          {current?.artworkUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={current.artworkUrl} alt="" className="h-14 w-14 rounded object-cover" />
          ) : (
            <div className="flex h-14 w-14 items-center justify-center rounded bg-black text-accent">♪</div>
          )}
          <div className="w-48 min-w-0">
            <p className="truncate text-sm font-bold text-accent">{current?.title ?? 'No track'}</p>
            <p className="truncate text-xs text-accent/60">{current?.artist ?? '—'}</p>
          </div>

          <div className="flex flex-1 flex-col gap-1">
            <div className="flex items-center justify-center gap-4 text-accent">
              <button title="Previous" onClick={prev} className="hover:text-white">⏮</button>
              <button title="Play/Pause" onClick={togglePlay} className="text-2xl hover:text-white">{playing ? '❚❚' : '▶'}</button>
              <button title="Stop" onClick={stop} className="hover:text-white">⏹</button>
              <button title="Next" onClick={next} className="hover:text-white">⏭</button>
            </div>
            <div className="flex items-center gap-2 text-[10px] text-accent">
              <span>{fmt(position)}</span>
              <input
                type="range" min={0} max={duration || 1} step={0.5} value={Math.min(position, duration || 1)}
                onChange={(e) => onSeek(Number(e.target.value))}
                className="flex-1"
              />
              <span>{fmt(duration)}</span>
            </div>
          </div>

          <div className="flex w-32 items-center gap-2 text-accent">
            <span>🔊</span>
            <input type="range" min={0} max={1} step={0.01} value={volume} onChange={(e) => onVolume(Number(e.target.value))} className="flex-1" />
          </div>
        </div>
        <p className="mt-1 text-center text-[10px] text-white/40">{wasmReady ? '● WASM core active' : '○ core loads on first play'} · {status}</p>
      </footer>
    </div>
  );
}
