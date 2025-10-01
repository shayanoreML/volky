/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  images: {
    domains: [],
  },
  env: {
    NEXT_PUBLIC_APP_NAME: 'Volcy',
    NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL || 'https://volcy.app',
  },
}

module.exports = nextConfig
