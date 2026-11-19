"use client";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Link from "next/link";
import { Home, Calendar, FileText, MessageSquare, LogOut, Heart } from "lucide-react";

const NAV = [
  { href: "/portal",          icon: Home,          label: "Home" },
  { href: "/portal/visits",   icon: Calendar,      label: "Visits" },
  { href: "/portal/records",  icon: FileText,      label: "My Records" },
  { href: "/portal/messages", icon: MessageSquare, label: "Messages" },
];

export default function PortalLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [patientName, setPatientName] = useState("");

  useEffect(() => {
    if (pathname === "/portal/login") return;
    const token = localStorage.getItem("portal_token");
    if (!token) { router.push("/portal/login"); return; }
    try {
      const patient = JSON.parse(localStorage.getItem("portal_patient") ?? "{}");
      setPatientName(patient.name ?? "");
    } catch {}
  }, [pathname, router]);

  if (pathname === "/portal/login") return <>{children}</>;

  function signOut() {
    localStorage.removeItem("portal_token");
    localStorage.removeItem("portal_patient");
    router.push("/portal/login");
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      {/* Top header */}
      <header className="bg-white border-b border-slate-200 px-4 py-3 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-blue-500 flex items-center justify-center">
            <Heart className="w-4 h-4 text-white" />
          </div>
          <div>
            <div className="text-sm font-semibold text-slate-900">My Health Portal</div>
            {patientName && <div className="text-xs text-slate-400">{patientName}</div>}
          </div>
        </div>
        <button onClick={signOut} className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-slate-700 transition-colors">
          <LogOut className="w-3.5 h-3.5" />
          Sign out
        </button>
      </header>

      {/* Main content */}
      <main className="flex-1 pb-20">{children}</main>

      {/* Bottom nav */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 flex">
        {NAV.map(({ href, icon: Icon, label }) => {
          const active = href === "/portal" ? pathname === "/portal" : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={`flex-1 flex flex-col items-center gap-1 py-2.5 text-xs font-medium transition-colors ${
                active ? "text-blue-600" : "text-slate-400 hover:text-slate-600"
              }`}
            >
              <Icon className="w-5 h-5" />
              {label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
