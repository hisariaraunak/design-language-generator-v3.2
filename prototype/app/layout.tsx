import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Habitat Journey — Interactive Prototype',
  description: 'A gentle calorie tracker where healthy routines restore a habitat and introduce animal friends.',
  openGraph: {
    title: 'Habitat Journey',
    description: 'Track what nourishes you. Restore a little world along the way.',
    images: ['/og.png'],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Habitat Journey',
    description: 'Track what nourishes you. Restore a little world along the way.',
    images: ['/og.png'],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
