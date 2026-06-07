"use client";
import { usePathname } from "next/navigation";
import { Sidebar } from "@/components/dashboard/Sidebar";
import { TopBar } from "@/components/dashboard/TopBar";
import { ChatSidebar } from "@/components/ChatSidebar";

const BARE_ROUTES = ["/login", "/portal"];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  // Login page and all portal pages render without the staff shell
  const isBare = BARE_ROUTES.some(prefix => pathname === prefix || pathname.startsWith(prefix + "/"));

  if (isBare) return <>{children}</>;

  return (
    <div className="flex h-full">
      <Sidebar />
      <div className="flex flex-col flex-1 overflow-hidden">
        <TopBar />
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>
      {/* AI chat available on all staff pages — state-scoped per HIPAA minimum necessary */}
      <ChatSidebar />
    </div>
  );
}
