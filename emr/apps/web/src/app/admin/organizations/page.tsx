"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { organizationsApi } from "@/lib/api";
import { cn } from "@/lib/utils";
import { Building2, Plus, CheckCircle, XCircle, Settings2 } from "lucide-react";

type Organization = {
  id: string;
  name: string;
  slug: string;
  plan_tier: string;
  is_active: boolean;
  max_users?: number;
  max_patients?: number;
  created_at: string;
};

const TIER_COLOR: Record<string, string> = {
  starter: "text-gray-600 bg-gray-50",
  professional: "text-blue-700 bg-blue-50",
  enterprise: "text-purple-700 bg-purple-50",
};

export default function OrganizationsPage() {
  const qc = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [showProvision, setShowProvision] = useState<string | null>(null);
  const [form, setForm] = useState({ name: "", slug: "", plan_tier: "starter" });
  const [adminForm, setAdminForm] = useState({ email: "", first_name: "", last_name: "", password: "" });
  const [provisionResult, setProvisionResult] = useState<{ generated_password?: string } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["organizations"],
    queryFn: () => organizationsApi.list(),
  });

  const createMutation = useMutation({
    mutationFn: () => organizationsApi.create({ ...form }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["organizations"] }); setShowCreate(false); setForm({ name: "", slug: "", plan_tier: "starter" }); },
  });

  const provisionMutation = useMutation({
    mutationFn: (orgId: string) => organizationsApi.provisionAdmin(orgId, adminForm),
    onSuccess: (res) => {
      setProvisionResult(res.data);
      setAdminForm({ email: "", first_name: "", last_name: "", password: "" });
    },
  });

  const orgs: Organization[] = data?.data?.organizations ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900 flex items-center gap-2">
            <Building2 className="w-6 h-6 text-blue-600" /> Organizations
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">Provision new agency instances — super admin only</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          <Plus className="w-4 h-4" /> New Organization
        </button>
      </div>

      {/* Create form */}
      {showCreate && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-semibold text-gray-900 mb-4">Create New Organization</h3>
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="text-xs font-medium text-gray-600 block mb-1">Organization Name</label>
              <input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" placeholder="Acme Home Health" />
            </div>
            <div>
              <label className="text-xs font-medium text-gray-600 block mb-1">Slug (unique URL key)</label>
              <input value={form.slug} onChange={e => setForm(f => ({ ...f, slug: e.target.value }))}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm font-mono" placeholder="acme-home-health" />
            </div>
            <div>
              <label className="text-xs font-medium text-gray-600 block mb-1">Plan Tier</label>
              <select value={form.plan_tier} onChange={e => setForm(f => ({ ...f, plan_tier: e.target.value }))}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm">
                <option value="starter">Starter</option>
                <option value="professional">Professional</option>
                <option value="enterprise">Enterprise</option>
              </select>
            </div>
          </div>
          <div className="flex items-center gap-3 mt-4">
            <button onClick={() => createMutation.mutate()} disabled={!form.name || !form.slug || createMutation.isPending}
              className="px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
              {createMutation.isPending ? "Creating…" : "Create"}
            </button>
            <button onClick={() => setShowCreate(false)} className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800">Cancel</button>
          </div>
        </div>
      )}

      {/* Provision admin result */}
      {provisionResult && (
        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
          <p className="text-sm font-semibold text-green-800">Admin account created successfully</p>
          {provisionResult.generated_password && (
            <p className="text-sm text-green-700 mt-1">
              Temporary password: <span className="font-mono font-bold">{provisionResult.generated_password}</span>
              <span className="text-xs ml-2 opacity-70">(save this — shown only once)</span>
            </p>
          )}
          <button onClick={() => setProvisionResult(null)} className="text-xs text-green-600 underline mt-2">Dismiss</button>
        </div>
      )}

      {/* Org list */}
      {isLoading ? (
        <div className="text-sm text-gray-400">Loading…</div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
          {orgs.length === 0 ? (
            <div className="p-10 text-center">
              <Building2 className="w-8 h-8 text-gray-300 mx-auto mb-2" />
              <p className="text-gray-400">No organizations yet</p>
            </div>
          ) : orgs.map((o) => (
            <div key={o.id} className="px-5 py-4">
              <div className="flex items-center gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-gray-900">{o.name}</span>
                    <span className="text-xs text-gray-400 font-mono">{o.slug}</span>
                    <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium capitalize", TIER_COLOR[o.plan_tier])}>
                      {o.plan_tier}
                    </span>
                    {o.is_active
                      ? <CheckCircle className="w-4 h-4 text-green-500" />
                      : <XCircle className="w-4 h-4 text-red-400" />}
                  </div>
                  <p className="text-xs text-gray-400 mt-0.5">
                    Created {new Date(o.created_at).toLocaleDateString()}
                    {o.max_users ? ` · max ${o.max_users} users` : ""}
                    {o.max_patients ? ` · max ${o.max_patients} patients` : ""}
                  </p>
                </div>
                <button
                  onClick={() => setShowProvision(showProvision === o.id ? null : o.id)}
                  className="flex items-center gap-1.5 px-3 py-1.5 text-sm border border-gray-200 rounded-lg hover:border-blue-300 hover:text-blue-600"
                >
                  <Settings2 className="w-3.5 h-3.5" /> Provision Admin
                </button>
              </div>

              {/* Provision admin form inline */}
              {showProvision === o.id && (
                <div className="mt-3 pt-3 border-t border-gray-100">
                  <p className="text-xs font-semibold text-gray-500 mb-3 uppercase tracking-wide">Create Admin User for {o.name}</p>
                  <div className="grid grid-cols-4 gap-3">
                    <input value={adminForm.email} onChange={e => setAdminForm(f => ({ ...f, email: e.target.value }))}
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm" placeholder="admin@email.com" />
                    <input value={adminForm.first_name} onChange={e => setAdminForm(f => ({ ...f, first_name: e.target.value }))}
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm" placeholder="First name" />
                    <input value={adminForm.last_name} onChange={e => setAdminForm(f => ({ ...f, last_name: e.target.value }))}
                      className="border border-gray-200 rounded-lg px-3 py-2 text-sm" placeholder="Last name" />
                    <input value={adminForm.password} onChange={e => setAdminForm(f => ({ ...f, password: e.target.value }))}
                      type="password" className="border border-gray-200 rounded-lg px-3 py-2 text-sm" placeholder="Password (leave blank to auto-generate)" />
                  </div>
                  <button
                    onClick={() => provisionMutation.mutate(o.id)}
                    disabled={!adminForm.email || provisionMutation.isPending}
                    className="mt-3 px-4 py-2 text-sm font-medium bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                  >
                    {provisionMutation.isPending ? "Creating…" : "Create Admin"}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
