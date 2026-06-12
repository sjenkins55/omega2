"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi } from "@/lib/api";
import { Patient } from "@/types";
import { cn, formatDate, riskTierColor } from "@/lib/utils";
import { Search, Plus, ChevronRight } from "lucide-react";
import Link from "next/link";

const STATUS_TABS = ["all", "active", "inactive", "discharged", "pending"] as const;

export default function PatientsPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<string>("active");

  const { data, isLoading } = useQuery({
    queryKey: ["patients", status, search],
    queryFn: () => patientsApi.list({ status: status === "all" ? undefined : status, search: search || undefined }),
    placeholderData: (prev) => prev,
  });

  const patients: Patient[] = data?.data?.patients ?? [];

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Patients</h1>
          <p className="text-sm text-gray-500">{data?.data?.total ?? 0} patients</p>
        </div>
        <Link href="/patients/new" className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
          <Plus className="w-4 h-4" /> New Patient
        </Link>
      </div>

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-3 border-b border-gray-100 flex items-center gap-4">
          <div className="relative flex-1 max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by name or MRN..."
              className="w-full pl-9 pr-4 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div className="flex gap-1">
            {STATUS_TABS.map((s) => (
              <button
                key={s}
                onClick={() => setStatus(s)}
                className={cn(
                  "px-3 py-1 rounded-md text-sm capitalize transition-colors",
                  status === s ? "bg-blue-600 text-white" : "text-gray-600 hover:bg-gray-100"
                )}
              >
                {s}
              </button>
            ))}
          </div>
        </div>

        {isLoading ? (
          <div className="py-12 text-center text-sm text-gray-400">Loading...</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs text-gray-500 border-b border-gray-100">
                <th className="px-5 py-3 font-medium">Patient</th>
                <th className="px-4 py-3 font-medium">MRN</th>
                <th className="px-4 py-3 font-medium">DOB</th>
                <th className="px-4 py-3 font-medium">Primary DX</th>
                <th className="px-4 py-3 font-medium">AI Risk</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {patients.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50 transition-colors cursor-pointer" onClick={() => window.location.href = `/patients/${p.id}`}>
                  <td className="px-5 py-3">
                    <div className="font-medium text-gray-900 hover:text-blue-600">{p.last_name}, {p.first_name}</div>
                    <div className="text-xs text-gray-400">{p.phone}</div>
                  </td>
                  <td className="px-4 py-3 text-gray-600 font-mono text-xs">{p.mrn}</td>
                  <td className="px-4 py-3 text-gray-600">{formatDate(p.date_of_birth)}</td>
                  <td className="px-4 py-3 text-gray-600 max-w-48 truncate">{p.primary_dx ?? "—"}</td>
                  <td className="px-4 py-3">
                    {p.ai_risk_score != null ? (
                      <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full", riskTierColor(
                        p.ai_risk_score >= 0.9 ? "critical" : p.ai_risk_score >= 0.7 ? "high" : p.ai_risk_score >= 0.4 ? "medium" : "low"
                      ))}>
                        {Math.round(p.ai_risk_score * 100)}%
                      </span>
                    ) : (
                      <span className="text-xs text-gray-400">Not scored</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full capitalize",
                      p.status === "active" ? "bg-green-50 text-green-700" :
                      p.status === "discharged" ? "bg-gray-100 text-gray-600" :
                      "bg-yellow-50 text-yellow-700"
                    )}>
                      {p.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <Link href={`/patients/${p.id}`} className="p-1 text-gray-400 hover:text-gray-700 rounded">
                      <ChevronRight className="w-4 h-4" />
                    </Link>
                  </td>
                </tr>
              ))}
              {patients.length === 0 && (
                <tr><td colSpan={7} className="py-12 text-center text-sm text-gray-400">No patients found</td></tr>
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
