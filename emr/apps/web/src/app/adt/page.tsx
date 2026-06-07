"use client";
import { useQuery } from "@tanstack/react-query";
import { adtApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Hospital, CheckCircle, XCircle, Zap } from "lucide-react";

type ADTEvent = {
  id: string;
  patient_id?: string;
  mrn_in_message?: string;
  event_type: string;
  event_datetime?: string;
  hospital_name?: string;
  discharge_disposition?: string;
  matched: boolean;
  workflow_triggered: boolean;
  created_at: string;
};

const EVENT_COLOR: Record<string, string> = {
  admit: "text-blue-700 bg-blue-50",
  discharge: "text-green-700 bg-green-50",
  transfer: "text-purple-700 bg-purple-50",
};

export default function ADTPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["adt"],
    queryFn: () => adtApi.list({ limit: 100 }),
  });

  const events: ADTEvent[] = data?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">ADT Events</h1>
        <p className="text-sm text-gray-500 mt-0.5">Hospital admit / discharge / transfer notifications</p>
      </div>

      {isLoading ? (
        <div className="text-sm text-gray-400">Loading...</div>
      ) : events.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <Hospital className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">No ADT events received yet</p>
          <p className="text-xs text-gray-400 mt-1">Events arrive via POST /api/v1/adt/inbound</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
          {events.map((e) => (
            <div key={e.id} className="flex items-center gap-4 px-5 py-4">
              <div className={cn("text-xs font-semibold px-2.5 py-1 rounded-full capitalize", EVENT_COLOR[e.event_type] ?? "text-gray-700 bg-gray-50")}>
                {e.event_type}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-gray-900">{e.hospital_name ?? "Unknown hospital"}</span>
                  {e.mrn_in_message && (
                    <span className="text-xs text-gray-400">MRN {e.mrn_in_message}</span>
                  )}
                </div>
                {e.discharge_disposition && (
                  <p className="text-xs text-gray-500 mt-0.5">Disposition: {e.discharge_disposition}</p>
                )}
                <p className="text-xs text-gray-400 mt-0.5">
                  {e.event_datetime ? new Date(e.event_datetime).toLocaleString() : "—"}
                </p>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <span className={cn("flex items-center gap-1 text-xs", e.matched ? "text-green-600" : "text-gray-400")}>
                  {e.matched ? <CheckCircle className="w-3.5 h-3.5" /> : <XCircle className="w-3.5 h-3.5" />}
                  {e.matched ? "Matched" : "Unmatched"}
                </span>
                {e.workflow_triggered && (
                  <span className="flex items-center gap-1 text-xs text-blue-600">
                    <Zap className="w-3.5 h-3.5" /> Triggered
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
