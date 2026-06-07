"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard, Users, CalendarDays, ClipboardList,
  FileText, Zap, MessageSquare, Activity, Settings,
  MapPin, ShieldCheck, CheckSquare, Bell, HeartPulse,
  ClipboardCheck, Stethoscope, FileBarChart2, BookOpen,
  Hospital, BadgeCheck,
} from "lucide-react";

const NAV = [
  { href: "/dashboard",   icon: LayoutDashboard,  label: "Dashboard" },
  { href: "/patients",    icon: Users,            label: "Patients" },
  { href: "/schedule",    icon: CalendarDays,     label: "Schedule" },
  { href: "/visits",      icon: ClipboardList,    label: "Visits" },
  { href: "/tasks",       icon: CheckSquare,      label: "Tasks" },
  { href: "/ingestion",   icon: FileText,         label: "Inbox / Faxes" },
  { href: "/workflows",   icon: Zap,              label: "Workflows" },
  { href: "/engagement",  icon: MessageSquare,    label: "Engagement" },
  { href: "/analytics",   icon: Activity,         label: "Analytics" },
  { href: "/reports",     icon: FileBarChart2,    label: "Reports" },
  { href: "/settings",    icon: Settings,         label: "Settings" },
];

const CLINICAL_NAV = [
  { href: "/orders",     icon: Stethoscope,    label: "Orders" },
  { href: "/oasis",      icon: ClipboardCheck, label: "OASIS" },
  { href: "/care-plans", icon: BookOpen,       label: "Care Plans" },
  { href: "/vitals",     icon: HeartPulse,     label: "Vitals" },
  { href: "/adt",        icon: Hospital,       label: "ADT Events" },
  { href: "/eligibility",icon: BadgeCheck,     label: "Eligibility" },
];

const ADMIN_NAV = [
  { href: "/admin/territories", icon: MapPin,      label: "Territories" },
  { href: "/admin/users",       icon: ShieldCheck, label: "Users & Access" },
  { href: "/admin/audit",       icon: Bell,        label: "Audit Log" },
];

function NavGroup({ items }: { items: typeof NAV }) {
  const pathname = usePathname();
  return (
    <div className="space-y-0.5">
      {items.map(({ href, icon: Icon, label }) => (
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
    </div>
  );
}

export function Sidebar() {
  return (
    <aside className="w-56 bg-slate-900 text-slate-100 flex flex-col shrink-0">
      <div className="px-4 py-5 border-b border-slate-700">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-md bg-blue-500 flex items-center justify-center text-white text-xs font-bold">CC</div>
          <span className="font-semibold text-sm">ConcertoCare EMR</span>
        </div>
      </div>
      <nav className="flex-1 py-4 px-2 overflow-y-auto">
        <NavGroup items={NAV} />
        <div className="mt-4 pt-4 border-t border-slate-700/60">
          <p className="px-3 mb-1 text-[10px] font-semibold uppercase tracking-widest text-slate-500">Clinical</p>
          <NavGroup items={CLINICAL_NAV} />
        </div>
        <div className="mt-4 pt-4 border-t border-slate-700/60">
          <p className="px-3 mb-1 text-[10px] font-semibold uppercase tracking-widest text-slate-500">Admin</p>
          <NavGroup items={ADMIN_NAV} />
        </div>
      </nav>
      <div className="px-4 py-3 border-t border-slate-700 text-xs text-slate-400">
        AI-Powered Home Care EMR
      </div>
    </aside>
  );
}
