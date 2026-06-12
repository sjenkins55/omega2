"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { patientsApi, ordersApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Stethoscope, Calendar } from "lucide-react";

type Patient = { id: string; first_name: string; last_name: string; mrn: string };

type Order = {
  id: string;
  order_type: string;
  status: string;
  description?: string;
  frequency?: string;
  physician_name?: string;
  start_date?: string;
  end_date?: string;
  is_verbal_order: boolean;
  written_order_received: boolean;
};

const STATUS_COLOR: Record<string, string> = {
  pending: "text-yellow-700 bg-yellow-50",
  active: "text-green-700 bg-green-50",
  completed: "text-gray-600 bg-gray-50",
  cancelled: "text-red-600 bg-red-50",
  expired: "text-orange-600 bg-orange-50",
};

export default function OrdersPage() {
  const [selectedPatient, setSelectedPatient] = useState("");
  const [statusFilter, setStatusFilter] = useState("active");

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: ordersData } = useQuery({
    queryKey: ["orders", selectedPatient, statusFilter],
    queryFn: () => ordersApi.list(selectedPatient, { status: statusFilter || undefined }),
    enabled: !!selectedPatient,
  });

  const patients: Patient[] = patientsData?.data?.patients ?? [];
  const orders: Order[] = ordersData?.data ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
          <Stethoscope className="w-6 h-6 text-blue-600" /> Physician Orders
        </h1>
        <p className="text-sm text-gray-500 mt-0.5">Skilled nursing, therapy, and medication orders</p>
      </div>

      <div className="flex items-center gap-3">
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
        {["active", "pending", ""].map((s) => (
          <button
            key={s}
            onClick={() => setStatusFilter(s)}
            className={cn(
              "px-3 py-1.5 rounded-full text-sm border transition-colors",
              statusFilter === s
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white text-gray-600 border-gray-200"
            )}
          >
            {s === "" ? "All" : s}
          </button>
        ))}
      </div>

      {selectedPatient && (
        orders.length === 0 ? (
          <div className="bg-white rounded-xl border border-gray-200 p-10 text-center">
            <Stethoscope className="w-8 h-8 text-gray-300 mx-auto mb-2" />
            <p className="text-gray-400">No orders found</p>
          </div>
        ) : (
          <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
            {orders.map((o) => (
              <div key={o.id} className="px-5 py-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-semibold text-gray-900 capitalize">{o.order_type.replace("_", " ")}</span>
                      <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium", STATUS_COLOR[o.status])}>
                        {o.status}
                      </span>
                      {o.is_verbal_order && !o.written_order_received && (
                        <span className="text-xs px-2 py-0.5 rounded-full bg-orange-50 text-orange-700">Verbal — awaiting written</span>
                      )}
                    </div>
                    {o.description && <p className="text-sm text-gray-600 mt-0.5">{o.description}</p>}
                    <div className="flex items-center gap-4 mt-1 text-xs text-gray-400">
                      {o.frequency && <span>{o.frequency}</span>}
                      {o.physician_name && <span>Dr. {o.physician_name}</span>}
                      {(o.start_date || o.end_date) && (
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3 h-3" />
                          {o.start_date} {o.end_date ? `→ ${o.end_date}` : ""}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )
      )}

      {!selectedPatient && (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <Stethoscope className="w-10 h-10 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Select a patient to view their orders</p>
        </div>
      )}
    </div>
  );
}
