"use client";
import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search, Bell, User, Menu, ChevronDown, LogOut, Settings } from "lucide-react";
import { notificationsApi, authApi } from "@/lib/api";
import Link from "next/link";

export function TopBar({ onMenuClick }: { onMenuClick?: () => void }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const { data: notifData } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: () => notificationsApi.unreadCount(),
    refetchInterval: 30_000,
  });

  const { data: meData } = useQuery({
    queryKey: ["me"],
    queryFn: () => authApi.me(),
    staleTime: 5 * 60 * 1000,
  });

  const unreadCount: number = notifData?.data?.unread_count ?? 0;
  const me = meData?.data;
  const displayName = me ? `${me.first_name ?? ""} ${me.last_name ?? ""}`.trim() : "Loading…";
  const role = me?.role ?? "";
  const email = me?.email ?? "";

  // Close dropdown when clicking outside
  useEffect(() => {
    if (!menuOpen) return;
    function handleClick(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [menuOpen]);

  function handleLogout() {
    localStorage.removeItem("token");
    window.location.href = "/login";
  }

  return (
    <header className="bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-3 shrink-0">
      {/* Hamburger — mobile only */}
      <button
        onClick={onMenuClick}
        className="md:hidden p-1.5 rounded-lg text-gray-500 hover:text-gray-700 hover:bg-gray-100"
        aria-label="Open navigation"
      >
        <Menu className="w-5 h-5" />
      </button>

      {/* Search */}
      <div className="relative flex-1 max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          placeholder="Search patients, MRN…"
          className="w-full pl-9 pr-4 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      {/* Right icons */}
      <div className="flex items-center gap-2 ml-auto">
        <Link href="/tasks" className="relative p-1.5 text-gray-500 hover:text-gray-700 rounded-lg hover:bg-gray-100">
          <Bell className="w-5 h-5" />
          {unreadCount > 0 && (
            <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-0.5 bg-red-500 rounded-full flex items-center justify-center text-[10px] font-bold text-white">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          )}
        </Link>

        {/* User menu */}
        <div className="relative pl-2 border-l border-gray-200" ref={menuRef}>
          <button
            onClick={() => setMenuOpen((v) => !v)}
            className="flex items-center gap-2 rounded-lg px-1.5 py-1 hover:bg-gray-100 transition-colors"
          >
            <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center shrink-0">
              <User className="w-4 h-4 text-blue-600" />
            </div>
            <div className="hidden sm:block text-sm text-left">
              <div className="font-medium text-gray-900 leading-tight">{displayName}</div>
              <div className="text-xs text-gray-500 capitalize">{role}</div>
            </div>
            <ChevronDown className="hidden sm:block w-3.5 h-3.5 text-gray-400 shrink-0" />
          </button>

          {menuOpen && (
            <div className="absolute top-full right-0 mt-1.5 w-52 bg-white rounded-xl shadow-lg border border-gray-100 z-50 overflow-hidden">
              {/* Email header */}
              <div className="px-4 py-3 border-b border-gray-100">
                <div className="text-xs text-gray-400 truncate">{email || "—"}</div>
              </div>

              {/* Settings link */}
              <Link
                href="/settings"
                onClick={() => setMenuOpen(false)}
                className="flex items-center gap-2.5 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
              >
                <Settings className="w-4 h-4 text-gray-400" />
                Settings
              </Link>

              {/* Divider */}
              <div className="border-t border-gray-100" />

              {/* Logout */}
              <button
                onClick={handleLogout}
                className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors"
              >
                <LogOut className="w-4 h-4" />
                Log out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
