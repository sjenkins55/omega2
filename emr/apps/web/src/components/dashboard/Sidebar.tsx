"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard, Users, CalendarDays, ClipboardList,
  FileText, Zap, MessageSquare, Activity, Settings
} from "lucide-react";

const NAV = [
  { href: "/dashboard",  icon: LayoutDashboard, label: "Dashboard" },
  { href: "/patients",   icon: Users,           label: "Patients" },
  { href: "/schedule",   icon: CalendarDays,    label: "Schedule" },
  { href: "/visits",     icon: ClipboardList,   label: "Visits" },
  { href: "/ingestion",  icon: FileText,        label: "Inbox / Faxes" },
  { href: "/workflows",  icon: Zap,             label: "Workflows" },
  { href: "/engagement", icon: MessageSquare,   label: "Engagement" },
  { href: "/analytics",  icon: Activity,        label: "Analytics" },
  { href: "/settings",   icon: Settings,        label: "Settings" },
];

export function Sidebar() {
  const pathname = usePathname();
  return (
    <aside className="w-56 bg-slate-900 text-slate-100 flex flex-col shrink-0">
      <div className="px-4 py-5 border-b border-slate-700">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-md bg-blue-500 flex items-center justify-center text-white text-xs font-bold">CC</div>
          <span className="font-semibold text-sm">ConcertoCare EMR</span>
        </div>
      </div>
      <nav className="flex-1 py-4 space-y-0.5 px-2">
        {NAV.map(({ href, icon: Icon, label }) => (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors",
              pathname.startsWith(href)
                ? "bg-blue-600 text-white"
                : "text-slate-300 hover:bg-slate-800 hover:text-white"
            )}
          >
            <Icon className="w-4 h-4 shrink-0" />
            {label}
          </Link>
        ))}
      </nav>
      <div className="px-4 py-3 border-t border-slate-700 text-xs text-slate-400">
        AI-Powered Home Care EMR
      </div>
    </aside>
  );
}
