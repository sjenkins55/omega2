"use client";
import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, vitalsApi, visitsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { HeartPulse, AlertTriangle, TrendingUp, ChevronLeft, ChevronRight } from "lucide-react";
import {
  format, isSameDay, startOfMonth, endOfMonth, eachDayOfInterval,
  addMonths, subMonths, startOfWeek, endOfWeek,
} from "date-fns";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type AlertItem = { type: string; message: string; severity: string };

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
  high:     "text-orange-600 bg-orange-50 border-orange-200",
  moderate: "text-yellow-700 bg-yellow-50 border-yellow-200",
};

function MiniCalendar({
  dotDates,
  selectedDate,
  onSelect,
}: {
  dotDates: Set<string>;
  selectedDate: string;
  onSelect: (d: string) => void;
}) {
  const [calMonth, setCalMonth] = useState(() => {
    if (selectedDate) return new Date(selectedDate);
    return new Date();
  });

  const monthStart = startOfMonth(calMonth);
  const monthEnd = endOfMonth(calMonth);
  const calStart = startOfWeek(monthStart, { weekStartsOn: 1 });
  const calEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });
  const calDays = eachDayOfInterval({ start: calStart, end: calEnd });

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 w-56">
      <div className="flex items-center justify-between mb-2">
        <button onClick={() => setCalMonth(m => subMonths(m, 1))} className="p-1 hover:bg-gray-100 rounded">
          <ChevronLeft className="w-3.5 h-3.5 text-gray-500" />
        </button>
        <span className="text-xs font-semibold text-gray-700">{format(calMonth, "MMMM yyyy")}</span>
        <button onClick={() => setCalMonth(m => addMonths(m, 1))} className="p-1 hover:bg-gray-100 rounded">
          <ChevronRight className="w-3.5 h-3.5 text-gray-500" />
        </button>
      </div>
      <div className="grid grid-cols-7 text-center mb-1">
        {["M","T","W","T","F","S","S"].map((d, i) => (
          <div key={i} className="text-xs text-gray-400 py-0.5">{d}</div>
        ))}
      </div>
      <div className="grid grid-cols-7 text-center gap-y-0.5">
        {calDays.map(day => {
          const key = format(day, "yyyy-MM-dd");
          const hasDot = dotDates.has(key);
          const isSelected = selectedDate === key;
          const isOtherMonth = format(day, "M") !== format(calMonth, "M");
          return (
            <div key={key} className="flex flex-col items-center">
              <button
                onClick={() => onSelect(isSelected ? "" : key)}
                className={cn(
                  "text-xs w-6 h-6 rounded-full flex items-center justify-center transition-colors",
                  isSelected ? "bg-blue-600 text-white font-bold"
                    : hasDot ? "text-gray-900 hover:bg-blue-50 font-medium"
                    : isOtherMonth ? "text-gray-300"
                    : "text-gray-500 hover:bg-gray-100",
                )}
              >
                {format(day, "d")}
              </button>
              {hasDot && !isSelected && (
                <div className="w-1 h-1 rounded-full bg-blue-400 -mt-0.5" />
              )}
            </div>
          );
        })}
      </div>
      {selectedDate && (
        <button onClick={() => onSelect("")} className="mt-2 w-full text-xs text-blue-600 hover:underline">
          Clear filter
        </button>
      )}
    </div>
  );
}

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

  const { data: visitsData } = useQuery({
    queryKey: ["visits", "patient", selectedPatient, "scheduled"],
    queryFn: () => visitsApi.list({ patient_id: selectedPatient, limit: 200 }),
    enabled: !!selectedPatient,
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const vitals: VitalsData | undefined = vitalsData?.data;

  // Dates with vitals data points
  const vitalDates = useMemo(() => {
    const s = new Set<string>();
    vitals?.data_points.forEach(v => { if (v.date) s.add(v.date.slice(0, 10)); });
    return s;
  }, [vitals]);

  // Also show visit dates as dots if no vitals for that date
  const visitDates = useMemo(() => {
    const visits = (visitsData as { data?: { scheduled_at?: string }[] })?.data ?? [];
    const s = new Set<string>();
    visits.forEach((v: { scheduled_at?: string }) => {
      if (v.scheduled_at) s.add(v.scheduled_at.slice(0, 10));
    });
    return s;
  }, [visitsData]);

  const dotDates = useMemo(() => {
    const merged = new Set([...vitalDates, ...visitDates]);
    return merged;
  }, [vitalDates, visitDates]);

  const filteredPoints = useMemo(() => {
    return vitals?.data_points.filter(v => {
      if (!filterDate || !v.date) return !filterDate;
      return v.date.slice(0, 10) === filterDate;
    }) ?? [];
  }, [vitals, filterDate]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <HeartPulse className="w-6 h-6 text-red-500" /> Vitals Trend
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">Time-series vital signs with clinical alert detection</p>
      </div>

      <div className="flex gap-3 items-start flex-wrap">
        {/* Patient selector */}
        <select
          value={selectedPatient}
          onChange={e => { setSelectedPatient(e.target.value); setFilterDate(""); }}
          className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white w-72"
        >
          <option value="">Select a patient…</option>
          {patients.map(p => (
            <option key={p.id} value={p.id}>{p.last_name}, {p.first_name} — {p.mrn}</option>
          ))}
        </select>

        {/* Mini calendar with visit/vitals dots */}
        {selectedPatient && dotDates.size > 0 && (
          <div>
            <div className="text-xs text-gray-400 mb-1 ml-1">
              Click a date to filter · <span className="text-blue-500">●</span> visit or vitals recorded
            </div>
            <MiniCalendar dotDates={dotDates} selectedDate={filterDate} onSelect={setFilterDate} />
          </div>
        )}
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

          {vitals.baseline_weight_lbs && (
            <div className="text-sm text-gray-500">
              Baseline weight: <span className="font-semibold text-gray-900">{vitals.baseline_weight_lbs} lbs</span>
            </div>
          )}

          {filterDate && (
            <div className="text-sm text-blue-700 bg-blue-50 border border-blue-100 rounded-lg px-3 py-2 flex items-center gap-2">
              Showing vitals for {new Date(filterDate + "T12:00:00").toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
              <button onClick={() => setFilterDate("")} className="ml-auto text-blue-500 hover:text-blue-700 text-xs">Clear</button>
            </div>
          )}

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
                  <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">
                    {filterDate ? "No vitals recorded on this date" : "No vitals recorded yet"}
                  </td></tr>
                ) : filteredPoints.map(v => (
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
