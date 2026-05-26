"use client";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, visitsApi } from "@/lib/api";
import { cn, formatDate, formatDateTime, riskTierColor } from "@/lib/utils";
import { AlertTriangle, Brain, Pill, FileText, ClipboardList, Activity, ChevronRight } from "lucide-react";
import Link from "next/link";

export default function PatientDetailPage({ params }: { params: { id: string } }) {
  const { data: patientData } = useQuery({
    queryKey: ["patient", params.id],
    queryFn: () => patientsApi.get(params.id),
  });

  const { data: riskData, isLoading: riskLoading } = useQuery({
    queryKey: ["patient-risk", params.id],
    queryFn: () => patientsApi.riskBrief(params.id),
  });

  const patient = patientData?.data;
  const risk = riskData?.data;

  if (!patient) return <div className="py-12 text-center text-gray-400">Loading...</div>;

  const riskTier = risk?.risk_tier ?? (patient.ai_risk_score != null ?
    patient.ai_risk_score >= 0.9 ? "critical" :
    patient.ai_risk_score >= 0.7 ? "high" :
    patient.ai_risk_score >= 0.4 ? "medium" : "low" : "low");

  return (
    <div className="space-y-5 max-w-6xl">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-semibold text-gray-900">{patient.last_name}, {patient.first_name}</h1>
            <span className={cn("text-sm font-medium px-2.5 py-1 rounded-full", riskTierColor(riskTier))}>
              {riskTier.toUpperCase()} RISK
            </span>
          </div>
          <p className="text-sm text-gray-500 mt-0.5">MRN {patient.mrn} · DOB {formatDate(patient.date_of_birth)} · {patient.gender}</p>
        </div>
        <div className="flex gap-2">
          <Link href={`/visits/new?patient=${params.id}`} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
            Start Visit
          </Link>
          <Link href={`/patients/${params.id}/edit`} className="bg-white border border-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-50">
            Edit
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-5">
        {/* Clinical info */}
        <div className="col-span-2 space-y-4">
          {/* AI Risk Analysis */}
          {risk && (
            <div className="bg-white rounded-xl border border-gray-200 p-5">
              <h3 className="font-semibold text-gray-900 flex items-center gap-2 mb-3">
                <Brain className="w-4 h-4 text-blue-500" /> AI Risk Analysis
              </h3>
              <p className="text-sm text-gray-700 mb-3">{risk.rationale}</p>
              <div className="grid grid-cols-3 gap-3">
                <div className="bg-gray-50 rounded-lg p-3">
                  <div className="text-xs text-gray-500">Risk Score</div>
                  <div className="text-xl font-bold text-gray-900">{Math.round((risk.risk_score ?? 0) * 100)}%</div>
                </div>
                <div className="bg-gray-50 rounded-lg p-3">
                  <div className="text-xs text-gray-500">Hosp. Risk (90d)</div>
                  <div className="text-xl font-bold text-gray-900">{Math.round((risk.hospitalization_risk_90d ?? 0) * 100)}%</div>
                </div>
                <div className="bg-gray-50 rounded-lg p-3">
                  <div className="text-xs text-gray-500">ED Risk (30d)</div>
                  <div className="text-xl font-bold text-gray-900">{Math.round((risk.ed_visit_risk_30d ?? 0) * 100)}%</div>
                </div>
              </div>
              {risk.risk_factors?.length > 0 && (
                <div className="mt-3 space-y-1">
                  {risk.risk_factors.slice(0, 4).map((f: { factor: string; description: string }) => (
                    <div key={f.factor} className="flex items-start gap-2 text-sm">
                      <AlertTriangle className="w-3.5 h-3.5 text-orange-400 mt-0.5 shrink-0" />
                      <span className="text-gray-700">{f.factor}: {f.description}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Diagnoses */}
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2 mb-3">
              <Activity className="w-4 h-4 text-red-500" /> Diagnoses
            </h3>
            <p className="text-sm font-medium text-gray-900 mb-2">{patient.primary_dx}</p>
            <div className="flex flex-wrap gap-2">
              {(patient.diagnoses ?? []).map((dx: string) => (
                <span key={dx} className="text-xs bg-red-50 text-red-700 px-2 py-0.5 rounded-full">{dx}</span>
              ))}
            </div>
          </div>

          {/* Medications */}
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2 mb-3">
              <Pill className="w-4 h-4 text-green-500" /> Medications
            </h3>
            {(patient.medications ?? []).length === 0 ? (
              <p className="text-sm text-gray-400">No medications recorded</p>
            ) : (
              <div className="space-y-2">
                {(patient.medications ?? []).map((med: { name: string; dose: string; frequency: string }, i: number) => (
                  <div key={i} className="flex items-center justify-between text-sm py-1.5 border-b border-gray-50 last:border-0">
                    <span className="font-medium text-gray-900">{med.name}</span>
                    <span className="text-gray-500">{med.dose} · {med.frequency}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Side panel */}
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold text-gray-900 mb-3">Contact</h3>
            <div className="space-y-2 text-sm">
              <div><span className="text-gray-500">Phone:</span> <span className="ml-1">{patient.phone ?? "—"}</span></div>
              <div><span className="text-gray-500">Email:</span> <span className="ml-1">{patient.email ?? "—"}</span></div>
              <div><span className="text-gray-500">Insurance:</span> <span className="ml-1 capitalize">{patient.insurance_type ?? "—"}</span></div>
              <div><span className="text-gray-500">Insurance ID:</span> <span className="ml-1 font-mono text-xs">{patient.insurance_id ?? "—"}</span></div>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold text-gray-900 mb-3">Allergies</h3>
            {(patient.allergies ?? []).length === 0 ? (
              <p className="text-sm text-gray-400">None documented</p>
            ) : (
              <div className="flex flex-wrap gap-1.5">
                {(patient.allergies ?? []).map((a: string) => (
                  <span key={a} className="text-xs bg-red-50 text-red-700 border border-red-200 px-2 py-0.5 rounded">{a}</span>
                ))}
              </div>
            )}
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-semibold text-gray-900">Quick Links</h3>
            </div>
            <div className="space-y-1">
              {[
                { label: "View Visits", href: `/visits?patient=${params.id}` },
                { label: "Documents / Faxes", href: `/ingestion?patient=${params.id}` },
                { label: "Outreach History", href: `/engagement?patient=${params.id}` },
              ].map((l) => (
                <Link key={l.href} href={l.href} className="flex items-center justify-between py-2 text-sm text-blue-600 hover:underline">
                  {l.label} <ChevronRight className="w-3.5 h-3.5" />
                </Link>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
