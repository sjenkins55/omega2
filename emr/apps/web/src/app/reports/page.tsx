"use client";
import { useQuery } from "@tanstack/react-query";
import { reportsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { FileBarChart2, Users, ClipboardList, Activity, TrendingUp, AlertTriangle } from "lucide-react";

type CensusData = {
  total_patients: number;
  by_status: Record<string, number>;
  by_insurance: Record<string, number>;
  by_provider: { provider_id: string; provider_name: string; patient_count: number }[];
  high_risk_count: number;
  avg_risk_score: number;
};

type HccEntry = {
  patient_id: string;
  patient_name: string;
  mrn: string;
  hcc_gaps: number;
  conditions: { icd10_code: string; hcc_code: string; hcc_description: string }[];
};

type RiskEntry = {
  patient_id: string;
  name: string;
  mrn: string;
  risk_score: number;
  primary_dx: string;
  active_conditions: number;
  critical_labs: number;
  risk_tier: string;
};

function StatCard({ label, value, icon: Icon, color }: { label: string; value: string | number; icon: React.ElementType; color: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
      <div className={cn("w-10 h-10 rounded-lg flex items-center justify-center", color)}>
        <Icon className="w-5 h-5" />
      </div>
      <div>
        <div className="text-2xl font-bold text-gray-900">{value}</div>
        <div className="text-sm text-gray-500">{label}</div>
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const { data: censusData } = useQuery({
    queryKey: ["reports", "census"],
    queryFn: () => reportsApi.census(),
  });
  const { data: hccData } = useQuery({
    queryKey: ["reports", "hcc"],
    queryFn: () => reportsApi.hccCapture({ year: new Date().getFullYear() }),
  });
  const { data: riskData } = useQuery({
    queryKey: ["reports", "risk"],
    queryFn: () => reportsApi.hospitalizationRisk({ limit: 10 }),
  });

  const census: CensusData | undefined = censusData?.data;
  const hccGaps: HccEntry[] = hccData?.data?.patients_with_gaps ?? [];
  const riskPatients: RiskEntry[] = riskData?.data?.patients ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Reports & Analytics</h1>
        <p className="text-sm text-gray-500 mt-0.5">Agency-level performance and compliance metrics</p>
      </div>

      {/* Census stats */}
      {census && (
        <div className="grid grid-cols-4 gap-4">
          <StatCard label="Total Patients" value={census.total_patients} icon={Users} color="text-blue-600 bg-blue-50" />
          <StatCard label="Active Episodes" value={census.by_status?.active ?? 0} icon={ClipboardList} color="text-green-600 bg-green-50" />
          <StatCard label="High Risk" value={census.high_risk_count} icon={AlertTriangle} color="text-orange-600 bg-orange-50" />
          <StatCard label="Avg Risk Score" value={(census.avg_risk_score * 100).toFixed(0) + "%"} icon={Activity} color="text-purple-600 bg-purple-50" />
        </div>
      )}

      <div className="grid grid-cols-2 gap-6">
        {/* HCC Gap Closure */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900">HCC Gap Closure ({new Date().getFullYear()})</h2>
            <p className="text-xs text-gray-500 mt-0.5">Patients with unrecaptured HCC conditions</p>
          </div>
          <div className="divide-y divide-gray-50">
            {hccGaps.length === 0 ? (
              <p className="px-5 py-6 text-sm text-gray-400">No HCC gaps found</p>
            ) : hccGaps.slice(0, 8).map((p) => (
              <div key={p.patient_id} className="px-5 py-3 flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium text-gray-900">{p.patient_name}</div>
                  <div className="text-xs text-gray-400">{p.mrn}</div>
                </div>
                <span className="text-xs font-semibold text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full">
                  {p.hcc_gaps} gap{p.hcc_gaps !== 1 ? "s" : ""}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Hospitalization Risk */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-red-500" /> Hospitalization Risk
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">Top patients by re-admission risk score</p>
          </div>
          <div className="divide-y divide-gray-50">
            {riskPatients.length === 0 ? (
              <p className="px-5 py-6 text-sm text-gray-400">No data</p>
            ) : riskPatients.map((p) => (
              <div key={p.patient_id} className="px-5 py-3 flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium text-gray-900">{p.name}</div>
                  <div className="text-xs text-gray-400">{p.primary_dx || "—"}</div>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-16 bg-gray-100 rounded-full h-1.5">
                    <div
                      className={cn("h-1.5 rounded-full", p.risk_score >= 0.8 ? "bg-red-500" : p.risk_score >= 0.6 ? "bg-orange-400" : "bg-yellow-400")}
                      style={{ width: `${p.risk_score * 100}%` }}
                    />
                  </div>
                  <span className="text-xs font-mono text-gray-600">{(p.risk_score * 100).toFixed(0)}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Census by status */}
      {census && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold text-gray-900 mb-4">Census by Status</h2>
          <div className="flex items-end gap-4 flex-wrap">
            {Object.entries(census.by_status ?? {}).map(([status, count]) => (
              <div key={status} className="flex items-center gap-2">
                <div className={cn(
                  "w-3 h-3 rounded-sm",
                  status === "active" ? "bg-green-500" : status === "discharged" ? "bg-gray-400" : "bg-blue-400"
                )} />
                <span className="text-sm text-gray-600 capitalize">{status}</span>
                <span className="text-sm font-bold text-gray-900">{String(count)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
