"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { auditApi } from "@/lib/api";
import { ShieldCheck } from "lucide-react";

type AuditEvent = {
  id: string;
  user_email?: string;
  action: string;
  resource_type: string;
  resource_id?: string;
  ip_address?: string;
  created_at: string;
};

const ACTION_COLOR: Record<string, string> = {
  read: "text-gray-600 bg-gray-50",
  create: "text-green-700 bg-green-50",
  update: "text-blue-700 bg-blue-50",
  delete: "text-red-700 bg-red-50",
  login: "text-purple-700 bg-purple-50",
  export: "text-orange-700 bg-orange-50",
};

export default function AuditLogPage() {
  const [resourceType, setResourceType] = useState("");
  const [action, setAction] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["audit", resourceType, action],
    queryFn: () => auditApi.list({
      resource_type: resourceType || undefined,
      action: action || undefined,
      limit: 200,
    }),
  });

  const events: AuditEvent[] = data?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <ShieldCheck className="w-6 h-6 text-blue-600" /> HIPAA Audit Log
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">All ePHI access events — append-only per 45 CFR §164.312(b)</p>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3">
        <select
          value={resourceType}
          onChange={(e) => setResourceType(e.target.value)}
          className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 bg-white"
        >
          <option value="">All resources</option>
          <option value="patient">Patient</option>
          <option value="visit">Visit</option>
          <option value="lab_result">Lab Result</option>
          <option value="document">Document</option>
        </select>
        <select
          value={action}
          onChange={(e) => setAction(e.target.value)}
          className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 bg-white"
        >
          <option value="">All actions</option>
          <option value="read">Read</option>
          <option value="create">Create</option>
          <option value="update">Update</option>
          <option value="delete">Delete</option>
          <option value="login">Login</option>
          <option value="export">Export</option>
        </select>
        <span className="ml-auto text-sm text-gray-500">{events.length} events</span>
      </div>

      {isLoading ? (
        <div className="text-sm text-gray-400">Loading...</div>
      ) : events.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <ShieldCheck className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">No audit events recorded yet</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Time</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">User</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Action</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Resource</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">IP</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {events.map((e) => (
                <tr key={e.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-xs text-gray-500 font-mono whitespace-nowrap">
                    {new Date(e.created_at).toLocaleString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700">{e.user_email ?? "—"}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${ACTION_COLOR[e.action] ?? "text-gray-600 bg-gray-50"}`}>
                      {e.action}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-700">
                    {e.resource_type}
                    {e.resource_id && <span className="text-xs text-gray-400 ml-1 font-mono">{e.resource_id.slice(0, 8)}…</span>}
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-400 font-mono">{e.ip_address ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
