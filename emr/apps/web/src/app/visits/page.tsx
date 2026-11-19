"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { visitsApi, patientsApi } from "@/lib/api";
import { cn, formatDateTime } from "@/lib/utils";
import { ClipboardList, ChevronRight } from "lucide-react";
import Link from "next/link";

const STATUS_TABS = ["all", "scheduled", "in_progress", "completed"] as const;

const STATUS_COLOR: Record<string, string> = {
  scheduled: "bg-gray-100 text-gray-600",
  in_progress: "bg-blue-50 text-blue-700",
  completed: "bg-green-50 text-green-700",
  cancelled: "bg-gray-50 text-gray-400",
  missed: "bg-red-50 text-red-700",
};

type Visit = {
  id: string;
  patient_id: string;
  clinician_id: string | null;
  visit_type: string;
  status: string;
  scheduled_at: string | null;
  started_at: string | null;
  completed_at: string | null;
};

type PatientLite = { id: string; first_name: string; last_name: string; mrn: string };

function formatLabel(value: string) {
  return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export default function VisitsPage() {
  const [status, setStatus] = useState<string>("all");

  const { data, isLoading } = useQuery({
    queryKey: ["visits", status],
    queryFn: () => visitsApi.list({ status: status === "all" ? undefined : status, limit: 100 }),
    placeholderData: (prev) => prev,
  });

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "lookup"],
    queryFn: () => patientsApi.list({ limit: 200 }),
  });

  const visits: Visit[] = data?.data ?? [];
  const patientList: PatientLite[] = patientsData?.data?.patients ?? [];
  const patientById = new Map(patientList.map((p) => [p.id, p]));

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Visits</h1>
        <p className="text-sm text-gray-500 mt-0.5">Scheduled and completed patient visits</p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-3 border-b border-gray-100 flex items-center gap-1">
          {STATUS_TABS.map((s) => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className={cn(
                "px-3 py-1 rounded-md text-sm capitalize transition-colors",
                status === s ? "bg-blue-600 text-white" : "text-gray-600 hover:bg-gray-100"
              )}
            >
              {s === "all" ? "All" : s.replace("_", " ")}
            </button>
          ))}
        </div>

        {isLoading ? (
          <div className="py-12 text-center text-sm text-gray-400">Loading...</div>
        ) : visits.length === 0 ? (
          <div className="py-12 text-center">
            <ClipboardList className="w-10 h-10 text-gray-300 mx-auto mb-3" />
            <p className="text-sm text-gray-400">No visits found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs text-gray-500 border-b border-gray-100">
                <th className="px-5 py-3 font-medium">Date</th>
                <th className="px-4 py-3 font-medium">Patient</th>
                <th className="px-4 py-3 font-medium">Type</th>
                <th className="px-4 py-3 font-medium">Clinician</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {visits.map((v) => {
                const patient = patientById.get(v.patient_id);
                return (
                  <tr key={v.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-5 py-3 text-gray-600">{formatDateTime(v.scheduled_at)}</td>
                    <td className="px-4 py-3">
                      {patient ? (
                        <>
                          <div className="font-medium text-gray-900">
                            {patient.last_name}, {patient.first_name}
                          </div>
                          <div className="text-xs text-gray-400 font-mono">{patient.mrn}</div>
                        </>
                      ) : (
                        <span className="text-xs text-gray-400 font-mono">{v.patient_id.slice(0, 8)}</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-gray-600">{formatLabel(v.visit_type)}</td>
                    <td className="px-4 py-3 text-gray-600">
                      {v.clinician_id ? (
                        <span className="font-mono text-xs">{v.clinician_id.slice(0, 8)}</span>
                      ) : (
                        <span className="text-gray-400">Unassigned</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className={cn(
                        "text-xs font-medium px-2 py-0.5 rounded-full",
                        STATUS_COLOR[v.status] ?? "bg-gray-100 text-gray-600"
                      )}>
                        {v.status.replace("_", " ")}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <Link href={`/visits/${v.id}`} className="p-1 text-gray-400 hover:text-gray-700 rounded">
                        <ChevronRight className="w-4 h-4" />
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
