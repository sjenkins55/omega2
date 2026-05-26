"use client";
import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { workflowsApi } from "@/lib/api";
import { WorkflowStep } from "@/types";
import { cn } from "@/lib/utils";
import { Plus, Trash2, ArrowDown, Zap, Save } from "lucide-react";
import { useRouter } from "next/navigation";

const TRIGGERS = [
  { value: "visit_completed", label: "Visit Completed" },
  { value: "document_received", label: "Document Received" },
  { value: "lab_result_received", label: "Lab Result Received" },
  { value: "patient_discharged", label: "Patient Discharged" },
  { value: "risk_score_changed", label: "Risk Score Changed" },
  { value: "scheduled", label: "Scheduled (Cron)" },
  { value: "manual", label: "Manual Trigger" },
  { value: "ai_flag", label: "AI Flag" },
];

const STEP_COLORS: Record<string, string> = {
  send_notification: "border-blue-200 bg-blue-50",
  create_task: "border-purple-200 bg-purple-50",
  schedule_visit: "border-green-200 bg-green-50",
  update_care_plan: "border-teal-200 bg-teal-50",
  ai_analysis: "border-indigo-200 bg-indigo-50",
  condition_branch: "border-orange-200 bg-orange-50",
  wait: "border-gray-200 bg-gray-50",
};

export default function NewWorkflowPage() {
  const router = useRouter();
  const qc = useQueryClient();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [triggerType, setTriggerType] = useState("visit_completed");
  const [steps, setSteps] = useState<WorkflowStep[]>([]);

  const { data: catalogData } = useQuery({
    queryKey: ["step-catalog"],
    queryFn: () => workflowsApi.stepCatalog(),
  });

  const catalog = catalogData?.data?.step_types ?? [];

  const createMutation = useMutation({
    mutationFn: () => workflowsApi.create({
      name,
      description,
      trigger_type: triggerType,
      steps: steps.map((s, i) => ({
        ...s,
        is_root: i === 0,
        next_steps: i < steps.length - 1 ? [steps[i + 1].id] : [],
      })),
    }),
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["workflows"] });
      router.push(`/workflows/${data.data.id}`);
    },
  });

  const addStep = (type: string, label: string) => {
    const newStep: WorkflowStep = {
      id: `step-${Date.now()}`,
      type,
      label,
      config: {},
      next_steps: [],
      is_root: steps.length === 0,
    };
    setSteps((prev) => [...prev, newStep]);
  };

  const removeStep = (id: string) => {
    setSteps((prev) => prev.filter((s) => s.id !== id));
  };

  const updateStepConfig = (id: string, key: string, value: string) => {
    setSteps((prev) => prev.map((s) => s.id === id ? { ...s, config: { ...s.config, [key]: value } } : s));
  };

  return (
    <div className="max-w-3xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">New Workflow</h1>
        <p className="text-sm text-gray-500">Build an automated care workflow triggered by EMR events</p>
      </div>

      {/* Basic info */}
      <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Workflow Name</label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Post-Discharge Follow-up"
            className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What does this workflow do?"
            className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Trigger</label>
          <select
            value={triggerType}
            onChange={(e) => setTriggerType(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {TRIGGERS.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
        </div>
      </div>

      {/* Step builder */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="font-semibold text-gray-900 mb-4">Steps</h2>

        {/* Step list */}
        <div className="space-y-2 mb-4">
          {steps.map((step, i) => (
            <div key={step.id}>
              <div className={cn("border rounded-lg p-4", STEP_COLORS[step.type] ?? "border-gray-200 bg-gray-50")}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-semibold text-gray-800">{step.label ?? step.type}</span>
                  <button onClick={() => removeStep(step.id)} className="text-gray-400 hover:text-red-500">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                {/* Config fields */}
                {step.type === "send_notification" && (
                  <div className="grid grid-cols-2 gap-2">
                    <select
                      value={(step.config.channel as string) || "sms"}
                      onChange={(e) => updateStepConfig(step.id, "channel", e.target.value)}
                      className="text-xs border border-gray-200 rounded px-2 py-1"
                    >
                      <option value="sms">SMS</option>
                      <option value="email">Email</option>
                      <option value="push">Push</option>
                    </select>
                    <input
                      placeholder="Message template"
                      value={(step.config.template as string) || ""}
                      onChange={(e) => updateStepConfig(step.id, "template", e.target.value)}
                      className="text-xs border border-gray-200 rounded px-2 py-1"
                    />
                  </div>
                )}
                {step.type === "create_task" && (
                  <div className="space-y-1.5">
                    <input
                      placeholder="Task title"
                      value={(step.config.title as string) || ""}
                      onChange={(e) => updateStepConfig(step.id, "title", e.target.value)}
                      className="w-full text-xs border border-gray-200 rounded px-2 py-1"
                    />
                    <input
                      placeholder="Due in hours"
                      type="number"
                      value={(step.config.due_in_hours as string) || "24"}
                      onChange={(e) => updateStepConfig(step.id, "due_in_hours", e.target.value)}
                      className="w-full text-xs border border-gray-200 rounded px-2 py-1"
                    />
                  </div>
                )}
                {step.type === "wait" && (
                  <input
                    placeholder="Hours to wait"
                    type="number"
                    value={(step.config.hours as string) || "24"}
                    onChange={(e) => updateStepConfig(step.id, "hours", e.target.value)}
                    className="text-xs border border-gray-200 rounded px-2 py-1"
                  />
                )}
                {step.type === "schedule_visit" && (
                  <select
                    value={(step.config.visit_type as string) || "skilled_nursing"}
                    onChange={(e) => updateStepConfig(step.id, "visit_type", e.target.value)}
                    className="text-xs border border-gray-200 rounded px-2 py-1"
                  >
                    {["skilled_nursing", "physical_therapy", "occupational_therapy", "social_work"].map((vt) => (
                      <option key={vt} value={vt}>{vt.replace(/_/g, " ")}</option>
                    ))}
                  </select>
                )}
              </div>
              {i < steps.length - 1 && (
                <div className="flex justify-center py-1">
                  <ArrowDown className="w-4 h-4 text-gray-300" />
                </div>
              )}
            </div>
          ))}
          {steps.length === 0 && (
            <div className="py-6 text-center text-sm text-gray-400 border border-dashed border-gray-200 rounded-lg">
              Add steps below to build your workflow
            </div>
          )}
        </div>

        {/* Add step palette */}
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Add Step</div>
          <div className="flex flex-wrap gap-2">
            {catalog.map((st: { type: string; label: string; category: string }) => (
              <button
                key={st.type}
                onClick={() => addStep(st.type, st.label)}
                className="flex items-center gap-1.5 px-3 py-1.5 border border-gray-200 rounded-lg text-xs text-gray-700 hover:bg-gray-50 hover:border-blue-300 transition-colors"
              >
                <Plus className="w-3 h-3" /> {st.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="flex gap-3">
        <button
          onClick={() => createMutation.mutate()}
          disabled={!name || steps.length === 0 || createMutation.isPending}
          className="flex items-center gap-2 bg-blue-600 text-white px-5 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50"
        >
          <Save className="w-4 h-4" />
          {createMutation.isPending ? "Saving..." : "Save Workflow"}
        </button>
        <button onClick={() => router.back()} className="px-4 py-2 text-sm text-gray-600 hover:text-gray-900">
          Cancel
        </button>
      </div>
    </div>
  );
}
