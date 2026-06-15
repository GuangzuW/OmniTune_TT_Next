// Client-side wrapper around the C++ audio core compiled to WebAssembly.
// The same core that powers the desktop/mobile apps (miniaudio engine + 10-band
// equalizer) runs in the browser via Emscripten; miniaudio uses its Web Audio
// backend for output. Audio bytes are fetched (from the aggregator's stream
// proxy) and written into the Emscripten in-memory FS, then played by path.

declare global {
  interface Window {
    TTPlayerCore?: (opts?: any) => Promise<any>;
  }
}

let modulePromise: Promise<any> | null = null;

function loadModule(): Promise<any> {
  if (modulePromise) return modulePromise;
  modulePromise = new Promise((resolve, reject) => {
    if (typeof window === 'undefined') {
      reject(new Error('WASM core is browser-only'));
      return;
    }
    const existing = document.getElementById('ttplayer-wasm');
    const start = async () => {
      try {
        const factory = window.TTPlayerCore;
        if (!factory) throw new Error('TTPlayerCore factory not found');
        const mod = await factory({ locateFile: (p: string) => `/wasm/${p}` });
        resolve(mod);
      } catch (e) {
        reject(e);
      }
    };
    if (existing) {
      start();
      return;
    }
    const script = document.createElement('script');
    script.id = 'ttplayer-wasm';
    script.src = '/wasm/TTPlayerCore.js';
    script.onload = start;
    script.onerror = () => reject(new Error('Failed to load /wasm/TTPlayerCore.js'));
    document.head.appendChild(script);
  });
  return modulePromise;
}

export class WasmAudioPlayer {
  private module: any;
  private player: any;
  private counter = 0;
  ready = false;

  async init(): Promise<void> {
    if (this.ready) return;
    this.module = await loadModule();
    this.player = new this.module.AudioPlayer();
    this.ready = true;
  }

  /** Fetch audio bytes and load them into the WASM FS for playback. */
  async loadUrl(url: string): Promise<boolean> {
    await this.init();
    const resp = await fetch(url, { redirect: 'follow' });
    if (!resp.ok) throw new Error(`stream fetch failed: ${resp.status}`);
    const bytes = new Uint8Array(await resp.arrayBuffer());
    const path = `/track_${this.counter++}`;
    this.module.FS.writeFile(path, bytes);
    return this.player.load(path);
  }

  play() { this.player?.play(); }
  pause() { this.player?.pause(); }
  stop() { this.player?.stop(); }
  seek(seconds: number) { this.player?.seekTo(seconds); }
  position(): number { return this.player ? this.player.getPosition() : 0; }
  duration(): number { return this.player ? this.player.getDuration() : 0; }
  isPlaying(): boolean { return this.player ? this.player.isPlaying() : false; }
  setEqBandGain(band: number, gainDb: number) { this.player?.setEqBandGain(band, gainDb); }
  setVolume(v: number) { this.player?.setVolume(v); }
}
