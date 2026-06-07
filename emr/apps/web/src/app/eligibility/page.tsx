"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { patientsApi, eligibilityApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { BadgeCheck, CheckCircle, XCircle, RefreshCw } from "lucide-react";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type EligibilityCheck = {
  id: string;
  payer_name?: string;
  insurance_type?: string;
  coverage_active?: boolean;
  coverage_dates?: { start?: string; end?: string };
  benefits?: Record<string, unknown>;
  notes?: string;
  checked_at: string;
};

export default function EligibilityPage() {
  const qc = useQueryClient();
  const [selectedPatient, setSelectedPatient] = useState("");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: eligData, isLoading } = useQuery({
    queryKey: ["eligibility", selectedPatient],
    queryFn: () => eligibilityApi.list(selectedPatient),
    enabled: !!selectedPatient,
  });

  const checkMutation = useMutation({
    mutationFn: () => eligibilityApi.check(selectedPatient, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["eligibility", selectedPatient] }),
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const checks: EligibilityCheck[] = eligData?.data ?? [];
  const latest = checks[0];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <BadgeCheck className="w-6 h-6 text-blue-600" /> Insurance Eligibility
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">270/271 EDI eligibility verification</p>
      </div>

      <div className="flex items-center gap-3">
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
          <button
            onClick={() => checkMutation.mutate()}
            disabled={checkMutation.isPending}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            <RefreshCw className={cn("w-4 h-4", checkMutation.isPending && "animate-spin")} />
            Run Check
          </button>
        )}
      </div>

      {selectedPatient && (
        isLoading ? (
          <div className="text-sm text-gray-400">Loading…</div>
        ) : (
          <div className="space-y-4">
            {/* Latest result */}
            {latest && (
              <div className={cn(
                "rounded-xl border p-5",
                latest.coverage_active ? "border-green-200 bg-green-50" : "border-red-200 bg-red-50"
              )}>
                <div className="flex items-center gap-3">
                  {latest.coverage_active
                    ? <CheckCircle className="w-6 h-6 text-green-600" />
                    : <XCircle className="w-6 h-6 text-red-500" />}
                  <div>
                    <p className="font-semibold text-gray-900">
                      {latest.coverage_active ? "Coverage Active" : "Coverage Inactive"}
                    </p>
                    <p className="text-sm text-gray-600">{latest.payer_name} · {latest.insurance_type}</p>
                  </div>
                  <span className="ml-auto text-xs text-gray-500">
                    Checked {new Date(latest.checked_at).toLocaleString()}
                  </span>
                </div>
                {latest.coverage_dates && (
                  <p className="text-sm text-gray-600 mt-3">
                    Coverage period: <span className="font-medium">{latest.coverage_dates.start}</span>
                    {latest.coverage_dates.end ? ` → ${latest.coverage_dates.end}` : ""}
                  </p>
                )}
                {latest.benefits && (
                  <div className="mt-3 grid grid-cols-2 gap-2">
                    {Object.entries(latest.benefits).filter(([, v]) => v !== null).map(([k, v]) => (
                      <div key={k} className="text-xs">
                        <span className="text-gray-500 capitalize">{k.replace(/_/g, " ")}: </span>
                        <span className="text-gray-900 font-medium">{String(v)}</span>
                      </div>
                    ))}
                  </div>
                )}
                {latest.notes && (
                  <p className="text-xs text-gray-500 mt-3 italic">{latest.notes}</p>
                )}
              </div>
            )}

            {/* History */}
            {checks.length > 1 && (
              <div className="bg-white rounded-xl border border-gray-200">
                <div className="px-5 py-3 border-b border-gray-100">
                  <h3 className="text-sm font-semibold text-gray-900">Check History</h3>
                </div>
                <div className="divide-y divide-gray-50">
                  {checks.slice(1).map((c) => (
                    <div key={c.id} className="flex items-center gap-3 px-5 py-3">
                      {c.coverage_active
                        ? <CheckCircle className="w-4 h-4 text-green-500" />
                        : <XCircle className="w-4 h-4 text-red-400" />}
                      <span className="text-sm text-gray-700">{c.payer_name}</span>
                      <span className="ml-auto text-xs text-gray-400">
                        {new Date(c.checked_at).toLocaleDateString()}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {checks.length === 0 && (
              <div className="bg-white rounded-xl border border-gray-200 p-10 text-center">
                <BadgeCheck className="w-8 h-8 text-gray-300 mx-auto mb-2" />
                <p className="text-gray-400">No eligibility checks yet</p>
                <p className="text-xs text-gray-300 mt-1">Click "Run Check" to verify coverage</p>
              </div>
            )}
          </div>
        )
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <BadgeCheck className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to check their insurance eligibility</p>
        </div>
      )}
    </div>
  );
}
