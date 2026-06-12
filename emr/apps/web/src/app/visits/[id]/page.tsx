"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { visitsApi } from "@/lib/api";
import { cn, formatDateTime } from "@/lib/utils";
import {
  Brain, AlertTriangle, CheckCircle2, Mic, MicOff,
  FileText, ChevronDown, ChevronUp, Loader2, Zap
} from "lucide-react";

export default function VisitPage({ params }: { params: { id: string } }) {
  const qc = useQueryClient();
  const [noteText, setNoteText] = useState("");
  const [briefOpen, setBriefOpen] = useState(true);
  const [soapOpen, setSoapOpen] = useState(true);
  const [recording, setRecording] = useState(false);

  const { data: visitData, isError: visitError } = useQuery({
    queryKey: ["visit", params.id],
    queryFn: () => visitsApi.get(params.id),
    retry: false,
  });

  const { data: briefData, isLoading: briefLoading } = useQuery({
    queryKey: ["visit-brief", params.id],
    queryFn: () => visitsApi.preBrief(params.id),
    enabled: !!visitData?.data,
    retry: false,
    throwOnError: false,
  });

  const startMutation = useMutation({
    mutationFn: () => visitsApi.start(params.id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["visit", params.id] }),
  });

  const submitMutation = useMutation({
    mutationFn: (finalize: boolean) => visitsApi.submitNote(params.id, { raw_note: noteText, finalize }),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["visit", params.id] });
      setSoapOpen(true);
    },
  });

  const visit = visitData?.data;
  const brief = briefData?.data;
  // Prefer the just-processed note, then whatever is saved on the visit
  // (including notes the AI chat assistant wrote via update_visit)
  const savedSoap =
    visit && (visit.subjective || visit.objective || visit.assessment || visit.plan)
      ? { subjective: visit.subjective, objective: visit.objective, assessment: visit.assessment, plan: visit.plan }
      : visit?.structured_note;
  const structured = submitMutation.data?.data?.structured_note ?? savedSoap;
  const actionItems = submitMutation.data?.data?.action_items ?? visit?.action_items ?? [];

  if (visitError) return <div className="py-12 text-center text-gray-400">Visit not found or failed to load.</div>;
  if (!visit) return <div className="py-12 text-center text-gray-400">Loading visit...</div>;

  return (
    <div className="max-w-5xl space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">
            {visit.visit_type.replace(/_/g, " ").replace(/\b\w/g, (c: string) => c.toUpperCase())} Visit
          </h1>
          <p className="text-sm text-gray-500">{formatDateTime(visit.scheduled_at)}</p>
        </div>
        <div className="flex items-center gap-2">
          <span className={cn(
            "text-xs font-medium px-2.5 py-1 rounded-full",
            visit.status === "completed" ? "bg-green-50 text-green-700" :
            visit.status === "in_progress" ? "bg-blue-50 text-blue-700" :
            "bg-gray-100 text-gray-600"
          )}>
            {visit.status.replace("_", " ")}
          </span>
          {visit.status === "scheduled" && (
            <button
              onClick={() => startMutation.mutate()}
              disabled={startMutation.isPending}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700"
            >
              Start Visit
            </button>
          )}
        </div>
      </div>

      {/* Pre-visit brief */}
      {brief && (
        <div className="bg-white rounded-xl border border-blue-200 overflow-hidden">
          <button
            onClick={() => setBriefOpen(!briefOpen)}
            className="w-full flex items-center justify-between px-5 py-4 text-left hover:bg-blue-50/30"
          >
            <div className="flex items-center gap-2">
              <Brain className="w-5 h-5 text-blue-600" />
              <span className="font-semibold text-gray-900">AI Pre-Visit Brief</span>
              {brief.clinical_alerts?.length > 0 && (
                <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full font-medium">
                  {brief.clinical_alerts.length} Alert{brief.clinical_alerts.length > 1 ? "s" : ""}
                </span>
              )}
            </div>
            {briefOpen ? <ChevronUp className="w-4 h-4 text-gray-400" /> : <ChevronDown className="w-4 h-4 text-gray-400" />}
          </button>

          {briefOpen && (
            <div className="px-5 pb-5 space-y-4">
              {/* Alerts */}
              {brief.clinical_alerts?.length > 0 && (
                <div className="space-y-2">
                  {brief.clinical_alerts.map((alert: { severity: string; message: string }, i: number) => (
                    <div key={i} className={cn(
                      "flex items-start gap-2 p-3 rounded-lg text-sm",
                      alert.severity === "high" ? "bg-red-50 text-red-800" :
                      alert.severity === "medium" ? "bg-orange-50 text-orange-800" :
                      "bg-yellow-50 text-yellow-800"
                    )}>
                      <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                      {alert.message}
                    </div>
                  ))}
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Focus Areas</div>
                  <ul className="space-y-1">
                    {(brief.priority_focus_areas ?? []).map((f: string, i: number) => (
                      <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                        <CheckCircle2 className="w-3.5 h-3.5 text-blue-500 mt-0.5 shrink-0" />{f}
                      </li>
                    ))}
                  </ul>
                </div>
                <div>
                  <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Visit Goals</div>
                  <ul className="space-y-1">
                    {(brief.visit_goals ?? []).map((g: string, i: number) => (
                      <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                        <CheckCircle2 className="w-3.5 h-3.5 text-green-500 mt-0.5 shrink-0" />{g}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {brief.care_gaps?.length > 0 && (
                <div>
                  <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Care Gaps</div>
                  <div className="flex flex-wrap gap-1.5">
                    {brief.care_gaps.map((g: string) => (
                      <span key={g} className="text-xs bg-amber-50 text-amber-700 border border-amber-200 px-2 py-0.5 rounded-full">{g}</span>
                    ))}
                  </div>
                </div>
              )}

              <div className="p-3 bg-gray-50 rounded-lg text-sm text-gray-700">
                <span className="font-medium">Risk Summary: </span>{brief.risk_summary}
              </div>
            </div>
          )}
        </div>
      )}

      {briefLoading && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-3 text-sm text-gray-500">
          <Loader2 className="w-4 h-4 animate-spin text-blue-500" />
          Generating AI pre-visit brief...
        </div>
      )}

      {/* Note input */}
      {(visit.status === "in_progress" || visit.status === "scheduled") && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <FileText className="w-4 h-4 text-gray-500" /> Visit Note
            </h2>
            <button
              onClick={() => setRecording(!recording)}
              className={cn(
                "flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
                recording ? "bg-red-100 text-red-700 hover:bg-red-200" : "bg-gray-100 text-gray-700 hover:bg-gray-200"
              )}
            >
              {recording ? <><MicOff className="w-4 h-4" /> Stop Recording</> : <><Mic className="w-4 h-4" /> Dictate</>}
            </button>
          </div>
          <textarea
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            placeholder="Enter your visit note here — dictate or type. Include vitals, observations, patient complaints, physical exam findings, and your assessment. AI will structure this into SOAP format and auto-generate action items..."
            className="w-full h-48 p-3 text-sm border border-gray-200 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <div className="flex gap-3">
            <button
              onClick={() => submitMutation.mutate(false)}
              disabled={!noteText.trim() || submitMutation.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-medium hover:bg-gray-200 disabled:opacity-50"
            >
              {submitMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <Brain className="w-4 h-4" />}
              Process with AI
            </button>
            <button
              onClick={() => submitMutation.mutate(true)}
              disabled={!noteText.trim() || submitMutation.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50"
            >
              {submitMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
              Process & Finalize
            </button>
          </div>
        </div>
      )}

      {/* SOAP Note */}
      {structured && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <button
            onClick={() => setSoapOpen(!soapOpen)}
            className="w-full flex items-center justify-between px-5 py-4 hover:bg-gray-50"
          >
            <span className="font-semibold text-gray-900">Structured SOAP Note</span>
            {soapOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
          {soapOpen && (
            <div className="px-5 pb-5 space-y-4 text-sm">
              {[
                ["Subjective", structured.subjective],
                ["Objective", structured.objective],
                ["Assessment", structured.assessment],
                ["Plan", structured.plan],
              ].map(([label, content]) => content && (
                <div key={label}>
                  <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">{label}</div>
                  <p className="text-gray-700 leading-relaxed">{content}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Action items */}
      {actionItems.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold text-gray-900 flex items-center gap-2 mb-3">
            <Zap className="w-4 h-4 text-yellow-500" /> Auto-Generated Action Items
          </h2>
          <div className="space-y-2">
            {actionItems.map((item: { priority: string; type: string; description: string; due_in_hours: number }, i: number) => (
              <div key={i} className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
                <span className={cn(
                  "text-xs font-bold px-1.5 py-0.5 rounded shrink-0 mt-0.5",
                  item.priority === "urgent" ? "bg-red-100 text-red-700" :
                  item.priority === "high" ? "bg-orange-100 text-orange-700" :
                  "bg-blue-100 text-blue-700"
                )}>
                  {item.priority.toUpperCase()}
                </span>
                <div className="flex-1">
                  <div className="text-sm text-gray-900">{item.description}</div>
                  <div className="text-xs text-gray-500 mt-0.5 capitalize">
                    {item.type.replace(/_/g, " ")} · Due in {item.due_in_hours}h
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
