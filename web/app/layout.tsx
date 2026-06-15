import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'OmniTune TT Next — Web',
  description: 'Cloud-native retro music player. Stream from Audius, powered by a WebAssembly C++ audio core.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="font-mono">{children}</body>
    </html>
  );
}
