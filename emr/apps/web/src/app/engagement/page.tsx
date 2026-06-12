"use client";
import { Suspense, useEffect, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { engagementApi, patientsApi } from "@/lib/api";
import { OutreachRecord } from "@/types";
import { cn, formatDateTime } from "@/lib/utils";
import { MessageSquare, Send, Loader2, Plus, Phone, Mail, X, AlertTriangle, Users, CheckCircle2 } from "lucide-react";
import { useSearchParams } from "next/navigation";

const CHANNEL_ICONS: Record<string, React.ReactNode> = {
  sms: <MessageSquare className="w-4 h-4" />,
  email: <Mail className="w-4 h-4" />,
  phone: <Phone className="w-4 h-4" />,
};

const STATUS_COLORS: Record<string, string> = {
  scheduled: "bg-blue-50 text-blue-700",
  sent: "bg-purple-50 text-purple-700",
  delivered: "bg-teal-50 text-teal-700",
  failed: "bg-red-50 text-red-700",
  responded: "bg-green-50 text-green-700",
  no_response: "bg-gray-100 text-gray-600",
};

type PatientLite = { id: string; first_name: string; last_name: string; mrn: string; phone?: string; ai_risk_score?: number; primary_dx?: string };

function riskLabel(score?: number) {
  if (!score) return null;
  if (score >= 0.9) return { label: "Critical", color: "text-red-700 bg-red-50" };
  if (score >= 0.7) return { label: "High", color: "text-orange-700 bg-orange-50" };
  if (score >= 0.4) return { label: "Medium", color: "text-yellow-700 bg-yellow-50" };
  return null;
}

function OutreachForm({ onClose, patients }: { onClose: () => void; patients: PatientLite[] }) {
  const qc = useQueryClient();
  const [form, setForm] = useState({
    patient_id: "",
    outreach_type: "post_visit_checkin",
    channel: "sms",
    scheduled_at: "",
    message_content: "",
  });

  const createMutation = useMutation({
    mutationFn: () =>
      engagementApi.create({
        patient_id: form.patient_id,
        outreach_type: form.outreach_type,
        channel: form.channel,
        scheduled_at: form.scheduled_at,
        message_content: form.message_content || undefined,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["outreach"] });
      onClose();
    },
  });

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold text-gray-900">New Outreach</h2>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-4 h-4" /></button>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Patient</label>
          <select value={form.patient_id} onChange={(e) => setForm((f) => ({ ...f, patient_id: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            <option value="">Select patient...</option>
            {patients.map((p) => <option key={p.id} value={p.id}>{p.last_name}, {p.first_name}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Outreach Type</label>
          <select value={form.outreach_type} onChange={(e) => setForm((f) => ({ ...f, outreach_type: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            <option value="post_visit_checkin">Post Visit Check-in</option>
            <option value="high_risk_monthly">High Risk Monthly</option>
            <option value="welcome_home_care">Welcome Home Care</option>
            <option value="general_checkin">General Check-in</option>
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Channel</label>
          <select value={form.channel} onChange={(e) => setForm((f) => ({ ...f, channel: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            <option value="sms">SMS</option>
            <option value="email">Email</option>
            <option value="phone">Phone</option>
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Scheduled At</label>
          <input type="datetime-local" value={form.scheduled_at}
            onChange={(e) => setForm((f) => ({ ...f, scheduled_at: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
      </div>
      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">Message (optional — leave blank to AI-generate)</label>
        <textarea value={form.message_content} onChange={(e) => setForm((f) => ({ ...f, message_content: e.target.value }))}
          rows={3} placeholder="Leave blank to auto-generate..."
          className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none" />
      </div>
      <div className="flex items-center gap-2 justify-end">
        <button onClick={onClose} className="px-4 py-1.5 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50">Cancel</button>
        <button onClick={() => createMutation.mutate()}
          disabled={createMutation.isPending || !form.patient_id || !form.scheduled_at}
          className="flex items-center gap-1.5 px-4 py-1.5 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
          {createMutation.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
          Schedule
        </button>
      </div>
    </div>
  );
}

function EngagementContent() {
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const [activeTab, setActiveTab] = useState<"chase" | "history">("chase");
  const [showCreate, setShowCreate] = useState(false);

  useEffect(() => {
    if (searchParams.get("create") === "1") setShowCreate(true);
  }, [searchParams]);

  const { data, isLoading } = useQuery({
    queryKey: ["outreach"],
    queryFn: () => engagementApi.list({ limit: 200 }),
  });

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const sendMutation = useMutation({
    mutationFn: (id: string) => engagementApi.send(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["outreach"] }),
  });

  const logContactMutation = useMutation({
    mutationFn: (patientId: string) => {
      const soon = new Date(Date.now() + 60000).toISOString();
      return engagementApi.create({
        patient_id: patientId,
        outreach_type: "general_checkin",
        channel: "phone",
        scheduled_at: soon,
      });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["outreach"] }),
  });

  const patients: PatientLite[] = patientsData?.data?.patients ?? [];
  const records: OutreachRecord[] = data?.data ?? [];

  const lastOutreachByPatient = new Map<string, Date>();
  records.forEach((r) => {
    const d = new Date(r.created_at);
    const pid = (r as any).patient_id ?? "";
    const existing = lastOutreachByPatient.get(pid);
    if (!existing || d > existing) lastOutreachByPatient.set(pid, d);
  });

  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const chaseList = patients
    .filter((p) => (p.ai_risk_score ?? 0) >= 0.4)
    .map((p) => ({ ...p, lastOutreach: lastOutreachByPatient.get(p.id) }))
    .filter((p) => !p.lastOutreach || p.lastOutreach < thirtyDaysAgo)
    .sort((a, b) => (b.ai_risk_score ?? 0) - (a.ai_risk_score ?? 0));

  const pending = records.filter((r) => r.status === "scheduled");

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Engagement</h1>
          <p className="text-sm text-gray-500">Patient outreach, chase list, and communication tracking</p>
        </div>
        <button onClick={() => setShowCreate((v) => !v)}
          className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
          <Plus className="w-4 h-4" /> Schedule Outreach
        </button>
      </div>

      {showCreate && <OutreachForm onClose={() => setShowCreate(false)} patients={patients} />}

      <div className="flex gap-1 border-b border-gray-200">
        {([["chase", "Chase List"], ["history", "Outreach History"]] as [string, string][]).map(([key, label]) => (
          <button key={key} onClick={() => setActiveTab(key as "chase" | "history")}
            className={cn("px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px",
              activeTab === key ? "border-blue-600 text-blue-600" : "border-transparent text-gray-500 hover:text-gray-700")}>
            {label}
            {key === "chase" && chaseList.length > 0 && (
              <span className="ml-2 text-xs bg-orange-100 text-orange-700 px-1.5 py-0.5 rounded-full font-semibold">{chaseList.length}</span>
            )}
          </button>
        ))}
      </div>

      {activeTab === "chase" && (
        <div className="space-y-3">
          {pending.length > 0 && (
            <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
              <div className="text-sm font-semibold text-blue-900 mb-2 flex items-center gap-2">
                <Send className="w-4 h-4" /> {pending.length} Message{pending.length > 1 ? "s" : ""} Ready to Send
              </div>
              <div className="space-y-2">
                {pending.slice(0, 3).map((rec) => (
                  <div key={rec.id} className="flex items-center justify-between bg-white rounded-lg px-3 py-2 text-sm">
                    <span className="text-gray-700 capitalize">{rec.outreach_type.replace(/_/g, " ")} · {rec.channel}</span>
                    <button onClick={() => sendMutation.mutate(rec.id)} disabled={sendMutation.isPending}
                      className="flex items-center gap-1 text-blue-600 hover:text-blue-700 font-medium text-xs">
                      {sendMutation.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />} Send
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="bg-white rounded-xl border border-gray-200">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-orange-500" />
              <h2 className="font-semibold text-gray-900">Patients Needing Outreach</h2>
              <span className="text-xs text-gray-400">medium+ risk, no contact in 30 days</span>
            </div>
            {chaseList.length === 0 ? (
              <div className="py-12 text-center">
                <CheckCircle2 className="w-10 h-10 text-green-300 mx-auto mb-3" />
                <p className="text-sm text-gray-400">All patients have been contacted recently</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-50">
                {chaseList.map((p) => {
                  const risk = riskLabel(p.ai_risk_score);
                  return (
                    <div key={p.id} className="flex items-center gap-4 px-5 py-3">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="text-sm font-medium text-gray-900">{p.last_name}, {p.first_name}</span>
                          {risk && <span className={cn("text-xs font-semibold px-2 py-0.5 rounded-full", risk.color)}>{risk.label}</span>}
                          {p.phone && <span className="text-xs text-gray-400">{p.phone}</span>}
                        </div>
                        <div className="text-xs text-gray-400 truncate">{p.primary_dx ?? "No diagnosis"}</div>
                        {p.lastOutreach ? (
                          <div className="text-xs text-gray-400">Last contact: {p.lastOutreach.toLocaleDateString()}</div>
                        ) : (
                          <div className="text-xs text-orange-500 font-medium">Never contacted</div>
                        )}
                      </div>
                      <div className="flex items-center gap-2 shrink-0 flex-wrap justify-end">
                        {p.phone && (
                          <a href={`tel:${p.phone}`}
                            className="flex items-center gap-1 text-xs text-green-700 bg-green-50 border border-green-200 px-2.5 py-1.5 rounded-lg hover:bg-green-100">
                            <Phone className="w-3.5 h-3.5" /> Call
                          </a>
                        )}
                        <button onClick={() => logContactMutation.mutate(p.id)} disabled={logContactMutation.isPending}
                          className="flex items-center gap-1 text-xs text-blue-700 bg-blue-50 border border-blue-200 px-2.5 py-1.5 rounded-lg hover:bg-blue-100">
                          {logContactMutation.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                          Log Contact
                        </button>
                        <button onClick={() => setShowCreate(true)}
                          className="flex items-center gap-1 text-xs text-gray-600 bg-gray-50 border border-gray-200 px-2.5 py-1.5 rounded-lg hover:bg-gray-100">
                          <MessageSquare className="w-3.5 h-3.5" /> Schedule
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === "history" && (
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
            <Users className="w-4 h-4 text-gray-400" />
            <h2 className="font-semibold text-gray-900">All Outreach History</h2>
            <span className="text-xs text-gray-400">({records.length} records)</span>
          </div>
          {isLoading ? (
            <div className="py-12 text-center text-sm text-gray-400">Loading...</div>
          ) : (
            <div className="divide-y divide-gray-50">
              {records.map((rec) => (
                <div key={rec.id} className="flex items-center gap-4 px-5 py-3">
                  <div className="text-gray-400">{CHANNEL_ICONS[rec.channel] ?? <MessageSquare className="w-4 h-4" />}</div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-gray-900 capitalize">{rec.outreach_type.replace(/_/g, " ")}</div>
                    <div className="text-xs text-gray-500 truncate">{rec.message_content?.slice(0, 80) ?? "No message content"}</div>
                  </div>
                  <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full capitalize shrink-0",
                    STATUS_COLORS[rec.status] ?? "bg-gray-100 text-gray-600")}>
                    {rec.status.replace("_", " ")}
                  </span>
                  {rec.status === "scheduled" && (
                    <button onClick={() => sendMutation.mutate(rec.id)} disabled={sendMutation.isPending}
                      className="flex items-center gap-1 text-xs text-blue-600 border border-blue-200 px-2 py-1 rounded-lg hover:bg-blue-50 shrink-0">
                      {sendMutation.isPending ? <Loader2 className="w-3 h-3 animate-spin" /> : <Send className="w-3 h-3" />} Send
                    </button>
                  )}
                  <span className="text-xs text-gray-400 shrink-0">{formatDateTime(rec.created_at)}</span>
                </div>
              ))}
              {records.length === 0 && <div className="py-12 text-center text-sm text-gray-400">No outreach records yet</div>}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function EngagementPage() {
  return (
    <Suspense fallback={<div className="py-12 text-center text-gray-400">Loading...</div>}>
      <EngagementContent />
    </Suspense>
  );
}
