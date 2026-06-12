"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, vitalsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { HeartPulse, AlertTriangle, TrendingUp } from "lucide-react";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type AlertItem = {
  type: string;
  message: string;
  severity: string;
};

type VitalsData = {
  patient_id: string;
  baseline_weight_lbs?: number;
  data_points: {
    visit_id: string;
    date?: string;
    weight_lbs?: number;
    bp?: string;
    hr?: number;
    o2_sat?: number;
    temp_f?: number;
  }[];
  alerts: AlertItem[];
};

const SEVERITY_COLOR: Record<string, string> = {
  critical: "text-red-700 bg-red-50 border-red-200",
  high: "text-orange-600 bg-orange-50 border-orange-200",
  moderate: "text-yellow-700 bg-yellow-50 border-yellow-200",
};

export default function VitalsPage() {
  const [selectedPatient, setSelectedPatient] = useState("");
  const [filterDate, setFilterDate] = useState("");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: vitalsData } = useQuery({
    queryKey: ["vitals", selectedPatient],
    queryFn: () => vitalsApi.trend(selectedPatient),
    enabled: !!selectedPatient,
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const vitals: VitalsData | undefined = vitalsData?.data;
  const filteredPoints = vitals?.data_points.filter((v) => {
    if (!filterDate || !v.date) return true;
    return v.date.slice(0, 10) === filterDate;
  }) ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <HeartPulse className="w-6 h-6 text-red-500" /> Vitals Trend
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">Time-series vital signs with clinical alert detection</p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <select
          value={selectedPatient}
          onChange={(e) => setSelectedPatient(e.target.value)}
          className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white w-72"
        >
          <option value="">Select a patient…</option>
          {patients.map((p) => (
            <option key={p.id} value={p.id}>{p.last_name}, {p.first_name} — {p.mrn}</option>
          ))}
        </select>
        <div className="flex items-center gap-2">
          <label className="text-sm text-gray-500 shrink-0">Visit date:</label>
          <input
            type="date"
            value={filterDate}
            onChange={(e) => setFilterDate(e.target.value)}
            className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white"
          />
          {filterDate && (
            <button onClick={() => setFilterDate("")} className="text-xs text-gray-400 hover:text-gray-600">Clear</button>
          )}
        </div>
      </div>

      {vitals && (
        <>
          {/* Alerts */}
          {vitals.alerts.length > 0 && (
            <div className="space-y-2">
              {vitals.alerts.map((a, i) => (
                <div key={i} className={cn("flex items-center gap-3 px-4 py-3 rounded-lg border text-sm font-medium", SEVERITY_COLOR[a.severity] ?? "text-gray-700 bg-gray-50 border-gray-200")}>
                  <AlertTriangle className="w-4 h-4 shrink-0" />
                  {a.message}
                  <span className="ml-auto text-xs font-normal opacity-70 capitalize">{a.severity}</span>
                </div>
              ))}
            </div>
          )}

          {/* Baseline */}
          {vitals.baseline_weight_lbs && (
            <div className="text-sm text-gray-500">
              Baseline weight: <span className="font-semibold text-gray-900">{vitals.baseline_weight_lbs} lbs</span>
            </div>
          )}

          {/* Vitals table */}
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Date</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Weight (lbs)</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">BP</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">HR</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">O2 Sat</th>
                  <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Temp (°F)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredPoints.length === 0 ? (
                  <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">{filterDate ? "No vitals on this date" : "No vitals recorded yet"}</td></tr>
                ) : filteredPoints.map((v) => (
                  <tr key={v.visit_id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-gray-700">{v.date ? new Date(v.date).toLocaleDateString() : "—"}</td>
                    <td className="px-4 py-3 font-medium">{v.weight_lbs ?? "—"}</td>
                    <td className="px-4 py-3">{v.bp ?? "—"}</td>
                    <td className={cn("px-4 py-3", v.hr && v.hr > 110 ? "text-orange-600 font-semibold" : "")}>{v.hr ?? "—"}</td>
                    <td className={cn("px-4 py-3", v.o2_sat && v.o2_sat < 92 ? "text-red-600 font-semibold" : "")}>{v.o2_sat != null ? `${v.o2_sat}%` : "—"}</td>
                    <td className="px-4 py-3">{v.temp_f ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <TrendingUp className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to view their vitals trend</p>
        </div>
      )}
    </div>
  );
}
