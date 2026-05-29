"use client";
import { useEffect, useState } from "react";
import { portalApi } from "@/lib/api";
import { AlertTriangle, Pill, Stethoscope, Users, Shield } from "lucide-react";

type Records = {
  diagnoses: { description: string; type: string }[];
  medications: { name: string; dose?: string; frequency?: string; route?: string }[];
  allergies: (string | { name?: string; reaction?: string })[];
  care_team: { name: string; role: string; phone?: string }[];
  insurance: { type: string | null; id: string | null };
};

function Section({ icon: Icon, title, color, children }: {
  icon: React.ElementType; title: string; color: string; children: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
      <div className={`flex items-center gap-3 px-5 py-4 border-b border-slate-100 ${color}`}>
        <Icon className="w-5 h-5" />
        <h2 className="font-semibold text-sm">{title}</h2>
      </div>
      <div className="p-5">{children}</div>
    </div>
  );
}

export default function PortalRecords() {
  const [records, setRecords] = useState<Records | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    portalApi.get("/portal/records")
      .then(r => setRecords(r.data))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-slate-400 text-sm">Loading records…</div>
    </div>
  );
  if (!records) return null;

  return (
    <div className="max-w-lg mx-auto px-4 py-6 space-y-4">
      <h1 className="text-2xl font-bold text-slate-900">My Health Records</h1>

      {/* Diagnoses */}
      <Section icon={Stethoscope} title={`Diagnoses (${records.diagnoses.length})`} color="text-blue-700 bg-blue-50">
        {records.diagnoses.length === 0 ? (
          <p className="text-sm text-slate-400">No diagnoses on file</p>
        ) : (
          <div className="space-y-2">
            {records.diagnoses.map((dx, i) => (
              <div key={i} className="flex items-start gap-2">
                <div className={`w-2 h-2 rounded-full shrink-0 mt-1.5 ${dx.type === "primary" ? "bg-blue-500" : "bg-slate-300"}`} />
                <div>
                  <span className="text-sm text-slate-800">{dx.description}</span>
                  {dx.type === "primary" && (
                    <span className="ml-2 text-xs text-blue-500 font-medium">Primary</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </Section>

      {/* Medications */}
      <Section icon={Pill} title={`Medications (${records.medications.length})`} color="text-violet-700 bg-violet-50">
        {records.medications.length === 0 ? (
          <p className="text-sm text-slate-400">No medications on file</p>
        ) : (
          <div className="space-y-3">
            {records.medications.map((med, i) => (
              <div key={i} className="flex items-start justify-between">
                <div>
                  <div className="text-sm font-semibold text-slate-900 capitalize">{med.name}</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    {[med.dose, med.frequency, med.route].filter(Boolean).join(" · ")}
                  </div>
                </div>
                <span className="text-xs bg-violet-100 text-violet-700 px-2 py-0.5 rounded-full font-medium">Active</span>
              </div>
            ))}
          </div>
        )}
      </Section>

      {/* Allergies */}
      <Section icon={AlertTriangle} title={`Allergies (${records.allergies.length})`} color="text-red-700 bg-red-50">
        {records.allergies.length === 0 ? (
          <p className="text-sm text-slate-400">No known allergies on file</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {records.allergies.map((a, i) => {
              const label = typeof a === "string" ? a : (a.name ?? "Unknown");
              const reaction = typeof a === "object" ? a.reaction : undefined;
              return (
                <div key={i} className="bg-red-50 border border-red-100 rounded-xl px-3 py-1.5">
                  <span className="text-sm text-red-800 font-medium">{label}</span>
                  {reaction && <span className="text-xs text-red-500 ml-1">({reaction})</span>}
                </div>
              );
            })}
          </div>
        )}
      </Section>

      {/* Care team */}
      <Section icon={Users} title="Your Care Team" color="text-emerald-700 bg-emerald-50">
        {records.care_team.length === 0 ? (
          <p className="text-sm text-slate-400">Care team not yet assigned</p>
        ) : (
          <div className="space-y-3">
            {records.care_team.map((member, i) => (
              <div key={i} className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-700 font-semibold text-sm shrink-0">
                  {member.name.split(" ").map(n => n[0]).join("").slice(0, 2)}
                </div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-slate-900">{member.name}</div>
                  <div className="text-xs text-slate-500 capitalize">{member.role?.replace("_", " ")}</div>
                </div>
                {member.phone && (
                  <a href={`tel:${member.phone}`} className="text-sm text-blue-600 font-medium hover:underline">
                    Call
                  </a>
                )}
              </div>
            ))}
          </div>
        )}
      </Section>

      {/* Insurance */}
      {(records.insurance.type || records.insurance.id) && (
        <Section icon={Shield} title="Insurance" color="text-slate-700 bg-slate-50">
          <div className="space-y-1">
            {records.insurance.type && (
              <div className="flex justify-between text-sm">
                <span className="text-slate-500">Plan type</span>
                <span className="font-medium text-slate-900 capitalize">{records.insurance.type.replace("_", " ")}</span>
              </div>
            )}
            {records.insurance.id && (
              <div className="flex justify-between text-sm">
                <span className="text-slate-500">Member ID</span>
                <span className="font-mono font-medium text-slate-900">{records.insurance.id}</span>
              </div>
            )}
          </div>
        </Section>
      )}
    </div>
  );
}
