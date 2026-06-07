"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, carePlansApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { BookOpen, Target, CheckCircle } from "lucide-react";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type GoalItem = { goal: string; target_date?: string; status?: string };

type CarePlan = {
  id: string;
  status: string;
  effective_date?: string;
  long_term_goals: GoalItem[];
  short_term_goals: GoalItem[];
  functional_limitations?: string;
  safety_measures?: string;
};

const STATUS_COLOR: Record<string, string> = {
  active: "text-green-700 bg-green-50",
  draft: "text-gray-600 bg-gray-50",
  superseded: "text-blue-600 bg-blue-50",
  completed: "text-purple-700 bg-purple-50",
};

const GOAL_STATUS_COLOR: Record<string, string> = {
  not_started: "text-gray-400",
  in_progress: "text-blue-600",
  achieved: "text-green-600",
  discontinued: "text-red-400",
};

export default function CarePlansPage() {
  const [selectedPatient, setSelectedPatient] = useState("");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: plansData } = useQuery({
    queryKey: ["care-plans", selectedPatient],
    queryFn: () => carePlansApi.list(selectedPatient),
    enabled: !!selectedPatient,
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const plans: CarePlan[] = plansData?.data ?? [];
  const activePlan = plans.find((p) => p.status === "active") ?? plans[0];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <BookOpen className="w-6 h-6 text-blue-600" /> Care Plans
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">Patient goals and care coordination plans</p>
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

      {selectedPatient && !activePlan && (
        <div className="bg-white rounded-xl border border-gray-200 p-10 text-center">
          <BookOpen className="w-8 h-8 text-gray-300 mx-auto mb-2" />
          <p className="text-gray-400">No care plan found</p>
        </div>
      )}

      {activePlan && (
        <div className="space-y-4">
          {/* Plan header */}
          <div className="bg-white rounded-xl border border-gray-200 px-5 py-4 flex items-center justify-between">
            <div>
              <span className={cn("text-xs font-semibold px-2 py-0.5 rounded-full", STATUS_COLOR[activePlan.status])}>
                {activePlan.status}
              </span>
              {activePlan.effective_date && (
                <span className="text-sm text-gray-500 ml-3">Effective {activePlan.effective_date}</span>
              )}
            </div>
            {plans.length > 1 && (
              <span className="text-xs text-gray-400">{plans.length} plans total</span>
            )}
          </div>

          {/* Long-term goals */}
          {activePlan.long_term_goals?.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-200">
              <div className="px-5 py-3 border-b border-gray-100">
                <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                  <Target className="w-4 h-4 text-blue-500" /> Long-Term Goals
                </h3>
              </div>
              <div className="divide-y divide-gray-50">
                {activePlan.long_term_goals.map((g, i) => (
                  <div key={i} className="px-5 py-3 flex items-start gap-3">
                    <CheckCircle className={cn("w-4 h-4 mt-0.5 shrink-0", GOAL_STATUS_COLOR[g.status ?? "not_started"])} />
                    <div>
                      <p className="text-sm text-gray-800">{g.goal}</p>
                      {g.target_date && <p className="text-xs text-gray-400 mt-0.5">Target: {g.target_date}</p>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Short-term goals */}
          {activePlan.short_term_goals?.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-200">
              <div className="px-5 py-3 border-b border-gray-100">
                <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                  <Target className="w-4 h-4 text-green-500" /> Short-Term Goals
                </h3>
              </div>
              <div className="divide-y divide-gray-50">
                {activePlan.short_term_goals.map((g, i) => (
                  <div key={i} className="px-5 py-3 flex items-start gap-3">
                    <CheckCircle className={cn("w-4 h-4 mt-0.5 shrink-0", GOAL_STATUS_COLOR[g.status ?? "not_started"])} />
                    <div>
                      <p className="text-sm text-gray-800">{g.goal}</p>
                      {g.target_date && <p className="text-xs text-gray-400 mt-0.5">Target: {g.target_date}</p>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Safety & Limitations */}
          {(activePlan.functional_limitations || activePlan.safety_measures) && (
            <div className="grid grid-cols-2 gap-4">
              {activePlan.functional_limitations && (
                <div className="bg-white rounded-xl border border-gray-200 p-4">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase mb-2">Functional Limitations</h4>
                  <p className="text-sm text-gray-700">{activePlan.functional_limitations}</p>
                </div>
              )}
              {activePlan.safety_measures && (
                <div className="bg-white rounded-xl border border-gray-200 p-4">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase mb-2">Safety Measures</h4>
                  <p className="text-sm text-gray-700">{activePlan.safety_measures}</p>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <BookOpen className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to view their care plan</p>
        </div>
      )}
    </div>
  );
}
