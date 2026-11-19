"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { authApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { User as UserIcon, Bell, Info, ShieldCheck } from "lucide-react";

type Me = {
  id: string;
  email: string;
  full_name: string;
  role: string;
  npi: string | null;
  is_active: boolean;
};

const APP_VERSION = "0.1.0";

const NOTIFICATION_PREFS = [
  { key: "task_assigned", label: "Task assigned to me", description: "Notify when a new task lands in my inbox" },
  { key: "visit_reminders", label: "Visit reminders", description: "Reminder 1 hour before each scheduled visit" },
  { key: "critical_alerts", label: "Critical patient alerts", description: "High-risk vitals, abnormal labs, ADT events" },
  { key: "workflow_updates", label: "Workflow updates", description: "When automated workflows complete or fail" },
] as const;

function Toggle({ on, onClick }: { on: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      role="switch"
      aria-checked={on}
      className={cn(
        "relative w-10 h-6 rounded-full transition-colors shrink-0",
        on ? "bg-blue-600" : "bg-gray-200"
      )}
    >
      <span
        className={cn(
          "absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform",
          on ? "translate-x-[18px]" : "translate-x-0.5"
        )}
      />
    </button>
  );
}

export default function SettingsPage() {
  const [prefs, setPrefs] = useState<Record<string, boolean>>({
    task_assigned: true,
    visit_reminders: true,
    critical_alerts: true,
    workflow_updates: false,
  });

  const { data, isLoading } = useQuery({
    queryKey: ["auth", "me"],
    queryFn: () => authApi.me(),
  });

  const me: Me | undefined = data?.data;

  return (
    <div className="max-w-3xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Settings</h1>
        <p className="text-sm text-gray-500 mt-0.5">Your profile, preferences, and application info</p>
      </div>

      {/* Profile */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
          <UserIcon className="w-4 h-4 text-blue-500" />
          <h2 className="font-semibold text-gray-900">Profile</h2>
        </div>
        {isLoading ? (
          <div className="px-5 py-8 text-sm text-gray-400">Loading...</div>
        ) : me ? (
          <div className="px-5 py-4 flex items-start gap-4">
            <div className="w-12 h-12 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-lg font-semibold shrink-0">
              {me.full_name.split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase()}
            </div>
            <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-sm">
              <div>
                <div className="text-xs text-gray-400 uppercase tracking-wide">Name</div>
                <div className="text-gray-900 font-medium">{me.full_name}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400 uppercase tracking-wide">Email</div>
                <div className="text-gray-900">{me.email}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400 uppercase tracking-wide">Role</div>
                <div className="text-gray-900 capitalize">{me.role.replace(/_/g, " ")}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400 uppercase tracking-wide">NPI</div>
                <div className="text-gray-900 font-mono">{me.npi ?? "—"}</div>
              </div>
              <div>
                <div className="text-xs text-gray-400 uppercase tracking-wide">Status</div>
                <span className={cn(
                  "inline-block text-xs font-medium px-2 py-0.5 rounded-full mt-0.5",
                  me.is_active ? "bg-green-50 text-green-700" : "bg-gray-100 text-gray-500"
                )}>
                  {me.is_active ? "Active" : "Inactive"}
                </span>
              </div>
            </div>
          </div>
        ) : (
          <div className="px-5 py-8 text-sm text-gray-400">Unable to load profile</div>
        )}
      </div>

      {/* Notification preferences */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell className="w-4 h-4 text-orange-500" />
            <h2 className="font-semibold text-gray-900">Notification Preferences</h2>
          </div>
          <span className="text-xs text-gray-400">Saved locally — server sync coming soon</span>
        </div>
        <div className="divide-y divide-gray-50">
          {NOTIFICATION_PREFS.map((p) => (
            <div key={p.key} className="px-5 py-3.5 flex items-center justify-between gap-4">
              <div>
                <div className="text-sm font-medium text-gray-900">{p.label}</div>
                <div className="text-xs text-gray-500">{p.description}</div>
              </div>
              <Toggle
                on={!!prefs[p.key]}
                onClick={() => setPrefs((prev) => ({ ...prev, [p.key]: !prev[p.key] }))}
              />
            </div>
          ))}
        </div>
      </div>

      {/* App info */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
          <Info className="w-4 h-4 text-gray-500" />
          <h2 className="font-semibold text-gray-900">About</h2>
        </div>
        <div className="px-5 py-4 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-sm">
          <div>
            <div className="text-xs text-gray-400 uppercase tracking-wide">Application</div>
            <div className="text-gray-900 font-medium">ConcertoCare EMR</div>
          </div>
          <div>
            <div className="text-xs text-gray-400 uppercase tracking-wide">Version</div>
            <div className="text-gray-900 font-mono">{APP_VERSION}</div>
          </div>
          <div className="sm:col-span-2 flex items-start gap-2 mt-1 p-3 rounded-lg bg-blue-50 text-blue-800">
            <ShieldCheck className="w-4 h-4 shrink-0 mt-0.5" />
            <p className="text-xs">
              All access to patient data is logged in the HIPAA audit trail. AI features follow the
              minimum-necessary standard and are scoped to your role.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
