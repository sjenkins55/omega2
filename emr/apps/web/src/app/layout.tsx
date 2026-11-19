import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";
import { AppShell } from "@/components/AppShell";
import { PwaProvider } from "@/components/PwaProvider";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "ConcertoCare EMR",
  description: "AI-enabled home care EMR",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "ConcertoCare",
  },
  icons: {
    icon: "/icons/icon-192.png",
    apple: "/icons/apple-touch-icon.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#2563eb",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <body className={`${inter.className} h-full bg-gray-50`}>
        <Providers>
          <AppShell>{children}</AppShell>
          <PwaProvider />
        </Providers>
      </body>
    </html>
  );
}
