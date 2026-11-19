"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, oasisApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { ClipboardCheck, Calendar } from "lucide-react";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type OasisAssessment = {
  id: string;
  assessment_type: string;
  assessment_date: string;
  status: string;
  submitted_at?: string;
  iqies_submission_id?: string;
};

const STATUS_COLOR: Record<string, string> = {
  draft: "text-gray-600 bg-gray-50",
  complete: "text-blue-700 bg-blue-50",
  submitted: "text-green-700 bg-green-50",
  locked: "text-purple-700 bg-purple-50",
};

const TYPE_LABEL: Record<string, string> = {
  SOC: "Start of Care",
  ROC: "Resumption of Care",
  FU: "Follow-Up",
  REC: "Recertification",
  DC: "Discharge",
};

export default function OasisPage() {
  const [selectedPatient, setSelectedPatient] = useState("");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: oasisData } = useQuery({
    queryKey: ["oasis", selectedPatient],
    queryFn: () => oasisApi.list(selectedPatient),
    enabled: !!selectedPatient,
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const assessments: OasisAssessment[] = oasisData?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <ClipboardCheck className="w-6 h-6 text-blue-600" /> OASIS Assessments
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">OASIS-E outcomes and assessment data — required for Medicare billing</p>
      </div>

      <select
        value={selectedPatient}
        onChange={(e) => setSelectedPatient(e.target.value)}
        className="text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white w-72"
      >
        <option value="">Select a patient…</option>
        {patients.map((p) => (
          <option key={p.id} value={p.id}>{p.last_name}, {p.first_name} — {p.mrn}</option>
        ))}
      </select>

      {selectedPatient && (
        assessments.length === 0 ? (
          <div className="bg-white rounded-xl border border-gray-200 p-10 text-center">
            <ClipboardCheck className="w-8 h-8 text-gray-300 mx-auto mb-2" />
            <p className="text-gray-400">No OASIS assessments found</p>
            <p className="text-xs text-gray-300 mt-1">A SOC assessment should be created within 5 days of start of care</p>
          </div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
            {assessments.map((a) => (
              <div key={a.id} className="flex items-center gap-4 px-5 py-4">
                <div className="w-14 text-center">
                  <div className="text-sm font-bold text-gray-900">{a.assessment_type}</div>
                  <div className="text-xs text-gray-400">{TYPE_LABEL[a.assessment_type] ?? a.assessment_type}</div>
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <Calendar className="w-3.5 h-3.5 text-gray-400" />
                    <span className="text-sm text-gray-700">{a.assessment_date}</span>
                    <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium", STATUS_COLOR[a.status])}>
                      {a.status}
                    </span>
                  </div>
                  {a.iqies_submission_id && (
                    <p className="text-xs text-gray-400 mt-0.5">iQIES ID: {a.iqies_submission_id}</p>
                  )}
                  {a.submitted_at && (
                    <p className="text-xs text-gray-400 mt-0.5">Submitted {new Date(a.submitted_at).toLocaleDateString()}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <ClipboardCheck className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to view their OASIS assessments</p>
        </div>
      )}
    </div>
  );
}
