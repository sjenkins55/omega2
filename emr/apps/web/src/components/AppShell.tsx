"use client";
import { useState } from "react";
import { usePathname } from "next/navigation";
import { Sidebar, MobileSidebar } from "@/components/dashboard/Sidebar";
import { TopBar } from "@/components/dashboard/TopBar";
import { ChatSidebar } from "@/components/ChatSidebar";

const BARE_ROUTES = ["/login", "/portal"];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const isBare = BARE_ROUTES.some(prefix => pathname === prefix || pathname.startsWith(prefix + "/"));

  if (isBare) return <>{children}</>;

  return (
    <div className="flex h-full">
      {/* Desktop sidebar — hidden on mobile */}
      <Sidebar />

      {/* Mobile slide-in drawer */}
      <MobileSidebar open={mobileNavOpen} onClose={() => setMobileNavOpen(false)} />

      <div className="flex flex-col flex-1 overflow-hidden min-w-0">
        <TopBar onMenuClick={() => setMobileNavOpen(true)} />
        <main className="flex-1 overflow-auto p-4 md:p-6">{children}</main>
      </div>

      <ChatSidebar />
    </div>
  );
}
