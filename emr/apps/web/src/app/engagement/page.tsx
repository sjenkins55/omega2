"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { engagementApi } from "@/lib/api";
import { OutreachRecord } from "@/types";
import { cn, formatDateTime } from "@/lib/utils";
import { MessageSquare, Send, Loader2, Plus, Phone, Mail } from "lucide-react";

const CHANNEL_ICONS: Record<string, React.ReactNode> = {
  sms: <MessageSquare className="w-4 h-4" />,
  email: <Mail className="w-4 h-4" />,
  phone: <Phone className="w-4 h-4" />,
};

const STATUS_COLORS: Record<string, string> = {
  scheduled: "bg-blue-50 text-blue-700",
  sent: "bg-purple-50 text-purple-700",
  delivered: "bg-teal-50 text-teal-700",
  failed: "bg-red-50 text-red-700",
  responded: "bg-green-50 text-green-700",
  no_response: "bg-gray-100 text-gray-600",
};

export default function EngagementPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ["outreach"],
    queryFn: () => engagementApi.list({ limit: 100 }),
  });

  const sendMutation = useMutation({
    mutationFn: (id: string) => engagementApi.send(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["outreach"] }),
  });

  const records: OutreachRecord[] = data?.data ?? [];
  const pending = records.filter((r) => r.status === "scheduled");

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Engagement</h1>
          <p className="text-sm text-gray-500">Patient outreach and communication — AI-personalized messages</p>
        </div>
        <button className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700">
          <Plus className="w-4 h-4" /> Schedule Outreach
        </button>
      </div>

      {pending.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <Send className="w-4 h-4 text-blue-500" />
            Pending Outreach ({pending.length})
          </h2>
          <div className="space-y-2">
            {pending.slice(0, 5).map((rec) => (
              <div key={rec.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="text-gray-500">{CHANNEL_ICONS[rec.channel] ?? <MessageSquare className="w-4 h-4" />}</div>
                  <div>
                    <div className="text-sm font-medium text-gray-900 capitalize">
                      {rec.outreach_type.replace(/_/g, " ")}
                    </div>
                    <div className="text-xs text-gray-500">Scheduled {formatDateTime(rec.scheduled_at)}</div>
                  </div>
                </div>
                <button
                  onClick={() => sendMutation.mutate(rec.id)}
                  disabled={sendMutation.isPending}
                  className="flex items-center gap-1.5 text-sm text-blue-600 hover:text-blue-700 px-3 py-1.5 border border-blue-200 rounded-lg hover:bg-blue-50"
                >
                  {sendMutation.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
                  Send Now
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-4 border-b border-gray-100">
          <h2 className="font-semibold text-gray-900">All Outreach History</h2>
        </div>
        {isLoading ? (
          <div className="py-12 text-center text-sm text-gray-400">Loading...</div>
        ) : (
          <div className="divide-y divide-gray-50">
            {records.map((rec) => (
              <div key={rec.id} className="flex items-center gap-4 px-5 py-3">
                <div className="text-gray-400">{CHANNEL_ICONS[rec.channel] ?? <MessageSquare className="w-4 h-4" />}</div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-900 capitalize">{rec.outreach_type.replace(/_/g, " ")}</div>
                  <div className="text-xs text-gray-500">{rec.message_content?.slice(0, 80) ?? "No message content"}</div>
                </div>
                <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full capitalize", STATUS_COLORS[rec.status] ?? "bg-gray-100 text-gray-600")}>
                  {rec.status}
                </span>
                <span className="text-xs text-gray-400">{formatDateTime(rec.created_at)}</span>
              </div>
            ))}
            {records.length === 0 && (
              <div className="py-12 text-center text-sm text-gray-400">No outreach records yet</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
