"use client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { workflowsApi } from "@/lib/api";
import { Workflow } from "@/types";
import { cn, formatDateTime } from "@/lib/utils";
import { Plus, Zap, Play, Pause, ChevronRight } from "lucide-react";
import Link from "next/link";

const TRIGGER_LABELS: Record<string, string> = {
  visit_completed: "Visit Completed",
  document_received: "Document Received",
  lab_result_received: "Lab Result Received",
  patient_admitted: "Patient Admitted",
  patient_discharged: "Patient Discharged",
  risk_score_changed: "Risk Score Changed",
  scheduled: "Scheduled",
  manual: "Manual",
  ai_flag: "AI Flag",
};

export default function WorkflowsPage() {
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["workflows"],
    queryFn: () => workflowsApi.list(),
  });

  const activateMutation = useMutation({
    mutationFn: (id: string) => workflowsApi.activate(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["workflows"] }),
  });

  const workflows: Workflow[] = data?.data ?? [];

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Workflows</h1>
          <p className="text-sm text-gray-500">Automated care workflows — no manual clicking required</p>
        </div>
        <Link href="/workflows/new" className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
          <Plus className="w-4 h-4" /> New Workflow
        </Link>
      </div>

      {/* System workflows callout */}
      <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 flex items-start gap-3">
        <Zap className="w-5 h-5 text-blue-600 shrink-0 mt-0.5" />
        <div>
          <div className="font-medium text-blue-900">Workflow Automation</div>
          <p className="text-sm text-blue-700 mt-0.5">
            Build trigger-based workflows that fire automatically — no clicking needed. Workflows can send notifications,
            create tasks, schedule visits, update care plans, and trigger AI analysis.
          </p>
        </div>
      </div>

      <div className="grid gap-3">
        {workflows.map((wf) => (
          <div key={wf.id} className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
            <div className={cn(
              "w-10 h-10 rounded-lg flex items-center justify-center shrink-0",
              wf.status === "active" ? "bg-green-100" : "bg-gray-100"
            )}>
              <Zap className={cn("w-5 h-5", wf.status === "active" ? "text-green-600" : "text-gray-400")} />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-medium text-gray-900">{wf.name}</span>
                <span className={cn(
                  "text-xs font-medium px-2 py-0.5 rounded-full",
                  wf.status === "active" ? "bg-green-50 text-green-700" :
                  wf.status === "draft" ? "bg-gray-100 text-gray-600" :
                  "bg-yellow-50 text-yellow-700"
                )}>
                  {wf.status}
                </span>
              </div>
              <div className="text-sm text-gray-500 mt-0.5">
                Trigger: {TRIGGER_LABELS[wf.trigger_type] ?? wf.trigger_type} ·{" "}
                {wf.steps.length} step{wf.steps.length !== 1 ? "s" : ""} ·{" "}
                {wf.run_count} run{wf.run_count !== 1 ? "s" : ""}
                {wf.last_run_at && <> · Last: {formatDateTime(wf.last_run_at)}</>}
              </div>
            </div>
            <div className="flex items-center gap-2">
              {wf.status !== "active" && (
                <button
                  onClick={() => activateMutation.mutate(wf.id)}
                  className="flex items-center gap-1.5 text-sm text-green-600 hover:text-green-700 px-3 py-1.5 border border-green-200 rounded-lg hover:bg-green-50"
                >
                  <Play className="w-3.5 h-3.5" /> Activate
                </button>
              )}
              {wf.status === "active" && (
                <button className="flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-700 px-3 py-1.5 border border-gray-200 rounded-lg hover:bg-gray-50">
                  <Pause className="w-3.5 h-3.5" /> Pause
                </button>
              )}
              <Link href={`/workflows/${wf.id}`} className="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg hover:bg-gray-100">
                <ChevronRight className="w-4 h-4" />
              </Link>
            </div>
          </div>
        ))}

        {workflows.length === 0 && (
          <div className="bg-white rounded-xl border border-dashed border-gray-300 p-12 text-center">
            <Zap className="w-10 h-10 text-gray-300 mx-auto mb-3" />
            <p className="font-medium text-gray-500">No workflows yet</p>
            <p className="text-sm text-gray-400 mt-1">Create your first workflow to automate care processes</p>
            <Link href="/workflows/new" className="inline-flex items-center gap-2 mt-4 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
              <Plus className="w-4 h-4" /> Build a Workflow
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
