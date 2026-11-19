"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { tasksApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { CheckSquare, Check, Clock, AlertTriangle, ChevronDown } from "lucide-react";

const PRIORITY_COLOR: Record<string, string> = {
  urgent: "text-red-600 bg-red-50 border-red-200",
  high: "text-orange-600 bg-orange-50 border-orange-200",
  normal: "text-blue-600 bg-blue-50 border-blue-200",
  low: "text-gray-600 bg-gray-50 border-gray-200",
};

const STATUS_COLOR: Record<string, string> = {
  open: "text-yellow-700 bg-yellow-50",
  in_progress: "text-blue-700 bg-blue-50",
  completed: "text-green-700 bg-green-50",
  cancelled: "text-gray-500 bg-gray-50",
};

type Task = {
  id: string;
  title: string;
  description?: string;
  priority: string;
  status: string;
  category: string;
  due_at?: string;
  patient_id?: string;
};

export default function TasksPage() {
  const qc = useQueryClient();
  const [statusFilter, setStatusFilter] = useState("open");
  const [priorityFilter, setPriorityFilter] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["tasks", statusFilter, priorityFilter],
    queryFn: () => tasksApi.list({
      status: statusFilter || undefined,
      priority: priorityFilter || undefined,
      limit: 100,
    }),
  });

  const completeMutation = useMutation({
    mutationFn: (id: string) => tasksApi.complete(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
  });

  const tasks: Task[] = data?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Tasks</h1>
        <p className="text-sm text-gray-500 mt-0.5">Clinician inbox — outstanding actions</p>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3">
        {["open", "in_progress", "completed", ""].map((s) => (
          <button
            key={s}
            onClick={() => setStatusFilter(s)}
            className={cn(
              "px-3 py-1.5 rounded-full text-sm font-medium border transition-colors",
              statusFilter === s
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white text-gray-600 border-gray-200 hover:border-gray-300"
            )}
          >
            {s === "" ? "All" : s.replace("_", " ")}
          </button>
        ))}
        <select
          value={priorityFilter}
          onChange={(e) => setPriorityFilter(e.target.value)}
          className="ml-auto text-sm border border-gray-200 rounded-lg px-3 py-1.5 bg-white"
        >
          <option value="">All priorities</option>
          <option value="urgent">Urgent</option>
          <option value="high">High</option>
          <option value="normal">Normal</option>
          <option value="low">Low</option>
        </select>
      </div>

      {/* Task list */}
      {isLoading ? (
        <div className="text-sm text-gray-400">Loading...</div>
      ) : tasks.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <CheckSquare className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">No tasks found</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
          {tasks.map((t) => (
            <div key={t.id} className="flex items-start gap-4 px-5 py-4">
              <button
                onClick={() => t.status !== "completed" && completeMutation.mutate(t.id)}
                className={cn(
                  "mt-0.5 w-5 h-5 rounded border-2 flex items-center justify-center shrink-0 transition-colors",
                  t.status === "completed"
                    ? "border-green-500 bg-green-500 text-white"
                    : "border-gray-300 hover:border-blue-400"
                )}
              >
                {t.status === "completed" && <Check className="w-3 h-3" />}
              </button>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className={cn(
                    "text-sm font-medium",
                    t.status === "completed" ? "line-through text-gray-400" : "text-gray-900"
                  )}>{t.title}</span>
                  <span className={cn("text-xs px-2 py-0.5 rounded-full border font-medium", PRIORITY_COLOR[t.priority])}>
                    {t.priority}
                  </span>
                  <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium", STATUS_COLOR[t.status])}>
                    {t.status.replace("_", " ")}
                  </span>
                </div>
                {t.description && (
                  <p className="text-sm text-gray-500 mt-0.5 line-clamp-2">{t.description}</p>
                )}
                <div className="flex items-center gap-3 mt-1">
                  <span className="text-xs text-gray-400 capitalize">{t.category.replace("_", " ")}</span>
                  {t.due_at && (
                    <span className="text-xs text-gray-400 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      Due {new Date(t.due_at).toLocaleDateString()}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
