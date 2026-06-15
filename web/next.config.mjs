/** @type {import('next').NextConfig} */
const nextConfig = {
  // Produce a self-contained server bundle for small Docker images.
  output: 'standalone',
  reactStrictMode: true,
  // Audius CDN artwork is served from arbitrary hosts.
  images: { remotePatterns: [{ protocol: 'https', hostname: '**' }] },
};

export default nextConfig;
