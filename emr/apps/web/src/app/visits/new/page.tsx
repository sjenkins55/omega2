"use client";
import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { visitsApi, patientsApi, authApi } from "@/lib/api";
import { useRouter } from "next/navigation";
import { Loader2, ChevronLeft } from "lucide-react";
import Link from "next/link";

const VISIT_TYPES = [
  { value: "skilled_nursing", label: "Skilled Nursing" },
  { value: "physical_therapy", label: "Physical Therapy" },
  { value: "occupational_therapy", label: "Occupational Therapy" },
  { value: "speech_therapy", label: "Speech Therapy" },
  { value: "social_work", label: "Social Work" },
  { value: "aide", label: "Home Health Aide" },
  { value: "telehealth", label: "Telehealth" },
];

type PatientLite = { id: string; first_name: string; last_name: string; mrn: string };

export default function NewVisitPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    patient_id: "",
    visit_type: "skilled_nursing",
    scheduled_at: "",
  });

  const { data: patientsData } = useQuery({
    queryKey: ["patients", "active"],
    queryFn: () => patientsApi.list({ status: "active", limit: 200 }),
  });

  const { data: meData } = useQuery({
    queryKey: ["me"],
    queryFn: () => authApi.me(),
    staleTime: 5 * 60 * 1000,
  });

  const patients: PatientLite[] = patientsData?.data?.patients ?? [];
  const me = meData?.data;

  const createMutation = useMutation({
    mutationFn: () =>
      visitsApi.create({
        patient_id: form.patient_id,
        visit_type: form.visit_type,
        scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : undefined,
        clinician_id: me?.id ?? undefined,
      }),
    onSuccess: (res) => {
      router.push(`/visits/${res.data.id}`);
    },
  });

  return (
    <div className="max-w-lg">
      <div className="flex items-center gap-3 mb-6">
        <Link href="/visits" className="p-1.5 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100">
          <ChevronLeft className="w-5 h-5" />
        </Link>
        <div>
          <h1 className="text-xl font-semibold text-gray-900">Schedule New Visit</h1>
          <p className="text-sm text-gray-500">Create a scheduled home visit</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-5">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Patient *</label>
          <select
            value={form.patient_id}
            onChange={(e) => setForm((f) => ({ ...f, patient_id: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select a patient…</option>
            {patients.map((p) => (
              <option key={p.id} value={p.id}>
                {p.last_name}, {p.first_name} — {p.mrn}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Visit Type *</label>
          <select
            value={form.visit_type}
            onChange={(e) => setForm((f) => ({ ...f, visit_type: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {VISIT_TYPES.map((vt) => (
              <option key={vt.value} value={vt.value}>{vt.label}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Scheduled Date & Time *</label>
          <input
            type="datetime-local"
            value={form.scheduled_at}
            onChange={(e) => setForm((f) => ({ ...f, scheduled_at: e.target.value }))}
            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {createMutation.isError && (
          <p className="text-sm text-red-600">Failed to create visit. Please try again.</p>
        )}

        <div className="flex gap-3 pt-1">
          <Link
            href="/visits"
            className="flex-1 text-center py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50"
          >
            Cancel
          </Link>
          <button
            onClick={() => createMutation.mutate()}
            disabled={!form.patient_id || !form.scheduled_at || createMutation.isPending}
            className="flex-1 flex items-center justify-center gap-2 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {createMutation.isPending && <Loader2 className="w-4 h-4 animate-spin" />}
            Schedule Visit
          </button>
        </div>
      </div>
    </div>
  );
}
