/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Breeze Clinical Design System
        canvas: '#F7FAFC',
        surface: '#ECF2F7',
        textPrimary: '#111827',
        textSecondary: '#374151',
        mint: '#69E3C6',
        sky: '#6AB7FF',
        hairline: '#E2E8F0',
        ash: '#E2E8F0',
      },
      borderRadius: {
        'card': '14px',
        'button': '12px',
        'pill': '999px',
      },
      boxShadow: {
        'card': '0 8px 24px rgba(0,0,0,0.08)',
        'button': '0 4px 12px rgba(0,0,0,0.06)',
      },
      fontFamily: {
        sans: ['SF Pro', 'system-ui', 'sans-serif'],
        heading: ['Space Grotesk', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
