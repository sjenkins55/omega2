"use client";
import { useQuery } from "@tanstack/react-query";
import { reportsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Users, AlertTriangle, Activity, ClipboardList, Target, ArrowRight, TrendingUp } from "lucide-react";
import Link from "next/link";

type Census = {
  period_days: number;
  active_patients: number;
  high_risk: number;
  critical: number;
  new_admissions: number;
  discharges: number;
  risk_distribution: Record<string, number>;
};

type VisitUtilization = {
  period_days: number;
  total_visits: number;
  completed: number;
  missed: number;
  cancelled: number;
  completion_rate: number;
  by_visit_type: Record<string, number>;
};

type HccCapture = {
  year: number;
  total_hcc_conditions: number;
  recaptured_this_year: number;
  capture_rate: number;
  provisional_suspects: number;
  gap_count: number;
};

type RiskPatient = {
  id: string;
  name: string;
  mrn: string;
  risk_score: number;
  primary_dx: string | null;
  soc_date: string | null;
};

type StaffProductivity = {
  period_days: number;
  total_completed: number;
  by_clinician: Record<string, number>;
};

const RISK_COLORS: Record<string, string> = {
  low: "bg-green-500",
  moderate: "bg-yellow-400",
  high: "bg-orange-400",
  critical: "bg-red-500",
};

function StatCard({ label, value, sub, icon: Icon, color }: {
  label: string;
  value: string | number;
  sub?: string;
  icon: React.ElementType;
  color: string;
}) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
      <div className={cn("w-10 h-10 rounded-lg flex items-center justify-center shrink-0", color)}>
        <Icon className="w-5 h-5" />
      </div>
      <div className="min-w-0">
        <div className="text-2xl font-bold text-gray-900">{value}</div>
        <div className="text-sm text-gray-500 truncate">{label}</div>
        {sub && <div className="text-xs text-gray-400">{sub}</div>}
      </div>
    </div>
  );
}

export default function AnalyticsPage() {
  const { data: censusData } = useQuery({
    queryKey: ["analytics", "census"],
    queryFn: () => reportsApi.census(),
  });
  const { data: utilizationData } = useQuery({
    queryKey: ["analytics", "visit-utilization"],
    queryFn: () => reportsApi.visitUtilization(),
  });
  const { data: hccData } = useQuery({
    queryKey: ["analytics", "hcc-capture"],
    queryFn: () => reportsApi.hccCapture(),
  });
  const { data: riskData } = useQuery({
    queryKey: ["analytics", "hospitalization-risk"],
    queryFn: () => reportsApi.hospitalizationRisk({ limit: 8 }),
  });
  const { data: staffData } = useQuery({
    queryKey: ["analytics", "staff-productivity"],
    queryFn: () => reportsApi.staffProductivity(),
  });

  const census: Census | undefined = censusData?.data;
  const utilization: VisitUtilization | undefined = utilizationData?.data;
  const hcc: HccCapture | undefined = hccData?.data;
  const riskPatients: RiskPatient[] = riskData?.data?.patients ?? [];
  const staff: StaffProductivity | undefined = staffData?.data;

  const riskTotal = Object.values(census?.risk_distribution ?? {}).reduce((a, b) => a + b, 0);
  const clinicianRows = Object.entries(staff?.by_clinician ?? {}).sort((a, b) => b[1] - a[1]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Analytics</h1>
          <p className="text-sm text-gray-500 mt-0.5">At-a-glance operational and clinical metrics</p>
        </div>
        <Link
          href="/reports"
          className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-700"
        >
          Full reports <ArrowRight className="w-4 h-4" />
        </Link>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Active Patients"
          value={census?.active_patients ?? "—"}
          sub={census ? `${census.new_admissions} new / ${census.discharges} discharged (${census.period_days}d)` : undefined}
          icon={Users}
          color="text-blue-600 bg-blue-50"
        />
        <StatCard
          label="High Risk Patients"
          value={census?.high_risk ?? "—"}
          sub={census ? `${census.critical} critical` : undefined}
          icon={AlertTriangle}
          color="text-orange-600 bg-orange-50"
        />
        <StatCard
          label="Visit Completion"
          value={utilization ? `${Math.round(utilization.completion_rate * 100)}%` : "—"}
          sub={utilization ? `${utilization.completed} of ${utilization.total_visits} (${utilization.period_days}d)` : undefined}
          icon={ClipboardList}
          color="text-green-600 bg-green-50"
        />
        <StatCard
          label="HCC Capture Rate"
          value={hcc ? `${Math.round(hcc.capture_rate * 100)}%` : "—"}
          sub={hcc ? `${hcc.gap_count} open gaps (${hcc.year})` : undefined}
          icon={Target}
          color="text-purple-600 bg-purple-50"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Risk distribution */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <Activity className="w-4 h-4 text-purple-500" /> Risk Distribution
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">Active patients by AI risk tier</p>
          </div>
          <div className="p-5 space-y-3">
            {census ? (
              Object.entries(census.risk_distribution).map(([tier, count]) => (
                <div key={tier} className="flex items-center gap-3">
                  <span className="w-20 text-sm text-gray-600 capitalize">{tier}</span>
                  <div className="flex-1 bg-gray-100 rounded-full h-2">
                    <div
                      className={cn("h-2 rounded-full", RISK_COLORS[tier] ?? "bg-gray-400")}
                      style={{ width: riskTotal ? `${(count / riskTotal) * 100}%` : "0%" }}
                    />
                  </div>
                  <span className="w-8 text-right text-sm font-bold text-gray-900">{count}</span>
                </div>
              ))
            ) : (
              <p className="text-sm text-gray-400">Loading...</p>
            )}
          </div>
        </div>

        {/* Visits by type */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <ClipboardList className="w-4 h-4 text-green-500" /> Visits by Discipline
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">
              Last {utilization?.period_days ?? 30} days — {utilization?.missed ?? 0} missed, {utilization?.cancelled ?? 0} cancelled
            </p>
          </div>
          <div className="divide-y divide-gray-50">
            {utilization && Object.keys(utilization.by_visit_type).length > 0 ? (
              Object.entries(utilization.by_visit_type)
                .sort((a, b) => b[1] - a[1])
                .map(([type, count]) => (
                  <div key={type} className="px-5 py-3 flex items-center justify-between">
                    <span className="text-sm text-gray-700 capitalize">{type.replace(/_/g, " ")}</span>
                    <span className="text-sm font-bold text-gray-900">{count}</span>
                  </div>
                ))
            ) : (
              <p className="px-5 py-6 text-sm text-gray-400">No visit data</p>
            )}
          </div>
        </div>

        {/* Hospitalization risk */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-red-500" /> Hospitalization Risk
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">Highest-risk active patients</p>
          </div>
          <div className="divide-y divide-gray-50">
            {riskPatients.length === 0 ? (
              <p className="px-5 py-6 text-sm text-gray-400">No patients above threshold</p>
            ) : riskPatients.slice(0, 8).map((p) => (
              <Link
                key={p.id}
                href={`/patients/${p.id}`}
                className="px-5 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors"
              >
                <div className="min-w-0">
                  <div className="text-sm font-medium text-gray-900">{p.name}</div>
                  <div className="text-xs text-gray-400 truncate">{p.primary_dx || p.mrn}</div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <div className="w-16 bg-gray-100 rounded-full h-1.5">
                    <div
                      className={cn(
                        "h-1.5 rounded-full",
                        p.risk_score >= 0.9 ? "bg-red-500" : p.risk_score >= 0.8 ? "bg-orange-400" : "bg-yellow-400"
                      )}
                      style={{ width: `${p.risk_score * 100}%` }}
                    />
                  </div>
                  <span className="text-xs font-mono text-gray-600">{Math.round(p.risk_score * 100)}%</span>
                </div>
              </Link>
            ))}
          </div>
        </div>

        {/* Staff productivity */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <Users className="w-4 h-4 text-blue-500" /> Staff Productivity
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">
              {staff?.total_completed ?? 0} completed visits in the last {staff?.period_days ?? 30} days
            </p>
          </div>
          <div className="divide-y divide-gray-50">
            {clinicianRows.length === 0 ? (
              <p className="px-5 py-6 text-sm text-gray-400">No completed visits in period</p>
            ) : clinicianRows.map(([clinicianId, count]) => (
              <div key={clinicianId} className="px-5 py-3 flex items-center justify-between">
                <span className="text-sm text-gray-700 font-mono">
                  {clinicianId === "unassigned" ? "Unassigned" : clinicianId.slice(0, 8)}
                </span>
                <span className="text-sm font-bold text-gray-900">{count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
