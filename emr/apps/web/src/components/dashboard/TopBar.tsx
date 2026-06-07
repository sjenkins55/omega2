"use client";
import { useQuery } from "@tanstack/react-query";
import { Search, Bell, User } from "lucide-react";
import { notificationsApi } from "@/lib/api";
import Link from "next/link";

export function TopBar() {
  const { data } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: () => notificationsApi.unreadCount(),
    refetchInterval: 30_000,
  });

  const unreadCount: number = data?.data?.unread_count ?? 0;

  return (
    <header className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between shrink-0">
      <div className="relative flex-1 max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          placeholder="Search patients, MRN, visit..."
          className="w-full pl-9 pr-4 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <div className="flex items-center gap-3 ml-4">
        <Link href="/tasks" className="relative p-1.5 text-gray-500 hover:text-gray-700 rounded-lg hover:bg-gray-100">
          <Bell className="w-5 h-5" />
          {unreadCount > 0 && (
            <span className="absolute top-0.5 right-0.5 min-w-[16px] h-4 px-0.5 bg-red-500 rounded-full flex items-center justify-center text-[10px] font-bold text-white">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          )}
        </Link>
        <div className="flex items-center gap-2 pl-3 border-l border-gray-200">
          <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
            <User className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-sm">
            <div className="font-medium text-gray-900">Dr. Sarah Kim</div>
            <div className="text-xs text-gray-500">Skilled Nursing</div>
          </div>
        </div>
      </div>
    </header>
  );
}
