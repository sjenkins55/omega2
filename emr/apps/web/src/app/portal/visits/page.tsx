"use client";
import { useEffect, useState } from "react";
import { portalApi } from "@/lib/api";
import { Calendar, Clock, Activity, ChevronDown, ChevronUp } from "lucide-react";

const VISIT_LABELS: Record<string, string> = {
  skilled_nursing: "Skilled Nursing",
  physical_therapy: "Physical Therapy",
  occupational_therapy: "Occupational Therapy",
  speech_therapy: "Speech Therapy",
  social_work: "Social Work",
  aide: "Home Health Aide",
  telehealth: "Telehealth",
};

type VisitSummary = {
  id: string;
  visit_type: string;
  scheduled_at: string | null;
  completed_at: string | null;
  assessment?: string;
  plan?: string;
  vital_signs?: Record<string, number>;
  action_items?: { priority: string; description: string }[];
};

function VitalBadge({ label, value, unit }: { label: string; value: number; unit: string }) {
  return (
    <div className="bg-slate-50 rounded-xl p-3 text-center">
      <div className="text-lg font-bold text-slate-900">{value}<span className="text-xs text-slate-400 font-normal ml-0.5">{unit}</span></div>
      <div className="text-xs text-slate-500 mt-0.5">{label}</div>
    </div>
  );
}

function PastVisitCard({ visit }: { visit: VisitSummary }) {
  const [expanded, setExpanded] = useState(false);
  const vitals = visit.vital_signs ?? {};

  return (
    <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
      <button
        onClick={() => setExpanded(e => !e)}
        className="w-full flex items-center justify-between p-4 text-left hover:bg-slate-50 transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center shrink-0">
            <Clock className="w-5 h-5 text-slate-500" />
          </div>
          <div>
            <div className="text-sm font-semibold text-slate-900">
              {VISIT_LABELS[visit.visit_type] ?? visit.visit_type}
            </div>
            <div className="text-xs text-slate-500">
              {visit.completed_at
                ? new Date(visit.completed_at).toLocaleDateString("en-US", {
                    weekday: "long", month: "long", day: "numeric", year: "numeric",
                  })
                : "Date unknown"}
            </div>
          </div>
        </div>
        {expanded ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
      </button>

      {expanded && (
        <div className="px-4 pb-4 space-y-4 border-t border-slate-100 pt-4">
          {/* Vitals */}
          {Object.keys(vitals).length > 0 && (
            <div>
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2 flex items-center gap-1.5">
                <Activity className="w-3.5 h-3.5" /> Vitals
              </h3>
              <div className="grid grid-cols-3 gap-2">
                {vitals.heart_rate != null && <VitalBadge label="Heart Rate" value={vitals.heart_rate} unit="bpm" />}
                {vitals.bp_systolic != null && vitals.bp_diastolic != null && (
                  <div className="bg-slate-50 rounded-xl p-3 text-center">
                    <div className="text-lg font-bold text-slate-900">{vitals.bp_systolic}/{vitals.bp_diastolic}</div>
                    <div className="text-xs text-slate-500 mt-0.5">Blood Pressure</div>
                  </div>
                )}
                {vitals.o2_saturation != null && <VitalBadge label="O₂ Sat" value={vitals.o2_saturation} unit="%" />}
                {vitals.temperature != null && <VitalBadge label="Temp" value={vitals.temperature} unit="°F" />}
                {vitals.weight_kg != null && <VitalBadge label="Weight" value={Math.round(vitals.weight_kg * 2.205)} unit="lbs" />}
                {vitals.pain_score != null && <VitalBadge label="Pain" value={vitals.pain_score} unit="/10" />}
              </div>
            </div>
          )}

          {/* Assessment */}
          {visit.assessment && (
            <div>
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-1.5">Assessment</h3>
              <p className="text-sm text-slate-700 leading-relaxed">{visit.assessment}</p>
            </div>
          )}

          {/* Plan */}
          {visit.plan && (
            <div>
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-1.5">Care Plan</h3>
              <p className="text-sm text-slate-700 leading-relaxed">{visit.plan}</p>
            </div>
          )}

          {/* Action items */}
          {(visit.action_items ?? []).length > 0 && (
            <div>
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">Follow-up Items</h3>
              <div className="space-y-1.5">
                {visit.action_items!.map((item, i) => (
                  <div key={i} className="flex items-start gap-2 text-sm text-slate-700">
                    <div className={`w-1.5 h-1.5 rounded-full shrink-0 mt-1.5 ${
                      item.priority === "high" ? "bg-red-400" :
                      item.priority === "medium" ? "bg-amber-400" : "bg-green-400"
                    }`} />
                    {item.description}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function PortalVisits() {
  const [upcoming, setUpcoming] = useState<VisitSummary[]>([]);
  const [past, setPast] = useState<VisitSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    portalApi.get("/portal/visits")
      .then(r => { setUpcoming(r.data.upcoming); setPast(r.data.past); })
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-slate-400 text-sm">Loading visits…</div>
    </div>
  );

  return (
    <div className="max-w-lg mx-auto px-4 py-6 space-y-6">
      {/* Upcoming */}
      <section>
        <h2 className="text-lg font-bold text-slate-900 mb-3">Upcoming Visits</h2>
        {upcoming.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-6 text-center">
            <Calendar className="w-10 h-10 text-slate-200 mx-auto mb-2" />
            <p className="text-slate-500 text-sm">No upcoming visits scheduled</p>
          </div>
        ) : (
          <div className="space-y-3">
            {upcoming.map(v => (
              <div key={v.id} className="bg-blue-600 rounded-2xl p-4 text-white">
                <div className="text-blue-200 text-xs font-medium mb-1 uppercase tracking-wide">
                  {VISIT_LABELS[v.visit_type] ?? v.visit_type}
                </div>
                <div className="font-bold text-lg">
                  {v.scheduled_at ? new Date(v.scheduled_at).toLocaleDateString("en-US", {
                    weekday: "long", month: "long", day: "numeric",
                  }) : "Date TBD"}
                </div>
                {v.scheduled_at && (
                  <div className="text-blue-200 text-sm mt-0.5">
                    {new Date(v.scheduled_at).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Past */}
      <section>
        <h2 className="text-lg font-bold text-slate-900 mb-3">Visit History</h2>
        {past.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-6 text-center">
            <p className="text-slate-500 text-sm">No completed visits yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {past.map(v => <PastVisitCard key={v.id} visit={v} />)}
          </div>
        )}
      </section>
    </div>
  );
}
