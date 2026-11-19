"use client";
import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, visitsApi } from "@/lib/api";
import { cn, riskTierColor } from "@/lib/utils";
import { Users, ClipboardList, AlertTriangle, Activity, TrendingUp, Zap } from "lucide-react";
import Link from "next/link";
import { isSameDay } from "date-fns";

export default function DashboardPage() {
  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: scheduledData } = useQuery({
    queryKey: ["visits", "scheduled"],
    queryFn: () => visitsApi.list({ status: "scheduled", limit: 200 }),
  });

  const patients = patientsData?.data?.patients ?? [];
  const highRisk = patients.filter((p: { ai_risk_score?: number }) => (p.ai_risk_score ?? 0) >= 0.7);
  const critRisk = patients.filter((p: { ai_risk_score?: number }) => (p.ai_risk_score ?? 0) >= 0.9);

  const todayVisitCount = useMemo(() => {
    const visits: { scheduled_at?: string }[] = (scheduledData as any)?.data ?? [];
    const today = new Date();
    return visits.filter(v => v.scheduled_at && isSameDay(new Date(v.scheduled_at), today)).length;
  }, [scheduledData]);

  const stats = [
    { label: "Active Patients", value: patients.length, icon: Users, color: "text-blue-600 bg-blue-50" },
    { label: "High Risk", value: highRisk.length, icon: AlertTriangle, color: "text-orange-600 bg-orange-50" },
    { label: "Critical", value: critRisk.length, icon: TrendingUp, color: "text-red-600 bg-red-50" },
    { label: "Today's Visits", value: todayVisitCount, icon: ClipboardList, color: "text-green-600 bg-green-50" },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-0.5">Today's overview — {new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4">
        {stats.map((s) => (
          <div key={s.label} className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-4">
            <div className={cn("w-10 h-10 rounded-lg flex items-center justify-center", s.color)}>
              <s.icon className="w-5 h-5" />
            </div>
            <div>
              <div className="text-2xl font-bold text-gray-900">{s.value}</div>
              <div className="text-sm text-gray-500">{s.label}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-2 gap-6">
        {/* High risk patients */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-orange-500" /> High Risk Patients
            </h2>
            <Link href="/patients?risk=high" className="text-sm text-blue-600 hover:underline">View all</Link>
          </div>
          <div className="divide-y divide-gray-50">
            {highRisk.slice(0, 6).map((p: { id: string; first_name: string; last_name: string; primary_dx?: string; ai_risk_score?: number }) => (
              <Link key={p.id} href={`/patients/${p.id}`} className="flex items-center justify-between px-5 py-3 hover:bg-gray-50">
                <div>
                  <div className="text-sm font-medium text-gray-900">{p.last_name}, {p.first_name}</div>
                  <div className="text-xs text-gray-500">{p.primary_dx ?? "No primary DX"}</div>
                </div>
                <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full", riskTierColor("high"))}>
                  {Math.round((p.ai_risk_score ?? 0) * 100)}%
                </span>
              </Link>
            ))}
            {highRisk.length === 0 && (
              <div className="px-5 py-8 text-center text-sm text-gray-400">No high-risk patients</div>
            )}
          </div>
        </div>

        {/* Quick actions */}
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h2 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <Zap className="w-4 h-4 text-blue-500" /> Quick Actions
            </h2>
            <div className="space-y-2">
              {[
                { label: "Schedule a Visit", href: "/visits/new", color: "bg-blue-600 text-white hover:bg-blue-700" },
                { label: "Review Inbox / Faxes", href: "/ingestion", color: "bg-white text-gray-900 border border-gray-200 hover:bg-gray-50" },
                { label: "Patient Chase List", href: "/engagement", color: "bg-white text-gray-900 border border-gray-200 hover:bg-gray-50" },
                { label: "Schedule Outreach", href: "/engagement?create=1", color: "bg-white text-gray-900 border border-gray-200 hover:bg-gray-50" },
              ].map((a) => (
                <Link key={a.href} href={a.href} className={cn("block w-full text-center py-2 px-4 rounded-lg text-sm font-medium transition-colors", a.color)}>
                  {a.label}
                </Link>
              ))}
            </div>
          </div>

          <div className="bg-gradient-to-br from-blue-600 to-blue-700 rounded-xl p-5 text-white">
            <div className="flex items-center gap-2 mb-2">
              <Activity className="w-4 h-4" />
              <span className="text-sm font-medium">AI Status</span>
            </div>
            <p className="text-sm text-blue-100">All AI models operational. Pre-visit briefs generated automatically before each visit.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
