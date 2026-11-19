"use client";
import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { patientsApi, eligibilityApi, visitsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { BadgeCheck, CheckCircle, XCircle, RefreshCw, ChevronLeft, ChevronRight } from "lucide-react";
import {
  format, isSameDay, startOfMonth, endOfMonth, eachDayOfInterval,
  addMonths, subMonths, startOfWeek, endOfWeek,
} from "date-fns";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type EligibilityCheck = {
  id: string;
  payer_name?: string;
  insurance_type?: string;
  coverage_active?: boolean;
  coverage_dates?: { start?: string; end?: string };
  benefits?: Record<string, unknown>;
  notes?: string;
  checked_at: string;
};

function MiniCalendar({
  visitDots,
  checkDots,
  filterDate,
  onSelect,
}: {
  visitDots: Set<string>;
  checkDots: Set<string>;
  filterDate: string;
  onSelect: (d: string) => void;
}) {
  const [calMonth, setCalMonth] = useState(() => filterDate ? new Date(filterDate) : new Date());
  const calDays = eachDayOfInterval({
    start: startOfWeek(startOfMonth(calMonth), { weekStartsOn: 1 }),
    end: endOfWeek(endOfMonth(calMonth), { weekStartsOn: 1 }),
  });

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
          const isVisit = visitDots.has(key);
          const isCheck = checkDots.has(key);
          const isSelected = filterDate === key;
          const isOtherMonth = format(day, "M") !== format(calMonth, "M");
          return (
            <div key={key} className="flex flex-col items-center">
              <button
                onClick={() => onSelect(isSelected ? "" : key)}
                className={cn(
                  "text-xs w-6 h-6 rounded-full flex items-center justify-center transition-colors",
                  isSelected ? "bg-blue-600 text-white font-bold"
                    : (isVisit || isCheck) ? "text-gray-900 hover:bg-blue-50 font-medium"
                    : isOtherMonth ? "text-gray-300"
                    : "text-gray-500 hover:bg-gray-100",
                )}
              >
                {format(day, "d")}
              </button>
              {(isVisit || isCheck) && !isSelected && (
                <div className="flex gap-0.5 -mt-0.5">
                  {isVisit && <div className="w-1 h-1 rounded-full bg-green-400" />}
                  {isCheck && <div className="w-1 h-1 rounded-full bg-blue-400" />}
                </div>
              )}
            </div>
          );
        })}
      </div>
      <div className="mt-2 flex gap-3 text-xs text-gray-400">
        <span><span className="text-green-500">●</span> Visit</span>
        <span><span className="text-blue-500">●</span> Elig. check</span>
      </div>
      {filterDate && (
        <button onClick={() => onSelect("")} className="mt-2 w-full text-xs text-blue-600 hover:underline">
          Clear filter
        </button>
      )}
    </div>
  );
}

export default function EligibilityPage() {
  const qc = useQueryClient();
  const [selectedPatient, setSelectedPatient] = useState("");
  const [filterDate, setFilterDate] = useState("");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: eligData, isLoading } = useQuery({
    queryKey: ["eligibility", selectedPatient],
    queryFn: () => eligibilityApi.list(selectedPatient),
    enabled: !!selectedPatient,
  });

  const { data: visitsData } = useQuery({
    queryKey: ["visits", "patient", selectedPatient],
    queryFn: () => visitsApi.list({ patient_id: selectedPatient, limit: 200 }),
    enabled: !!selectedPatient,
  });

  const checkMutation = useMutation({
    mutationFn: () => eligibilityApi.check(selectedPatient, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["eligibility", selectedPatient] }),
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const allChecks: EligibilityCheck[] = eligData?.data ?? [];

  const checkDots = useMemo(() => {
    const s = new Set<string>();
    allChecks.forEach(c => { if (c.checked_at) s.add(c.checked_at.slice(0, 10)); });
    return s;
  }, [allChecks]);

  const visitDots = useMemo(() => {
    const visits = (visitsData as { data?: { scheduled_at?: string }[] })?.data ?? [];
    const s = new Set<string>();
    visits.forEach((v: { scheduled_at?: string }) => {
      if (v.scheduled_at) s.add(v.scheduled_at.slice(0, 10));
    });
    return s;
  }, [visitsData]);

  const checks = useMemo(() => {
    if (!filterDate) return allChecks;
    return allChecks.filter(c => c.checked_at.slice(0, 10) === filterDate);
  }, [allChecks, filterDate]);

  const latest = checks[0];

  const showCalendar = selectedPatient && (checkDots.size > 0 || visitDots.size > 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <BadgeCheck className="w-6 h-6 text-blue-600" /> Insurance Eligibility
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">270/271 EDI eligibility verification</p>
      </div>

      <div className="flex gap-4 items-start flex-wrap">
        <div className="space-y-3">
          <div className="flex items-center gap-3">
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
            {selectedPatient && (
              <button
                onClick={() => checkMutation.mutate()}
                disabled={checkMutation.isPending}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
              >
                <RefreshCw className={cn("w-4 h-4", checkMutation.isPending && "animate-spin")} />
                Run Check
              </button>
            )}
          </div>
        </div>

        {showCalendar && (
          <div>
            <div className="text-xs text-gray-400 mb-1 ml-1">Click a date to filter check history</div>
            <MiniCalendar
              visitDots={visitDots}
              checkDots={checkDots}
              filterDate={filterDate}
              onSelect={setFilterDate}
            />
          </div>
        )}
      </div>

      {selectedPatient && (
        isLoading ? (
          <div className="text-sm text-gray-400">Loading…</div>
        ) : (
          <div className="space-y-4">
            {filterDate && (
              <div className="text-sm text-blue-700 bg-blue-50 border border-blue-100 rounded-lg px-3 py-2 flex items-center gap-2">
                Showing checks for {new Date(filterDate + "T12:00:00").toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
                <button onClick={() => setFilterDate("")} className="ml-auto text-blue-500 hover:text-blue-700 text-xs">Clear</button>
              </div>
            )}

            {latest && (
              <div className={cn("rounded-xl border p-5", latest.coverage_active ? "border-green-200 bg-green-50" : "border-red-200 bg-red-50")}>
                <div className="flex items-center gap-3">
                  {latest.coverage_active
                    ? <CheckCircle className="w-6 h-6 text-green-600" />
                    : <XCircle className="w-6 h-6 text-red-500" />}
                  <div>
                    <p className="font-semibold text-gray-900">
                      {latest.coverage_active ? "Coverage Active" : "Coverage Inactive"}
                    </p>
                    <p className="text-sm text-gray-600">{latest.payer_name} · {latest.insurance_type}</p>
                  </div>
                  <span className="ml-auto text-xs text-gray-500">
                    Checked {new Date(latest.checked_at).toLocaleString()}
                  </span>
                </div>
                {latest.coverage_dates && (
                  <p className="text-sm text-gray-600 mt-3">
                    Coverage period: <span className="font-medium">{latest.coverage_dates.start}</span>
                    {latest.coverage_dates.end ? ` → ${latest.coverage_dates.end}` : ""}
                  </p>
                )}
                {latest.benefits && (
                  <div className="mt-3 grid grid-cols-2 gap-2">
                    {Object.entries(latest.benefits).filter(([, v]) => v !== null).map(([k, v]) => (
                      <div key={k} className="text-xs">
                        <span className="text-gray-500 capitalize">{k.replace(/_/g, " ")}: </span>
                        <span className="text-gray-900 font-medium">{String(v)}</span>
                      </div>
                    ))}
                  </div>
                )}
                {latest.notes && <p className="text-xs text-gray-500 mt-3 italic">{latest.notes}</p>}
              </div>
            )}

            {checks.length > 1 && (
              <div className="bg-white rounded-xl border border-gray-200">
                <div className="px-5 py-3 border-b border-gray-100">
                  <h3 className="text-sm font-semibold text-gray-900">Check History</h3>
                </div>
                <div className="divide-y divide-gray-50">
                  {checks.slice(1).map(c => (
                    <div key={c.id} className="flex items-center gap-3 px-5 py-3">
                      {c.coverage_active
                        ? <CheckCircle className="w-4 h-4 text-green-500" />
                        : <XCircle className="w-4 h-4 text-red-400" />}
                      <span className="text-sm text-gray-700">{c.payer_name}</span>
                      <span className="ml-auto text-xs text-gray-400">
                        {new Date(c.checked_at).toLocaleDateString()}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {checks.length === 0 && (
              <div className="bg-white rounded-xl border border-gray-200 p-10 text-center">
                <BadgeCheck className="w-8 h-8 text-gray-300 mx-auto mb-2" />
                <p className="text-gray-400">No eligibility checks{filterDate ? " on this date" : " yet"}</p>
                {!filterDate && <p className="text-xs text-gray-300 mt-1">Click "Run Check" to verify coverage</p>}
              </div>
            )}
          </div>
        )
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <BadgeCheck className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to check their insurance eligibility</p>
        </div>
      )}
    </div>
  );
}
