"use client";
import { useState, useEffect } from "react";
import {
  UserPlus, Search, Shield, Edit2, UserX, UserCheck,
  Key, ChevronDown, X, Check, RefreshCw,
} from "lucide-react";

const API = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

const ROLES = [
  "admin", "physician", "nurse", "therapist",
  "social_worker", "aide", "care_coordinator", "billing",
] as const;
type Role = typeof ROLES[number];

const ROLE_LABELS: Record<Role, string> = {
  admin: "Admin",
  physician: "Physician",
  nurse: "Nurse",
  therapist: "Therapist",
  social_worker: "Social Worker",
  aide: "Aide",
  care_coordinator: "Care Coordinator",
  billing: "Billing",
};

const ROLE_COLORS: Record<Role, string> = {
  admin: "bg-red-100 text-red-700",
  physician: "bg-indigo-100 text-indigo-700",
  nurse: "bg-blue-100 text-blue-700",
  therapist: "bg-violet-100 text-violet-700",
  social_worker: "bg-teal-100 text-teal-700",
  aide: "bg-amber-100 text-amber-700",
  care_coordinator: "bg-emerald-100 text-emerald-700",
  billing: "bg-slate-100 text-slate-700",
};

type User = {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  role: Role;
  npi: string | null;
  is_active: boolean;
  licensed_states: string[];
  created_at: string | null;
};

type FormData = {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  role: Role;
  npi: string;
  licensed_states: string[];
};

const EMPTY_FORM: FormData = {
  email: "", password: "", first_name: "", last_name: "",
  role: "nurse", npi: "", licensed_states: [],
};

const US_STATES = [
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
  "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
  "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
  "VA","WA","WV","WI","WY","DC",
];

export default function UsersAdminPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<Role | "">("");
  const [showInactive, setShowInactive] = useState(false);

  const [showCreate, setShowCreate] = useState(false);
  const [editUser, setEditUser] = useState<User | null>(null);
  const [form, setForm] = useState<FormData>(EMPTY_FORM);
  const [formError, setFormError] = useState("");
  const [saving, setSaving] = useState(false);

  const [resetTarget, setResetTarget] = useState<User | null>(null);
  const [newPassword, setNewPassword] = useState("");
  const [resetSaving, setResetSaving] = useState(false);

  useEffect(() => { load(); }, []);

  function authHeaders(extra?: Record<string, string>): Record<string, string> {
    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    return { Authorization: `Bearer ${token}`, ...extra };
  }

  async function load() {
    setLoading(true);
    try {
      const res = await fetch(`${API}/admin/users`, {
        headers: authHeaders(),
      });
      const data = await res.json();
      setUsers(data.users ?? []);
    } finally {
      setLoading(false);
    }
  }

  function openCreate() {
    setForm(EMPTY_FORM);
    setFormError("");
    setEditUser(null);
    setShowCreate(true);
  }

  function openEdit(u: User) {
    setForm({ email: u.email, password: "", first_name: u.first_name, last_name: u.last_name, role: u.role, npi: u.npi ?? "", licensed_states: u.licensed_states ?? [] });
    setFormError("");
    setEditUser(u);
    setShowCreate(true);
  }

  async function saveUser() {
    setSaving(true);
    setFormError("");
    try {
      const body: Record<string, unknown> = {
        email: form.email, first_name: form.first_name,
        last_name: form.last_name, role: form.role, npi: form.npi,
        licensed_states: form.licensed_states,
      };
      if (form.password) body.password = form.password;

      const url = editUser
        ? `${API}/admin/users/${editUser.id}`
        : `${API}/admin/users`;
      const method = editUser ? "PATCH" : "POST";

      if (!editUser) body.password = form.password;

      const res = await fetch(url, {
        method,
        headers: authHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const err = await res.json();
        setFormError(err.detail ?? "Save failed");
        return;
      }
      setShowCreate(false);
      await load();
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(u: User) {
    await fetch(`${API}/admin/users/${u.id}`, {
      method: "PATCH",
      headers: authHeaders({ "Content-Type": "application/json" }),
      body: JSON.stringify({ is_active: !u.is_active }),
    });
    await load();
  }

  async function savePasswordReset() {
    if (!resetTarget || !newPassword) return;
    setResetSaving(true);
    try {
      await fetch(`${API}/admin/users/${resetTarget.id}`, {
        method: "PATCH",
        headers: authHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ password: newPassword }),
      });
      setResetTarget(null);
      setNewPassword("");
    } finally {
      setResetSaving(false);
    }
  }

  const filtered = users.filter(u => {
    if (!showInactive && !u.is_active) return false;
    if (roleFilter && u.role !== roleFilter) return false;
    const q = search.toLowerCase();
    return !q || u.full_name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q) || (u.npi ?? "").includes(q);
  });

  const byRole = ROLES.reduce((acc, r) => {
    acc[r] = users.filter(u => u.role === r && u.is_active).length;
    return acc;
  }, {} as Record<Role, number>);

  return (
    <div className="flex-1 overflow-y-auto bg-slate-50">
      <div className="max-w-6xl mx-auto px-6 py-8">

        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-semibold text-slate-900">User Management</h1>
            <p className="text-sm text-slate-500 mt-1">
              {users.filter(u => u.is_active).length} active users · {users.length} total
            </p>
          </div>
          <div className="flex gap-2">
            <button onClick={load} className="p-2 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-slate-500">
              <RefreshCw className="w-4 h-4" />
            </button>
            <button
              onClick={openCreate}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
            >
              <UserPlus className="w-4 h-4" />
              Add User
            </button>
          </div>
        </div>

        {/* Role stat chips */}
        <div className="flex flex-wrap gap-2 mb-6">
          <button
            onClick={() => setRoleFilter("")}
            className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
              roleFilter === "" ? "bg-slate-800 text-white border-slate-800" : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
            }`}
          >
            All roles
          </button>
          {ROLES.map(r => (
            <button
              key={r}
              onClick={() => setRoleFilter(roleFilter === r ? "" : r)}
              className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
                roleFilter === r ? "bg-slate-800 text-white border-slate-800" : `${ROLE_COLORS[r]} border-transparent hover:opacity-80`
              }`}
            >
              {ROLE_LABELS[r]} {byRole[r] > 0 && <span className="ml-1 opacity-70">{byRole[r]}</span>}
            </button>
          ))}
        </div>

        {/* Filters */}
        <div className="flex gap-3 mb-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-2.5 w-4 h-4 text-slate-400" />
            <input
              className="w-full pl-9 pr-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Search by name, email, or NPI…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
          <label className="flex items-center gap-2 text-sm text-slate-600 bg-white border border-slate-200 rounded-lg px-3 cursor-pointer hover:bg-slate-50">
            <input type="checkbox" checked={showInactive} onChange={e => setShowInactive(e.target.checked)} className="rounded" />
            Show inactive
          </label>
        </div>

        {/* Table */}
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50">
                <th className="text-left px-5 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">User</th>
                <th className="text-left px-5 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Role</th>
                <th className="text-left px-5 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">NPI</th>
                <th className="text-left px-5 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Status</th>
                <th className="text-left px-5 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Joined</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr><td colSpan={6} className="text-center py-12 text-slate-400">Loading…</td></tr>
              ) : filtered.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-12 text-slate-400">No users found</td></tr>
              ) : filtered.map(u => (
                <tr key={u.id} className={`hover:bg-slate-50 transition-colors ${!u.is_active ? "opacity-50" : ""}`}>
                  <td className="px-5 py-3">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-semibold text-xs shrink-0">
                        {u.first_name[0]}{u.last_name[0]}
                      </div>
                      <div>
                        <div className="font-medium text-slate-900">{u.full_name}</div>
                        <div className="text-xs text-slate-400">{u.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-3">
                    <span className={`text-xs px-2 py-1 rounded-full font-medium ${ROLE_COLORS[u.role]}`}>
                      {ROLE_LABELS[u.role]}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-slate-500 font-mono text-xs">{u.npi ?? "—"}</td>
                  <td className="px-5 py-3">
                    {(u.licensed_states ?? []).length > 0 ? (
                      <div className="flex flex-wrap gap-1">
                        {u.licensed_states.map(s => (
                          <span key={s} className="text-[10px] px-1.5 py-0.5 bg-blue-50 text-blue-700 rounded font-mono font-semibold">{s}</span>
                        ))}
                      </div>
                    ) : (
                      <span className="text-xs text-red-400 italic">None set</span>
                    )}
                  </td>
                  <td className="px-5 py-3">
                    <span className={`inline-flex items-center gap-1 text-xs px-2 py-1 rounded-full font-medium ${
                      u.is_active ? "bg-green-100 text-green-700" : "bg-slate-100 text-slate-500"
                    }`}>
                      {u.is_active ? <><Check className="w-3 h-3" /> Active</> : "Inactive"}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-xs text-slate-400">
                    {u.created_at ? new Date(u.created_at).toLocaleDateString() : "—"}
                  </td>
                  <td className="px-5 py-3">
                    <div className="flex items-center gap-1 justify-end">
                      <button
                        onClick={() => openEdit(u)}
                        title="Edit"
                        className="p-1.5 rounded hover:bg-slate-100 text-slate-500 hover:text-slate-700"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => { setResetTarget(u); setNewPassword(""); }}
                        title="Reset password"
                        className="p-1.5 rounded hover:bg-slate-100 text-slate-500 hover:text-slate-700"
                      >
                        <Key className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => toggleActive(u)}
                        title={u.is_active ? "Deactivate" : "Activate"}
                        className={`p-1.5 rounded hover:bg-slate-100 ${
                          u.is_active ? "text-red-400 hover:text-red-600" : "text-green-500 hover:text-green-700"
                        }`}
                      >
                        {u.is_active ? <UserX className="w-3.5 h-3.5" /> : <UserCheck className="w-3.5 h-3.5" />}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create / Edit modal */}
      {showCreate && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200">
              <h2 className="font-semibold text-slate-900 flex items-center gap-2">
                <Shield className="w-4 h-4 text-blue-500" />
                {editUser ? "Edit User" : "New User"}
              </h2>
              <button onClick={() => setShowCreate(false)} className="p-1 rounded hover:bg-slate-100">
                <X className="w-4 h-4 text-slate-400" />
              </button>
            </div>
            <div className="px-6 py-4 space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <Field label="First name">
                  <input className={INPUT} value={form.first_name} onChange={e => setForm(f => ({ ...f, first_name: e.target.value }))} />
                </Field>
                <Field label="Last name">
                  <input className={INPUT} value={form.last_name} onChange={e => setForm(f => ({ ...f, last_name: e.target.value }))} />
                </Field>
              </div>
              <Field label="Email">
                <input className={INPUT} type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} disabled={!!editUser} />
              </Field>
              <Field label={editUser ? "New password (leave blank to keep)" : "Password"}>
                <input className={INPUT} type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder={editUser ? "••••••••" : ""} />
              </Field>
              <Field label="Role">
                <select className={INPUT} value={form.role} onChange={e => setForm(f => ({ ...f, role: e.target.value as Role }))}>
                  {ROLES.map(r => <option key={r} value={r}>{ROLE_LABELS[r]}</option>)}
                </select>
              </Field>
              <Field label="NPI (optional)">
                <input className={INPUT} value={form.npi} onChange={e => setForm(f => ({ ...f, npi: e.target.value }))} placeholder="1234567890" />
              </Field>
              <Field label="Licensed States (HIPAA minimum necessary scope)">
                <div className="border border-slate-200 rounded-lg p-2 max-h-32 overflow-y-auto flex flex-wrap gap-1.5">
                  {US_STATES.map(s => {
                    const active = form.licensed_states.includes(s);
                    return (
                      <button
                        key={s}
                        type="button"
                        onClick={() => setForm(f => ({
                          ...f,
                          licensed_states: active
                            ? f.licensed_states.filter(x => x !== s)
                            : [...f.licensed_states, s],
                        }))}
                        className={`text-[11px] px-2 py-0.5 rounded font-mono font-semibold border transition-colors ${
                          active
                            ? "bg-blue-600 text-white border-blue-600"
                            : "bg-white text-slate-500 border-slate-200 hover:border-blue-300"
                        }`}
                      >
                        {s}
                      </button>
                    );
                  })}
                </div>
                <p className="text-[10px] text-slate-400 mt-1">AI chat will only show patients in these states. Leave empty for admin/billing roles (org-wide access).</p>
              </Field>
              {formError && <p className="text-xs text-red-600 bg-red-50 rounded px-3 py-2">{formError}</p>}
            </div>
            <div className="px-6 py-4 border-t border-slate-200 flex justify-end gap-2">
              <button onClick={() => setShowCreate(false)} className="px-4 py-2 text-sm text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50">
                Cancel
              </button>
              <button
                onClick={saveUser}
                disabled={saving}
                className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50"
              >
                {saving ? "Saving…" : editUser ? "Save changes" : "Create user"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Password reset modal */}
      {resetTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200">
              <h2 className="font-semibold text-slate-900 flex items-center gap-2">
                <Key className="w-4 h-4 text-amber-500" />
                Reset Password
              </h2>
              <button onClick={() => setResetTarget(null)} className="p-1 rounded hover:bg-slate-100">
                <X className="w-4 h-4 text-slate-400" />
              </button>
            </div>
            <div className="px-6 py-4 space-y-3">
              <p className="text-sm text-slate-600">Setting new password for <strong>{resetTarget.full_name}</strong></p>
              <input
                className={INPUT}
                type="password"
                placeholder="New password"
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
              />
            </div>
            <div className="px-6 py-4 border-t border-slate-200 flex justify-end gap-2">
              <button onClick={() => setResetTarget(null)} className="px-4 py-2 text-sm text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50">
                Cancel
              </button>
              <button
                onClick={savePasswordReset}
                disabled={!newPassword || resetSaving}
                className="px-4 py-2 text-sm bg-amber-500 text-white rounded-lg font-medium hover:bg-amber-600 disabled:opacity-50"
              >
                {resetSaving ? "Saving…" : "Reset password"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

const INPUT = "w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500";

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-xs font-medium text-slate-600 mb-1">{label}</label>
      {children}
    </div>
  );
}
