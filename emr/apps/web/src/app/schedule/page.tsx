"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { visitsApi, patientsApi } from "@/lib/api";
import { Visit, Patient } from "@/types";
import { cn, formatDate } from "@/lib/utils";
import {
  ChevronLeft, ChevronRight, Brain, AlertTriangle,
  MapPin, Clock, CheckCircle2, Loader2, User
} from "lucide-react";
import Link from "next/link";
import { format, addDays, startOfWeek, isSameDay } from "date-fns";

const VISIT_TYPE_COLORS: Record<string, { bg: string; border: string; label: string }> = {
  skilled_nursing:    { bg: "bg-blue-50",   border: "border-blue-300",  label: "SN" },
  physical_therapy:   { bg: "bg-purple-50", border: "border-purple-300",label: "PT" },
  occupational_therapy:{ bg: "bg-teal-50",  border: "border-teal-300",  label: "OT" },
  speech_therapy:     { bg: "bg-pink-50",   border: "border-pink-300",  label: "ST" },
  social_work:        { bg: "bg-orange-50", border: "border-orange-300",label: "SW" },
  aide:               { bg: "bg-gray-50",   border: "border-gray-300",  label: "HHA" },
  telehealth:         { bg: "bg-cyan-50",   border: "border-cyan-300",  label: "TH" },
};

const HOURS = Array.from({ length: 13 }, (_, i) => i + 7); // 7am–7pm

function riskColor(score?: number) {
  if (!score) return "";
  if (score >= 0.9) return "text-red-600";
  if (score >= 0.7) return "text-orange-500";
  if (score >= 0.4) return "text-yellow-600";
  return "text-green-600";
}

// Mock visits for demo — replace with real API query
const MOCK_VISITS = [
  { id: "v1", patient_id: "p1", visit_type: "skilled_nursing",  status: "scheduled",  scheduled_at: new Date().setHours(8,  0),  patient_name: "Voss, Eleanor",    risk: 0.94, dx: "HFrEF · CKD", address: "142 Maple St", brief_ready: true  },
  { id: "v2", patient_id: "p2", visit_type: "physical_therapy", status: "scheduled",  scheduled_at: new Date().setHours(9, 30),  patient_name: "Liang, Dorothy",   risk: 0.82, dx: "Post-hip fx",  address: "88 Oak Ave",  brief_ready: true  },
  { id: "v3", patient_id: "p3", visit_type: "skilled_nursing",  status: "in_progress",scheduled_at: new Date().setHours(11, 0),  patient_name: "Rodriguez, Manuel",risk: 0.87, dx: "COPD · HTN",   address: "310 Pine Rd", brief_ready: true  },
  { id: "v4", patient_id: "p4", visit_type: "social_work",      status: "scheduled",  scheduled_at: new Date().setHours(13, 0),  patient_name: "Washington, Percy",risk: 0.76, dx: "Stroke · dysph",address: "55 Elm St",  brief_ready: false },
  { id: "v5", patient_id: "p5", visit_type: "occupational_therapy",status:"scheduled",scheduled_at: new Date().setHours(14, 30), patient_name: "Hernandez, Juanita",risk:0.71, dx: "T1DM · neuropathy",address:"201 Cedar Ln",brief_ready: true },
  { id: "v6", patient_id: "p6", visit_type: "skilled_nursing",  status: "completed",  scheduled_at: new Date().setHours(7,  0),  patient_name: "Moss, Robert",     risk: 0.63, dx: "CHF · AFib",   address: "17 Birch Pl", brief_ready: true  },
  { id: "v7", patient_id: "p7", visit_type: "telehealth",       status: "scheduled",  scheduled_at: new Date().setHours(16, 0),  patient_name: "Kim, Grace",       risk: 0.45, dx: "DM2 · HTN",   address: "Telehealth",  brief_ready: true  },
  { id: "v8", patient_id: "p8", visit_type: "aide",             status: "scheduled",  scheduled_at: new Date().setHours(10, 0),  patient_name: "Turner, James",    risk: 0.38, dx: "Post-surgical", address: "740 Spruce Dr",brief_ready:true },
];

function getTopOffset(ts: number) {
  const d = new Date(ts);
  const mins = (d.getHours() - 7) * 60 + d.getMinutes();
  return (mins / 60) * 80; // 80px per hour
}

export default function SchedulePage() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [view, setView] = useState<"day" | "week">("day");

  const weekStart = startOfWeek(selectedDate, { weekStartsOn: 1 });
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  const todayVisits = MOCK_VISITS; // In production: filter by selectedDate

  const statusCounts = {
    completed: todayVisits.filter(v => v.status === "completed").length,
    in_progress: todayVisits.filter(v => v.status === "in_progress").length,
    scheduled: todayVisits.filter(v => v.status === "scheduled").length,
  };

  return (
    <div className="flex gap-5 h-full">
      {/* Left sidebar — mini calendar + stats */}
      <div className="w-64 shrink-0 space-y-4">
        {/* Mini calendar nav */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="flex items-center justify-between mb-3">
            <button onClick={() => setSelectedDate(d => addDays(d, -7))} className="p-1 hover:bg-gray-100 rounded">
              <ChevronLeft className="w-4 h-4 text-gray-500" />
            </button>
            <span className="text-sm font-semibold text-gray-900">
              {format(selectedDate, "MMMM yyyy")}
            </span>
            <button onClick={() => setSelectedDate(d => addDays(d, 7))} className="p-1 hover:bg-gray-100 rounded">
              <ChevronRight className="w-4 h-4 text-gray-500" />
            </button>
          </div>
          <div className="grid grid-cols-7 text-center mb-1">
            {["M","T","W","T","F","S","S"].map((d, i) => (
              <div key={i} className="text-xs text-gray-400 font-medium py-1">{d}</div>
            ))}
          </div>
          <div className="grid grid-cols-7 text-center gap-y-1">
            {weekDays.map((day) => (
              <button
                key={day.toISOString()}
                onClick={() => setSelectedDate(day)}
                className={cn(
                  "text-xs w-7 h-7 rounded-full mx-auto flex items-center justify-center transition-colors",
                  isSameDay(day, selectedDate)
                    ? "bg-blue-600 text-white font-bold"
                    : isSameDay(day, new Date())
                    ? "border border-blue-400 text-blue-600 font-semibold"
                    : "text-gray-700 hover:bg-gray-100"
                )}
              >
                {format(day, "d")}
              </button>
            ))}
          </div>
          <button
            onClick={() => setSelectedDate(new Date())}
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
          <div className="mt-3 pt-3 border-t border-gray-100">
            <div className="text-xs text-gray-500 mb-1.5">AI Briefs</div>
            <div className="flex gap-2 text-xs">
              <span className="bg-green-50 text-green-700 px-2 py-0.5 rounded-full font-medium">
                {todayVisits.filter(v => v.brief_ready).length} ready
              </span>
              <span className="bg-yellow-50 text-yellow-700 px-2 py-0.5 rounded-full font-medium">
                {todayVisits.filter(v => !v.brief_ready).length} pending
              </span>
            </div>
          </div>
        </div>

        {/* Clinician filter */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Clinicians</div>
          {[
            { name: "Dr. Sarah Kim", role: "SN", count: 3, color: "bg-blue-100 text-blue-700" },
            { name: "Mike Torres", role: "PT", count: 2, color: "bg-purple-100 text-purple-700" },
            { name: "Aisha Patel", role: "OT", count: 1, color: "bg-teal-100 text-teal-700" },
            { name: "James Wu", role: "SW", count: 2, color: "bg-orange-100 text-orange-700" },
          ].map((c) => (
            <div key={c.name} className="flex items-center gap-2 py-1.5">
              <div className={cn("w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0", c.color)}>
                {c.role}
              </div>
              <span className="text-xs text-gray-700 flex-1">{c.name}</span>
              <span className="text-xs text-gray-400">{c.count}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Main calendar area */}
      <div className="flex-1 bg-white rounded-xl border border-gray-200 overflow-hidden flex flex-col">
        {/* Calendar header */}
        <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-3">
            <button onClick={() => setSelectedDate(d => addDays(d, -1))} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <ChevronLeft className="w-4 h-4 text-gray-500" />
            </button>
            <h2 className="text-base font-semibold text-gray-900">
              {format(selectedDate, "EEEE, MMMM d")}
            </h2>
            <button onClick={() => setSelectedDate(d => addDays(d, 1))} className="p-1.5 hover:bg-gray-100 rounded-lg">
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
        <div className="flex-1 overflow-auto">
          <div className="flex">
            {/* Time labels */}
            <div className="w-14 shrink-0 border-r border-gray-100">
              {HOURS.map(h => (
                <div key={h} className="h-20 flex items-start justify-end pr-2 pt-1">
                  <span className="text-xs text-gray-400">{h > 12 ? `${h-12}pm` : h === 12 ? "12pm" : `${h}am`}</span>
                </div>
              ))}
            </div>

            {/* Day column */}
            <div className="flex-1 relative">
              {/* Hour lines */}
              {HOURS.map(h => (
                <div key={h} className="h-20 border-b border-gray-50" />
              ))}

              {/* Current time line */}
              {isSameDay(selectedDate, new Date()) && (
                <div
                  className="absolute left-0 right-0 z-10 pointer-events-none"
                  style={{ top: getTopOffset(Date.now()) }}
                >
                  <div className="flex items-center">
                    <div className="w-2.5 h-2.5 rounded-full bg-red-500 -ml-1.5" />
                    <div className="flex-1 h-px bg-red-400" />
                  </div>
                </div>
              )}

              {/* Visit blocks */}
              {todayVisits.map((visit) => {
                const top = getTopOffset(visit.scheduled_at);
                const colors = VISIT_TYPE_COLORS[visit.visit_type] ?? { bg: "bg-gray-50", border: "border-gray-300", label: "?" };
                const isCompleted = visit.status === "completed";
                const isInProgress = visit.status === "in_progress";

                return (
                  <Link
                    key={visit.id}
                    href={`/visits/${visit.id}`}
                    className={cn(
                      "absolute left-2 right-2 rounded-lg border p-2.5 cursor-pointer transition-all hover:shadow-md hover:-translate-y-px",
                      colors.bg, colors.border,
                      isCompleted && "opacity-60",
                    )}
                    style={{ top: top + 2, minHeight: "68px" }}
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
                          {isCompleted && (
                            <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />
                          )}
                        </div>
                        <div className="font-semibold text-sm text-gray-900 truncate">{visit.patient_name}</div>
                        <div className="text-xs text-gray-500 truncate">{visit.dx}</div>
                        <div className="flex items-center gap-1 mt-1">
                          <MapPin className="w-3 h-3 text-gray-400 shrink-0" />
                          <span className="text-xs text-gray-400 truncate">{visit.address}</span>
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-1 flex-shrink-0">
                        <span className={cn("text-xs font-bold", riskColor(visit.risk))}>
                          {Math.round(visit.risk * 100)}%
                        </span>
                        {visit.brief_ready ? (
                          <span title="AI Brief Ready"><Brain className="w-3.5 h-3.5 text-blue-500" /></span>
                        ) : (
                          <span title="Generating Brief"><Loader2 className="w-3.5 h-3.5 text-yellow-400 animate-spin" /></span>
                        )}
                      </div>
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
