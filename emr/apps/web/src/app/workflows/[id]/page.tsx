"use client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { workflowsApi } from "@/lib/api";
import { cn, formatDateTime } from "@/lib/utils";
import { Play, Pause, ArrowRight } from "lucide-react";
import Link from "next/link";
import { useParams } from "next/navigation";

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

export default function WorkflowDetailPage() {
  const params = useParams();
  const id = params.id as string;
  const qc = useQueryClient();

  const { data, isLoading, isError } = useQuery({
    queryKey: ["workflow", id],
    queryFn: () => workflowsApi.get(id),
  });

  const activateMutation = useMutation({
    mutationFn: () => workflowsApi.activate(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["workflow", id] });
      qc.invalidateQueries({ queryKey: ["workflows"] });
    },
  });

  if (isLoading) {
    return (
      <div className="py-16 text-center text-sm text-gray-400">Loading workflow…</div>
    );
  }

  if (isError || !data?.data) {
    return (
      <div className="space-y-4">
        <Link href="/workflows" className="text-sm text-blue-600 hover:underline">
          ← Workflows
        </Link>
        <div className="py-16 text-center text-gray-500 font-medium">Workflow not found</div>
      </div>
    );
  }

  const wf = data.data;
  const steps: Array<{ id: string; type: string; config: Record<string, unknown>; next_steps: string[]; is_root: boolean }> =
    wf.steps ?? [];

  return (
    <div className="space-y-6 max-w-3xl">
      {/* Back link */}
      <Link href="/workflows" className="text-sm text-blue-600 hover:underline inline-flex items-center gap-1">
        ← Workflows
      </Link>

      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 flex-wrap">
            <h1 className="text-2xl font-semibold text-gray-900">{wf.name}</h1>
            <span
              className={cn(
                "text-xs font-medium px-2.5 py-0.5 rounded-full",
                wf.status === "active"
                  ? "bg-green-50 text-green-700"
                  : wf.status === "draft"
                  ? "bg-gray-100 text-gray-600"
                  : "bg-yellow-50 text-yellow-700"
              )}
            >
              {wf.status}
            </span>
          </div>
          {wf.description && (
            <p className="mt-1.5 text-sm text-gray-500">{wf.description}</p>
          )}
        </div>

        {/* Activate / Pause */}
        <div className="shrink-0">
          {wf.status !== "active" ? (
            <button
              onClick={() => activateMutation.mutate()}
              disabled={activateMutation.isPending}
              className="flex items-center gap-1.5 text-sm text-green-600 hover:text-green-700 px-3 py-1.5 border border-green-200 rounded-lg hover:bg-green-50 disabled:opacity-50"
            >
              <Play className="w-3.5 h-3.5" /> Activate
            </button>
          ) : (
            <button className="flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-700 px-3 py-1.5 border border-gray-200 rounded-lg hover:bg-gray-50">
              <Pause className="w-3.5 h-3.5" /> Pause
            </button>
          )}
        </div>
      </div>

      {/* Meta */}
      <div className="bg-white rounded-xl border border-gray-200 p-5 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div>
          <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Trigger</div>
          <div className="text-sm font-medium text-gray-900">
            {TRIGGER_LABELS[wf.trigger_type] ?? wf.trigger_type}
          </div>
        </div>
        <div>
          <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Steps</div>
          <div className="text-sm font-medium text-gray-900">{steps.length}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Total Runs</div>
          <div className="text-sm font-medium text-gray-900">{wf.run_count ?? 0}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500 uppercase tracking-wide mb-1">Last Run</div>
          <div className="text-sm font-medium text-gray-900">
            {wf.last_run_at ? formatDateTime(wf.last_run_at) : "Never"}
          </div>
        </div>
      </div>

      {/* Steps flow */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="font-semibold text-gray-900 mb-4">Steps</h2>
        {steps.length === 0 ? (
          <p className="text-sm text-gray-400">No steps defined.</p>
        ) : (
          <ol className="space-y-0">
            {steps.map((step, idx) => (
              <li key={step.id} className="flex gap-4">
                {/* Connector column */}
                <div className="flex flex-col items-center shrink-0">
                  <div
                    className={cn(
                      "w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold shrink-0",
                      step.is_root
                        ? "bg-blue-600 text-white"
                        : "bg-gray-100 text-gray-600"
                    )}
                  >
                    {idx + 1}
                  </div>
                  {idx < steps.length - 1 && (
                    <div className="w-px flex-1 bg-gray-200 my-1" style={{ minHeight: "24px" }} />
                  )}
                </div>

                {/* Step card */}
                <div className={cn("flex-1 mb-3 pb-3", idx < steps.length - 1 && "border-b border-gray-50")}>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-medium text-gray-900 capitalize">
                      {step.type.replace(/_/g, " ")}
                    </span>
                    {step.is_root && (
                      <span className="text-xs bg-blue-50 text-blue-700 px-1.5 py-0.5 rounded">
                        root
                      </span>
                    )}
                  </div>

                  {/* Config key/value pairs */}
                  {step.config && Object.keys(step.config).length > 0 && (
                    <dl className="mt-1.5 grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-sm">
                      {Object.entries(step.config).map(([k, v]) => (
                        <>
                          <dt key={`k-${k}`} className="text-gray-400 font-medium truncate">{k}</dt>
                          <dd key={`v-${k}`} className="text-gray-700 break-all">
                            {typeof v === "object" ? JSON.stringify(v) : String(v ?? "")}
                          </dd>
                        </>
                      ))}
                    </dl>
                  )}

                  {/* Next steps */}
                  {step.next_steps && step.next_steps.length > 0 && (
                    <div className="mt-2 flex items-center gap-1.5 text-xs text-gray-400">
                      <ArrowRight className="w-3 h-3" />
                      <span>Connects to: {step.next_steps.join(", ")}</span>
                    </div>
                  )}
                </div>
              </li>
            ))}
          </ol>
        )}
      </div>
    </div>
  );
}
