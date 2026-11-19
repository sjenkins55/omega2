"use client";
import { useState, useMemo, useRef, useEffect, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { visitsApi, patientsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import {
  ChevronLeft, ChevronRight, Brain, AlertTriangle,
  MapPin, Clock, CheckCircle2, Loader2, User
} from "lucide-react";
import Link from "next/link";
import {
  format, addDays, startOfWeek, endOfWeek, isSameDay,
  startOfMonth, endOfMonth, eachDayOfInterval,
  addMonths, subMonths, startOfWeek as sowFn,
} from "date-fns";

const VISIT_TYPE_COLORS: Record<string, { bg: string; border: string; label: string }> = {
  skilled_nursing:     { bg: "bg-blue-50",   border: "border-blue-300",   label: "SN"  },
  physical_therapy:    { bg: "bg-purple-50", border: "border-purple-300", label: "PT"  },
  occupational_therapy:{ bg: "bg-teal-50",   border: "border-teal-300",   label: "OT"  },
  speech_therapy:      { bg: "bg-pink-50",   border: "border-pink-300",   label: "ST"  },
  social_work:         { bg: "bg-orange-50", border: "border-orange-300", label: "SW"  },
  aide:                { bg: "bg-gray-50",   border: "border-gray-300",   label: "HHA" },
  telehealth:          { bg: "bg-cyan-50",   border: "border-cyan-300",   label: "TH"  },
};

const HOURS = Array.from({ length: 13 }, (_, i) => i + 7); // 7am–7pm
const HOUR_HEIGHT = 80; // px per hour

function riskColor(score?: number | null) {
  if (!score) return "";
  if (score >= 0.9) return "text-red-600";
  if (score >= 0.7) return "text-orange-500";
  if (score >= 0.4) return "text-yellow-600";
  return "text-green-600";
}

function getTopOffset(ts: string | number) {
  const d = new Date(ts);
  const mins = (d.getHours() - 7) * 60 + d.getMinutes();
  return Math.max(0, (mins / 60) * HOUR_HEIGHT);
}

function snapToQuarter(mins: number) {
  return Math.round(mins / 15) * 15;
}

type Patient = {
  id: string;
  first_name: string;
  last_name: string;
  mrn: string;
  ai_risk_score?: number | null;
  primary_dx?: string | null;
  address?: { line1?: string; city?: string; state?: string; zip?: string } | null;
};

type Visit = {
  id: string;
  patient_id: string;
  visit_type: string;
  status: string;
  scheduled_at: string;
  structured_note?: unknown;
  assessment?: unknown;
  clinician_id?: string | null;
};

function VisitBlock({
  visit,
  patient,
  compact,
  onDragStart,
  draggingId,
}: {
  visit: Visit;
  patient: Patient | undefined;
  compact: boolean;
  onDragStart: (e: React.DragEvent, visit: Visit) => void;
  draggingId: string | null;
}) {
  const colors = VISIT_TYPE_COLORS[visit.visit_type] ?? { bg: "bg-gray-50", border: "border-gray-300", label: "?" };
  const isCompleted = visit.status === "completed";
  const isInProgress = visit.status === "in_progress";
  const patientName = patient ? `${patient.last_name}, ${patient.first_name}` : "Unknown";
  const isDragging = draggingId === visit.id;

  if (compact) {
    return (
      <Link
        href={`/visits/${visit.id}`}
        draggable
        onDragStart={e => onDragStart(e, visit)}
        onClick={e => { if (isDragging) e.preventDefault(); }}
        className={cn(
          "absolute left-0.5 right-0.5 rounded border px-1 py-0.5 cursor-pointer transition-all hover:shadow-sm text-xs leading-tight overflow-hidden",
          colors.bg, colors.border,
          isCompleted && "opacity-50",
          isDragging && "opacity-30",
        )}
        style={{ top: getTopOffset(visit.scheduled_at) + 2, minHeight: "28px" }}
      >
        <div className="font-semibold truncate text-gray-800">{patientName}</div>
        <div className="text-gray-500">{format(new Date(visit.scheduled_at), "h:mm a")}</div>
      </Link>
    );
  }

  return (
    <Link
      href={`/visits/${visit.id}`}
      draggable
      onDragStart={e => onDragStart(e, visit)}
      onClick={e => { if (isDragging) e.preventDefault(); }}
      className={cn(
        "absolute left-2 right-2 rounded-lg border p-2.5 cursor-grab active:cursor-grabbing transition-all hover:shadow-md",
        colors.bg, colors.border,
        isCompleted && "opacity-60",
        isDragging && "opacity-30 pointer-events-none",
      )}
      style={{ top: getTopOffset(visit.scheduled_at) + 2, minHeight: "68px" }}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5 mb-0.5">
            <span className="text-xs font-bold text-gray-500 bg-white/70 px-1.5 py-0.5 rounded">
              {colors.label}
            </span>
            <span className="text-xs text-gray-500">
              {format(new Date(visit.scheduled_at), "h:mm a")}
            </span>
            {isInProgress && (
              <span className="text-xs bg-blue-100 text-blue-700 font-semibold px-1.5 py-0.5 rounded-full">Live</span>
            )}
            {isCompleted && <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />}
          </div>
          <div className="font-semibold text-sm text-gray-900 truncate">{patientName}</div>
          {patient?.primary_dx && <div className="text-xs text-gray-500 truncate">{patient.primary_dx}</div>}
          {patient?.address?.line1 && (
            <div className="flex items-center gap-1 mt-1">
              <MapPin className="w-3 h-3 text-gray-400 shrink-0" />
              <span className="text-xs text-gray-400 truncate">{patient.address.line1}</span>
            </div>
          )}
        </div>
        <div className="flex flex-col items-end gap-1 flex-shrink-0">
          {patient?.ai_risk_score != null && (
            <span className={cn("text-xs font-bold", riskColor(patient.ai_risk_score))}>
              {Math.round(patient.ai_risk_score * 100)}%
            </span>
          )}
          <span title="AI Brief Ready"><Brain className="w-3.5 h-3.5 text-blue-500" /></span>
        </div>
      </div>
    </Link>
  );
}

export default function SchedulePage() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [view, setView] = useState<"day" | "week">("day");
  const [calMonth, setCalMonth] = useState(new Date());
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [dropIndicator, setDropIndicator] = useState<{ dayIdx: number; top: number } | null>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const queryClient = useQueryClient();

  // Mini calendar grid
  const monthStart = startOfMonth(calMonth);
  const monthEnd = endOfMonth(calMonth);
  const calStart = sowFn(monthStart, { weekStartsOn: 1 });
  const calEnd = endOfWeek(monthEnd, { weekStartsOn: 1 });
  const calDays = eachDayOfInterval({ start: calStart, end: calEnd });

  // Fetch visits by status so DESC ordering doesn't cut off future ones
  const { data: scheduledData } = useQuery({
    queryKey: ["visits", "scheduled"],
    queryFn: () => visitsApi.list({ status: "scheduled", limit: 200 }),
  });
  const { data: inProgressData } = useQuery({
    queryKey: ["visits", "in_progress"],
    queryFn: () => visitsApi.list({ status: "in_progress", limit: 50 }),
  });
  const { data: completedData } = useQuery({
    queryKey: ["visits", "completed"],
    queryFn: () => visitsApi.list({ status: "completed", limit: 100 }),
  });
  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, scheduled_at }: { id: string; scheduled_at: string }) =>
      visitsApi.update(id, { scheduled_at }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["visits"] });
    },
  });

  const visits: Visit[] = [
    ...((scheduledData as { data?: Visit[] })?.data ?? []),
    ...((inProgressData as { data?: Visit[] })?.data ?? []),
    ...((completedData as { data?: Visit[] })?.data ?? []),
  ];
  const patients: Patient[] = (patientsData as { data?: { patients?: Patient[] } })?.data?.patients ?? [];

  const visitDates = new Set(
    visits.filter(v => v.scheduled_at).map(v => format(new Date(v.scheduled_at), "yyyy-MM-dd"))
  );

  const patientMap = useMemo(() => {
    const map: Record<string, Patient> = {};
    patients.forEach(p => { map[p.id] = p; });
    return map;
  }, [patients]);

  // Day columns: 1 in day view, 7 in week view
  const weekStart = startOfWeek(selectedDate, { weekStartsOn: 1 });
  const weekEnd = endOfWeek(selectedDate, { weekStartsOn: 1 });

  const dayColumns = useMemo(() => {
    if (view === "day") {
      return [{ day: selectedDate, dayVisits: visits.filter(v => v.scheduled_at && isSameDay(new Date(v.scheduled_at), selectedDate)) }];
    }
    return Array.from({ length: 7 }, (_, i) => {
      const day = addDays(weekStart, i);
      return { day, dayVisits: visits.filter(v => v.scheduled_at && isSameDay(new Date(v.scheduled_at), day)) };
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [view, selectedDate, visits]);

  const todayVisits = dayColumns.find(col => isSameDay(col.day, selectedDate))?.dayVisits ?? [];

  // Auto-scroll to first visit when date or view changes
  useEffect(() => {
    if (!scrollContainerRef.current) return;
    const allVisibleVisits = dayColumns.flatMap(c => c.dayVisits);
    if (allVisibleVisits.length === 0) {
      scrollContainerRef.current.scrollTop = HOUR_HEIGHT; // 8am
      return;
    }
    const earliest = allVisibleVisits.reduce((a, b) =>
      new Date(a.scheduled_at) < new Date(b.scheduled_at) ? a : b
    );
    const top = Math.max(0, getTopOffset(earliest.scheduled_at) - 40);
    scrollContainerRef.current.scrollTop = top;
  }, [selectedDate, view, visits.length]);

  // Drag-and-drop handlers
  const onDragStart = useCallback((e: React.DragEvent, visit: Visit) => {
    setDraggingId(visit.id);
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("visitId", visit.id);
  }, []);

  const onDragEnd = useCallback(() => {
    setDraggingId(null);
    setDropIndicator(null);
  }, []);

  const onDragOver = useCallback((e: React.DragEvent, dayIdx: number) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    const rect = e.currentTarget.getBoundingClientRect();
    const y = e.clientY - rect.top;
    setDropIndicator({ dayIdx, top: Math.max(0, Math.min(y, HOURS.length * HOUR_HEIGHT)) });
  }, []);

  const onDrop = useCallback((e: React.DragEvent, day: Date) => {
    e.preventDefault();
    const visitId = e.dataTransfer.getData("visitId");
    if (!visitId) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const y = e.clientY - rect.top;
    const totalMins = Math.max(0, (y / HOUR_HEIGHT) * 60);
    const rawHours = Math.floor(totalMins / 60) + 7;
    const rawMins = snapToQuarter(totalMins % 60);
    const hours = Math.min(18, Math.max(7, rawHours));
    const mins = rawMins >= 60 ? 0 : rawMins;
    const newTime = new Date(day);
    newTime.setHours(hours, mins, 0, 0);
    updateMutation.mutate({ id: visitId, scheduled_at: newTime.toISOString() });
    setDraggingId(null);
    setDropIndicator(null);
  }, [updateMutation]);

  // Navigation: move by 1 day (day view) or 1 week (week view)
  const navBack = () => setSelectedDate(d => addDays(d, view === "week" ? -7 : -1));
  const navForward = () => setSelectedDate(d => addDays(d, view === "week" ? 7 : 1));

  const headerLabel = view === "week"
    ? `${format(weekStart, "MMM d")} – ${format(weekEnd, "MMM d, yyyy")}`
    : format(selectedDate, "EEEE, MMMM d");

  const statusCounts = {
    completed: todayVisits.filter(v => v.status === "completed").length,
    in_progress: todayVisits.filter(v => v.status === "in_progress").length,
    scheduled: todayVisits.filter(v => v.status === "scheduled").length,
  };

  return (
    <div className="flex gap-5 h-full">
      {/* Left sidebar */}
      <div className="w-64 shrink-0 space-y-4">
        {/* Mini calendar */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="flex items-center justify-between mb-3">
            <button onClick={() => setCalMonth(m => subMonths(m, 1))} className="p-1 hover:bg-gray-100 rounded">
              <ChevronLeft className="w-4 h-4 text-gray-500" />
            </button>
            <span className="text-sm font-semibold text-gray-900">{format(calMonth, "MMMM yyyy")}</span>
            <button onClick={() => setCalMonth(m => addMonths(m, 1))} className="p-1 hover:bg-gray-100 rounded">
              <ChevronRight className="w-4 h-4 text-gray-500" />
            </button>
          </div>
          <div className="grid grid-cols-7 text-center mb-1">
            {["M","T","W","T","F","S","S"].map((d, i) => (
              <div key={i} className="text-xs text-gray-400 font-medium py-1">{d}</div>
            ))}
          </div>
          <div className="grid grid-cols-7 text-center gap-y-0.5">
            {calDays.map((day) => {
              const isSelected = isSameDay(day, selectedDate);
              const isToday = isSameDay(day, new Date());
              const isOtherMonth = format(day, "M") !== format(calMonth, "M");
              const hasVisit = visitDates.has(format(day, "yyyy-MM-dd"));
              return (
                <div key={day.toISOString()} className="flex flex-col items-center">
                  <button
                    onClick={() => { setSelectedDate(day); setCalMonth(day); }}
                    className={cn(
                      "text-xs w-7 h-7 rounded-full flex items-center justify-center transition-colors",
                      isSelected ? "bg-blue-600 text-white font-bold"
                        : isToday ? "border border-blue-400 text-blue-600 font-semibold"
                        : isOtherMonth ? "text-gray-300"
                        : "text-gray-700 hover:bg-gray-100"
                    )}
                  >
                    {format(day, "d")}
                  </button>
                  {hasVisit && !isSelected && (
                    <div className="w-1 h-1 rounded-full bg-blue-400 -mt-0.5" />
                  )}
                </div>
              );
            })}
          </div>
          <button
            onClick={() => { setSelectedDate(new Date()); setCalMonth(new Date()); }}
            className="mt-3 w-full text-xs text-blue-600 font-medium hover:underline"
          >
            Go to today
          </button>
        </div>

        {/* Day stats */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">
            {format(selectedDate, "EEEE, MMM d")}
          </div>
          <div className="space-y-2">
            <div className="flex justify-between items-center text-sm">
              <span className="text-gray-600">Total visits</span>
              <span className="font-semibold text-gray-900">{todayVisits.length}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="flex items-center gap-1.5 text-green-600">
                <CheckCircle2 className="w-3.5 h-3.5" /> Completed
              </span>
              <span className="font-semibold">{statusCounts.completed}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="flex items-center gap-1.5 text-blue-600">
                <Loader2 className="w-3.5 h-3.5" /> In Progress
              </span>
              <span className="font-semibold">{statusCounts.in_progress}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="flex items-center gap-1.5 text-gray-500">
                <Clock className="w-3.5 h-3.5" /> Scheduled
              </span>
              <span className="font-semibold">{statusCounts.scheduled}</span>
            </div>
          </div>
        </div>

        {/* Clinicians legend */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Visit Types</div>
          {Object.entries(VISIT_TYPE_COLORS).map(([key, val]) => (
            <div key={key} className="flex items-center gap-2 py-1">
              <div className={cn("w-5 h-5 rounded text-xs font-bold flex items-center justify-center border", val.bg, val.border)}>
                {val.label[0]}
              </div>
              <span className="text-xs text-gray-600 capitalize">{key.replace(/_/g, " ")}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Main calendar */}
      <div className="flex-1 bg-white rounded-xl border border-gray-200 overflow-hidden flex flex-col">
        {/* Header */}
        <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-3">
            <button onClick={navBack} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <ChevronLeft className="w-4 h-4 text-gray-500" />
            </button>
            <h2 className="text-base font-semibold text-gray-900">{headerLabel}</h2>
            <button onClick={navForward} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <ChevronRight className="w-4 h-4 text-gray-500" />
            </button>
          </div>
          <div className="flex items-center gap-2">
            <div className="flex bg-gray-100 rounded-lg p-0.5 text-xs">
              <button
                onClick={() => setView("day")}
                className={cn("px-3 py-1 rounded-md transition-colors", view === "day" ? "bg-white shadow text-gray-900 font-medium" : "text-gray-500")}
              >Day</button>
              <button
                onClick={() => setView("week")}
                className={cn("px-3 py-1 rounded-md transition-colors", view === "week" ? "bg-white shadow text-gray-900 font-medium" : "text-gray-500")}
              >Week</button>
            </div>
            <Link href="/visits/new" className="bg-blue-600 text-white text-xs font-medium px-3 py-1.5 rounded-lg hover:bg-blue-700">
              + New Visit
            </Link>
          </div>
        </div>

        {/* Time grid */}
        <div className="flex-1 overflow-auto" ref={scrollContainerRef}>
          <div className="flex" style={{ minWidth: view === "week" ? "700px" : undefined }}>
            {/* Time labels */}
            <div className="w-14 shrink-0 border-r border-gray-100 sticky left-0 bg-white z-20">
              {view === "week" && <div className="h-10 border-b border-gray-100" />}
              {HOURS.map(h => (
                <div key={h} className="h-20 flex items-start justify-end pr-2 pt-1">
                  <span className="text-xs text-gray-400">
                    {h > 12 ? `${h - 12}pm` : h === 12 ? "12pm" : `${h}am`}
                  </span>
                </div>
              ))}
            </div>

            {/* Day columns */}
            {dayColumns.map(({ day, dayVisits }, colIdx) => {
              const isToday = isSameDay(day, new Date());
              return (
                <div
                  key={colIdx}
                  className={cn(
                    "flex-1 relative border-r border-gray-100 last:border-r-0",
                    view === "week" && isToday && "bg-blue-50/20",
                  )}
                >
                  {/* Week view day header */}
                  {view === "week" && (
                    <div className={cn(
                      "h-10 border-b border-gray-100 flex flex-col items-center justify-center sticky top-0 bg-white z-10",
                      isToday && "text-blue-600"
                    )}>
                      <span className="text-xs text-gray-400">{format(day, "EEE")}</span>
                      <span className={cn("text-sm font-bold", isToday ? "text-blue-600" : "text-gray-800")}>
                        {format(day, "d")}
                      </span>
                    </div>
                  )}

                  {/* Droppable content area */}
                  <div
                    className="relative"
                    style={{ height: `${HOURS.length * HOUR_HEIGHT}px` }}
                    onDragOver={e => onDragOver(e, colIdx)}
                    onDragLeave={() => setDropIndicator(null)}
                    onDrop={e => onDrop(e, day)}
                  >
                    {/* Hour grid lines */}
                    {HOURS.map(h => (
                      <div
                        key={h}
                        className="absolute inset-x-0 border-b border-gray-50"
                        style={{ top: `${(h - 7) * HOUR_HEIGHT}px`, height: `${HOUR_HEIGHT}px` }}
                      />
                    ))}

                    {/* Drop indicator */}
                    {dropIndicator && dropIndicator.dayIdx === colIdx && (
                      <div
                        className="absolute left-1 right-1 h-0.5 bg-blue-500 rounded pointer-events-none z-20"
                        style={{ top: dropIndicator.top }}
                      >
                        <div className="w-2 h-2 rounded-full bg-blue-500 -mt-0.75 -ml-0.5" />
                      </div>
                    )}

                    {/* Current time line */}
                    {isToday && (
                      <div
                        className="absolute left-0 right-0 z-10 pointer-events-none"
                        style={{ top: getTopOffset(Date.now()) }}
                      >
                        <div className="flex items-center">
                          <div className="w-2.5 h-2.5 rounded-full bg-red-500 -ml-1" />
                          <div className="flex-1 h-px bg-red-400" />
                        </div>
                      </div>
                    )}

                    {/* Visit blocks */}
                    {dayVisits.map(visit => (
                      <VisitBlock
                        key={visit.id}
                        visit={visit}
                        patient={patientMap[visit.patient_id]}
                        compact={view === "week"}
                        onDragStart={onDragStart}
                        draggingId={draggingId}
                      />
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
