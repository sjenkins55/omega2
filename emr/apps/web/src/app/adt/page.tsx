"use client";
import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { adtApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Hospital, CheckCircle, XCircle, Zap, ChevronLeft, ChevronRight } from "lucide-react";
import {
  format, startOfMonth, endOfMonth, eachDayOfInterval,
  addMonths, subMonths, startOfWeek, endOfWeek,
} from "date-fns";

type ADTEvent = {
  id: string;
  patient_id?: string;
  mrn_in_message?: string;
  event_type: string;
  event_datetime?: string;
  hospital_name?: string;
  discharge_disposition?: string;
  matched: boolean;
  workflow_triggered: boolean;
  created_at: string;
};

const EVENT_COLOR: Record<string, string> = {
  admit:    "text-blue-700 bg-blue-50 border-blue-200",
  discharge:"text-green-700 bg-green-50 border-green-200",
  transfer: "text-purple-700 bg-purple-50 border-purple-200",
};

function MiniCalendar({
  dotDates,
  filterDate,
  onSelect,
}: {
  dotDates: Map<string, string[]>;
  filterDate: string;
  onSelect: (d: string) => void;
}) {
  const [calMonth, setCalMonth] = useState(() => filterDate ? new Date(filterDate) : new Date());
  const calDays = eachDayOfInterval({
    start: startOfWeek(startOfMonth(calMonth), { weekStartsOn: 1 }),
    end: endOfWeek(endOfMonth(calMonth), { weekStartsOn: 1 }),
  });

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 w-56 shrink-0">
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
          const types = dotDates.get(key) ?? [];
          const hasDot = types.length > 0;
          const isSelected = filterDate === key;
          const isOtherMonth = format(day, "M") !== format(calMonth, "M");
          const dotColor = types.includes("admit") ? "bg-blue-400"
            : types.includes("discharge") ? "bg-green-400"
            : types.includes("transfer") ? "bg-purple-400"
            : "bg-gray-400";
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
                <div className={cn("w-1 h-1 rounded-full -mt-0.5", dotColor)} />
              )}
            </div>
          );
        })}
      </div>
      <div className="mt-2 flex flex-wrap gap-2 text-xs text-gray-400">
        <span><span className="text-blue-500">●</span> Admit</span>
        <span><span className="text-green-500">●</span> Discharge</span>
        <span><span className="text-purple-500">●</span> Transfer</span>
      </div>
      {filterDate && (
        <button onClick={() => onSelect("")} className="mt-2 w-full text-xs text-blue-600 hover:underline">
          Clear filter
        </button>
      )}
    </div>
  );
}

export default function ADTPage() {
  const [filterDate, setFilterDate] = useState("");
  const [filterType, setFilterType] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["adt"],
    queryFn: () => adtApi.list({ limit: 200 }),
  });

  const events: ADTEvent[] = data?.data ?? [];

  // Build a map of date -> event types for calendar dots
  const dotDates = useMemo(() => {
    const map = new Map<string, string[]>();
    events.forEach(e => {
      const d = e.event_datetime ?? e.created_at;
      if (!d) return;
      const key = d.slice(0, 10);
      const types = map.get(key) ?? [];
      if (!types.includes(e.event_type)) types.push(e.event_type);
      map.set(key, types);
    });
    return map;
  }, [events]);

  const filtered = useMemo(() => {
    return events.filter(e => {
      const d = e.event_datetime ?? e.created_at;
      if (filterDate && (!d || d.slice(0, 10) !== filterDate)) return false;
      if (filterType && e.event_type !== filterType) return false;
      return true;
    });
  }, [events, filterDate, filterType]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">ADT Events</h1>
        <p className="text-sm text-gray-500 mt-0.5">Hospital admit / discharge / transfer notifications</p>
      </div>

      {isLoading ? (
        <div className="text-sm text-gray-400">Loading...</div>
      ) : events.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <Hospital className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">No ADT events received yet</p>
          <p className="text-xs text-gray-400 mt-1">Events arrive via POST /api/v1/adt/inbound</p>
        </div>
      ) : (
        <div className="flex gap-5 items-start">
          {/* Calendar */}
          <div>
            <div className="text-xs text-gray-400 mb-1 ml-1">Click a date to filter events</div>
            <MiniCalendar dotDates={dotDates} filterDate={filterDate} onSelect={setFilterDate} />
          </div>

          {/* Events list */}
          <div className="flex-1">
            {/* Filter bar */}
            <div className="flex items-center gap-3 mb-4">
              <div className="flex bg-gray-100 rounded-lg p-0.5 text-xs">
                {["", "admit", "discharge", "transfer"].map(t => (
                  <button
                    key={t}
                    onClick={() => setFilterType(t)}
                    className={cn("px-3 py-1.5 rounded-md capitalize transition-colors", filterType === t ? "bg-white shadow text-gray-900 font-medium" : "text-gray-500")}
                  >
                    {t || "All"}
                  </button>
                ))}
              </div>
              {(filterDate || filterType) && (
                <button onClick={() => { setFilterDate(""); setFilterType(""); }} className="text-xs text-gray-400 hover:text-gray-600">
                  Clear filters
                </button>
              )}
              <span className="ml-auto text-xs text-gray-400">{filtered.length} of {events.length} events</span>
            </div>

            {filterDate && (
              <div className="text-sm text-blue-700 bg-blue-50 border border-blue-100 rounded-lg px-3 py-2 flex items-center gap-2 mb-3">
                {new Date(filterDate + "T12:00:00").toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
                <button onClick={() => setFilterDate("")} className="ml-auto text-blue-500 hover:text-blue-700 text-xs">Clear</button>
              </div>
            )}

            {filtered.length === 0 ? (
              <div className="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-400 text-sm">
                No events match the current filter
              </div>
            ) : (
              <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
                {filtered.map(e => (
                  <div key={e.id} className="flex items-center gap-4 px-5 py-4">
                    <div className={cn("text-xs font-semibold px-2.5 py-1 rounded-full capitalize border", EVENT_COLOR[e.event_type] ?? "text-gray-700 bg-gray-50 border-gray-200")}>
                      {e.event_type}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-gray-900">{e.hospital_name ?? "Unknown hospital"}</span>
                        {e.mrn_in_message && (
                          <span className="text-xs text-gray-400">MRN {e.mrn_in_message}</span>
                        )}
                      </div>
                      {e.discharge_disposition && (
                        <p className="text-xs text-gray-500 mt-0.5">Disposition: {e.discharge_disposition}</p>
                      )}
                      <p className="text-xs text-gray-400 mt-0.5">
                        {e.event_datetime ? new Date(e.event_datetime).toLocaleString() : "—"}
                      </p>
                    </div>
                    <div className="flex items-center gap-3 shrink-0">
                      <span className={cn("flex items-center gap-1 text-xs", e.matched ? "text-green-600" : "text-gray-400")}>
                        {e.matched ? <CheckCircle className="w-3.5 h-3.5" /> : <XCircle className="w-3.5 h-3.5" />}
                        {e.matched ? "Matched" : "Unmatched"}
                      </span>
                      {e.workflow_triggered && (
                        <span className="flex items-center gap-1 text-xs text-blue-600">
                          <Zap className="w-3.5 h-3.5" /> Triggered
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
