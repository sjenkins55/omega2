"use client";
import { useEffect, useState } from "react";
import { portalApi } from "@/lib/api";
import { Calendar, Pill, AlertCircle, ClipboardList, MessageSquare, ChevronRight, CheckCircle2 } from "lucide-react";
import Link from "next/link";

type DashboardData = {
  patient: { name: string; first_name: string };
  next_visit: { visit_type: string; scheduled_at: string } | null;
  last_visit: { completed_at: string } | null;
  action_items: { priority: string; description: string }[];
  diagnoses_count: number;
  medications_count: number;
  unread_messages: number;
  care_team: { name: string; role: string; phone?: string }[];
  risk_tier: "low" | "moderate" | "high";
  risk_message: string;
};

const VISIT_TYPE_LABELS: Record<string, string> = {
  skilled_nursing: "Skilled Nursing",
  physical_therapy: "Physical Therapy",
  occupational_therapy: "Occupational Therapy",
  speech_therapy: "Speech Therapy",
  social_work: "Social Work",
  aide: "Home Health Aide",
  telehealth: "Telehealth",
};

export default function PortalHome() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    portalApi.get("/portal/dashboard")
      .then(r => setData(r.data))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-slate-400 text-sm">Loading your health summary…</div>
    </div>
  );

  if (!data) return null;

  const riskColor = { low: "green", moderate: "amber", high: "red" }[data.risk_tier];

  return (
    <div className="max-w-lg mx-auto px-4 py-6 space-y-4">
      {/* Greeting */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          Hello, {data.patient.first_name} 👋
        </h1>
        <p className="text-slate-500 text-sm mt-1">Here's your health summary</p>
      </div>

      {/* Risk message */}
      {data.risk_tier !== "low" && (
        <div className={`rounded-2xl p-4 ${
          data.risk_tier === "high" ? "bg-red-50 border border-red-100" : "bg-amber-50 border border-amber-100"
        }`}>
          <div className="flex gap-3">
            <AlertCircle className={`w-5 h-5 shrink-0 mt-0.5 ${data.risk_tier === "high" ? "text-red-500" : "text-amber-500"}`} />
            <p className={`text-sm ${data.risk_tier === "high" ? "text-red-700" : "text-amber-700"}`}>
              {data.risk_message}
            </p>
          </div>
        </div>
      )}

      {/* Next visit */}
      {data.next_visit ? (
        <Link href="/portal/visits" className="block bg-blue-600 rounded-2xl p-5 text-white hover:bg-blue-700 transition-colors">
          <div className="flex items-start justify-between">
            <div>
              <div className="text-blue-200 text-xs font-medium mb-1">NEXT VISIT</div>
              <div className="text-lg font-bold">
                {VISIT_TYPE_LABELS[data.next_visit.visit_type] ?? data.next_visit.visit_type}
              </div>
              <div className="text-blue-200 text-sm mt-1">
                {new Date(data.next_visit.scheduled_at).toLocaleDateString("en-US", {
                  weekday: "long", month: "long", day: "numeric",
                })}
              </div>
              <div className="text-blue-100 text-sm">
                {new Date(data.next_visit.scheduled_at).toLocaleTimeString("en-US", {
                  hour: "numeric", minute: "2-digit",
                })}
              </div>
            </div>
            <Calendar className="w-8 h-8 text-blue-200" />
          </div>
        </Link>
      ) : (
        <div className="bg-slate-100 rounded-2xl p-5 text-center">
          <Calendar className="w-8 h-8 text-slate-300 mx-auto mb-2" />
          <p className="text-slate-500 text-sm font-medium">No upcoming visits scheduled</p>
          <p className="text-slate-400 text-xs mt-1">Contact your care team to schedule</p>
        </div>
      )}

      {/* Quick stats */}
      <div className="grid grid-cols-2 gap-3">
        <Link href="/portal/records" className="bg-white rounded-2xl border border-slate-200 p-4 hover:border-blue-300 transition-colors">
          <Pill className="w-6 h-6 text-violet-500 mb-2" />
          <div className="text-2xl font-bold text-slate-900">{data.medications_count}</div>
          <div className="text-xs text-slate-500">Medication{data.medications_count !== 1 ? "s" : ""}</div>
        </Link>
        <Link href="/portal/records" className="bg-white rounded-2xl border border-slate-200 p-4 hover:border-blue-300 transition-colors">
          <ClipboardList className="w-6 h-6 text-blue-500 mb-2" />
          <div className="text-2xl font-bold text-slate-900">{data.diagnoses_count}</div>
          <div className="text-xs text-slate-500">Diagnos{data.diagnoses_count !== 1 ? "es" : "is"}</div>
        </Link>
      </div>

      {/* Messages */}
      <Link href="/portal/messages" className="flex items-center justify-between bg-white rounded-2xl border border-slate-200 p-4 hover:border-blue-300 transition-colors">
        <div className="flex items-center gap-3">
          <div className="relative">
            <MessageSquare className="w-6 h-6 text-emerald-500" />
            {data.unread_messages > 0 && (
              <div className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full flex items-center justify-center text-white text-[10px] font-bold">
                {data.unread_messages}
              </div>
            )}
          </div>
          <div>
            <div className="text-sm font-medium text-slate-900">Messages</div>
            <div className="text-xs text-slate-500">
              {data.unread_messages > 0 ? `${data.unread_messages} unread from your care team` : "No new messages"}
            </div>
          </div>
        </div>
        <ChevronRight className="w-4 h-4 text-slate-300" />
      </Link>

      {/* Action items from last visit */}
      {data.action_items.length > 0 && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5">
          <h2 className="text-sm font-semibold text-slate-700 mb-3">Your Care Plan</h2>
          <div className="space-y-2.5">
            {data.action_items.slice(0, 4).map((item, i) => (
              <div key={i} className="flex items-start gap-3">
                <CheckCircle2 className={`w-4 h-4 shrink-0 mt-0.5 ${
                  item.priority === "high" ? "text-red-400" :
                  item.priority === "medium" ? "text-amber-400" : "text-green-400"
                }`} />
                <span className="text-sm text-slate-700">{item.description}</span>
              </div>
            ))}
          </div>
          {data.action_items.length > 4 && (
            <p className="text-xs text-slate-400 mt-3">+{data.action_items.length - 4} more items</p>
          )}
        </div>
      )}

      {/* Care team */}
      {data.care_team.length > 0 && (
        <div className="bg-white rounded-2xl border border-slate-200 p-5">
          <h2 className="text-sm font-semibold text-slate-700 mb-3">Your Care Team</h2>
          <div className="space-y-3">
            {data.care_team.map((member, i) => (
              <div key={i} className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-semibold text-sm shrink-0">
                  {member.name.split(" ").map(n => n[0]).join("").slice(0, 2)}
                </div>
                <div>
                  <div className="text-sm font-medium text-slate-900">{member.name}</div>
                  <div className="text-xs text-slate-500 capitalize">{member.role?.replace("_", " ")}</div>
                </div>
                {member.phone && (
                  <a href={`tel:${member.phone}`} className="ml-auto text-xs text-blue-600 hover:underline">
                    Call
                  </a>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
