import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Volcy - Quantified Skin Progress',
  description: 'Millimeter-accurate skin analytics, privately on your iPhone.',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
