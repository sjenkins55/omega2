"use client";
import { useState, useEffect, useMemo } from "react";
import { MapPin, Users, ChevronRight, CheckSquare, Square, Search, RefreshCw } from "lucide-react";

const API = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

const PROVIDER_COLORS = [
  "bg-blue-100 text-blue-800 border-blue-200",
  "bg-emerald-100 text-emerald-800 border-emerald-200",
  "bg-violet-100 text-violet-800 border-violet-200",
  "bg-amber-100 text-amber-800 border-amber-200",
  "bg-rose-100 text-rose-800 border-rose-200",
  "bg-cyan-100 text-cyan-800 border-cyan-200",
  "bg-orange-100 text-orange-800 border-orange-200",
  "bg-teal-100 text-teal-800 border-teal-200",
];

type Territory = {
  zip_code: string;
  patient_count: number;
  provider_id: string | null;
  provider_name: string | null;
  provider_role: string | null;
};

type Provider = {
  id: string;
  full_name: string;
  role: string;
  is_active: boolean;
};

type ZipPatient = {
  id: string;
  name: string;
  mrn: string;
  status: string;
  ai_risk_score: number | null;
  primary_dx: string | null;
  address: Record<string, string> | null;
};

export default function TerritoriesPage() {
  const [territories, setTerritories] = useState<Territory[]>([]);
  const [providers, setProviders] = useState<Provider[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedZips, setSelectedZips] = useState<Set<string>>(new Set());
  const [activeZip, setActiveZip] = useState<string | null>(null);
  const [zipPatients, setZipPatients] = useState<ZipPatient[]>([]);
  const [patientsLoading, setPatientsLoading] = useState(false);
  const [assigningTo, setAssigningTo] = useState<string>("");
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState<"map" | "list">("list");

  useEffect(() => { load(); }, []);

  function authHeaders(extra?: Record<string, string>): Record<string, string> {
    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    return { Authorization: `Bearer ${token}`, ...extra };
  }

  async function load() {
    setLoading(true);
    try {
      const res = await fetch(`${API}/admin/territories`, {
        headers: authHeaders(),
      });
      const data = await res.json();
      setTerritories(data.territories ?? []);
      setProviders((data.providers ?? []).filter((p: Provider) => p.is_active));
    } finally {
      setLoading(false);
    }
  }

  async function loadZipPatients(zip: string) {
    setActiveZip(zip);
    setPatientsLoading(true);
    try {
      const res = await fetch(`${API}/admin/territories/${zip}/patients`, {
        headers: authHeaders(),
      });
      const data = await res.json();
      setZipPatients(data.patients ?? []);
    } finally {
      setPatientsLoading(false);
    }
  }

  async function assignSelected() {
    if (!selectedZips.size) return;
    setSaving(true);
    try {
      await fetch(`${API}/admin/territories/assign`, {
        method: "PATCH",
        headers: authHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({
          zip_codes: Array.from(selectedZips),
          provider_id: assigningTo || null,
        }),
      });
      setSelectedZips(new Set());
      setAssigningTo("");
      await load();
    } finally {
      setSaving(false);
    }
  }

  const providerColorMap = useMemo(() => {
    const map: Record<string, string> = {};
    providers.forEach((p, i) => { map[p.id] = PROVIDER_COLORS[i % PROVIDER_COLORS.length]; });
    return map;
  }, [providers]);

  const filtered = territories.filter(t =>
    t.zip_code.includes(search) ||
    (t.provider_name ?? "").toLowerCase().includes(search.toLowerCase())
  );

  // Group by provider for territory view
  const byProvider = useMemo(() => {
    const map: Record<string, { provider: Provider | null; zips: Territory[] }> = {
      unassigned: { provider: null, zips: [] },
    };
    providers.forEach(p => { map[p.id] = { provider: p, zips: [] }; });
    territories.forEach(t => {
      const key = t.provider_id ?? "unassigned";
      if (!map[key]) map[key] = { provider: null, zips: [] };
      map[key].zips.push(t);
    });
    return map;
  }, [territories, providers]);

  const toggleZip = (zip: string) => {
    setSelectedZips(prev => {
      const next = new Set(prev);
      if (next.has(zip)) next.delete(zip);
      else next.add(zip);
      return next;
    });
  };

  const selectAll = () => setSelectedZips(new Set(filtered.map(t => t.zip_code)));
  const clearAll = () => setSelectedZips(new Set());

  return (
    <div className="flex gap-0" style={{ minHeight: "calc(100vh - 56px)" }}>
      {/* Left panel */}
      <div className="flex flex-col w-[480px] border-r border-slate-200 shrink-0" style={{ minHeight: "calc(100vh - 56px)" }}>
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-200 bg-white">
          <div className="flex items-center justify-between mb-3">
            <div>
              <h1 className="text-lg font-semibold text-slate-900">Territory Map</h1>
              <p className="text-xs text-slate-500 mt-0.5">Assign zip codes to providers</p>
            </div>
            <button onClick={load} className="p-1.5 rounded hover:bg-slate-100 text-slate-500">
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-2.5 w-4 h-4 text-slate-400" />
            <input
              className="w-full pl-9 pr-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Search zip code or provider…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
          {/* Tab */}
          <div className="flex gap-1 mt-3 bg-slate-100 rounded-lg p-0.5">
            {(["list", "map"] as const).map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`flex-1 py-1.5 text-xs font-medium rounded-md transition-colors capitalize ${
                  activeTab === tab ? "bg-white shadow-sm text-slate-900" : "text-slate-500 hover:text-slate-700"
                }`}
              >
                {tab === "list" ? "Zip Code List" : "Territory View"}
              </button>
            ))}
          </div>
        </div>

        {/* Bulk assign bar */}
        {selectedZips.size > 0 && (
          <div className="px-4 py-2 bg-blue-50 border-b border-blue-100 flex items-center gap-2 flex-wrap">
            <span className="text-xs font-medium text-blue-700">{selectedZips.size} zip{selectedZips.size > 1 ? "s" : ""} selected</span>
            <select
              className="flex-1 text-xs border border-blue-200 rounded px-2 py-1 bg-white focus:outline-none"
              value={assigningTo}
              onChange={e => setAssigningTo(e.target.value)}
            >
              <option value="">— Unassign —</option>
              {providers.map(p => (
                <option key={p.id} value={p.id}>{p.full_name} ({p.role})</option>
              ))}
            </select>
            <button
              onClick={assignSelected}
              disabled={saving}
              className="px-3 py-1 bg-blue-600 text-white text-xs rounded font-medium disabled:opacity-50 hover:bg-blue-700"
            >
              {saving ? "Saving…" : "Assign"}
            </button>
            <button onClick={clearAll} className="text-xs text-blue-600 hover:underline">Clear</button>
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {loading ? (
            <div className="flex items-center justify-center h-32 text-slate-400 text-sm">Loading…</div>
          ) : activeTab === "list" ? (
            <>
              <div className="px-4 py-2 flex items-center justify-between border-b border-slate-100">
                <span className="text-xs text-slate-500">{filtered.length} zip codes</span>
                <button onClick={selectAll} className="text-xs text-blue-600 hover:underline">Select all</button>
              </div>
              {filtered.map(t => {
                const isSelected = selectedZips.has(t.zip_code);
                const isActive = activeZip === t.zip_code;
                const colorClass = t.provider_id ? providerColorMap[t.provider_id] : "bg-slate-100 text-slate-500 border-slate-200";
                return (
                  <div
                    key={t.zip_code}
                    onClick={() => { toggleZip(t.zip_code); loadZipPatients(t.zip_code); }}
                    className={`flex items-center gap-3 px-4 py-3 cursor-pointer border-b border-slate-100 hover:bg-slate-50 transition-colors ${
                      isActive ? "bg-blue-50" : ""
                    }`}
                  >
                    <div className="shrink-0 text-slate-400">
                      {isSelected ? <CheckSquare className="w-4 h-4 text-blue-600" /> : <Square className="w-4 h-4" />}
                    </div>
                    <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center shrink-0">
                      <MapPin className="w-4 h-4 text-slate-500" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-semibold text-sm text-slate-900">{t.zip_code}</span>
                        <span className={`text-xs px-2 py-0.5 rounded-full border font-medium ${colorClass}`}>
                          {t.provider_name ?? "Unassigned"}
                        </span>
                      </div>
                      <div className="flex items-center gap-1 mt-0.5">
                        <Users className="w-3 h-3 text-slate-400" />
                        <span className="text-xs text-slate-500">{t.patient_count} patient{t.patient_count !== 1 ? "s" : ""}</span>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-300 shrink-0" />
                  </div>
                );
              })}
            </>
          ) : (
            /* Territory view — grouped by provider */
            <div className="p-4 space-y-4">
              {providers.map((p, i) => {
                const entry = byProvider[p.id];
                if (!entry || entry.zips.length === 0) return null;
                const color = PROVIDER_COLORS[i % PROVIDER_COLORS.length];
                const total = entry.zips.reduce((sum, z) => sum + z.patient_count, 0);
                return (
                  <div key={p.id} className={`rounded-lg border p-4 ${color}`}>
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <div className="font-semibold text-sm">{p.full_name}</div>
                        <div className="text-xs opacity-70 capitalize">{p.role.replace("_", " ")}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-lg font-bold">{total}</div>
                        <div className="text-xs opacity-70">patients</div>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                      {entry.zips.map(z => (
                        <button
                          key={z.zip_code}
                          onClick={() => loadZipPatients(z.zip_code)}
                          className="font-mono text-xs px-2 py-1 bg-white/60 rounded border border-current/20 hover:bg-white/80 transition-colors"
                        >
                          {z.zip_code}
                          <span className="ml-1 opacity-60">({z.patient_count})</span>
                        </button>
                      ))}
                    </div>
                  </div>
                );
              })}
              {byProvider.unassigned?.zips.length > 0 && (
                <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
                  <div className="font-semibold text-sm text-slate-600 mb-3">Unassigned</div>
                  <div className="flex flex-wrap gap-1.5">
                    {byProvider.unassigned.zips.map(z => (
                      <button
                        key={z.zip_code}
                        onClick={() => { toggleZip(z.zip_code); loadZipPatients(z.zip_code); }}
                        className="font-mono text-xs px-2 py-1 bg-white rounded border border-slate-200 hover:bg-slate-100 transition-colors text-slate-600"
                      >
                        {z.zip_code}
                        <span className="ml-1 text-slate-400">({z.patient_count})</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Right panel — patients in selected zip */}
      <div className="flex-1 flex flex-col bg-slate-50">
        {activeZip ? (
          <>
            <div className="px-6 py-4 bg-white border-b border-slate-200">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="font-semibold text-slate-900 flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-slate-400" />
                    Zip Code {activeZip}
                  </h2>
                  <p className="text-xs text-slate-500 mt-0.5">
                    {patientsLoading ? "Loading…" : `${zipPatients.length} patient${zipPatients.length !== 1 ? "s" : ""}`}
                  </p>
                </div>
                {/* Quick assign for this zip */}
                <div className="flex items-center gap-2">
                  <select
                    className="text-xs border border-slate-200 rounded px-2 py-1.5 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                    onChange={async e => {
                      if (!e.target.value) return;
                      setSaving(true);
                      try {
                        await fetch(`${API}/admin/territories/assign`, {
                          method: "PATCH",
                          headers: authHeaders({ "Content-Type": "application/json" }),
                          body: JSON.stringify({ zip_codes: [activeZip], provider_id: e.target.value || null }),
                        });
                        await load();
                      } finally { setSaving(false); e.target.value = ""; }
                    }}
                  >
                    <option value="">Assign to provider…</option>
                    <option value="">— Unassign —</option>
                    {providers.map(p => (
                      <option key={p.id} value={p.id}>{p.full_name}</option>
                    ))}
                  </select>
                </div>
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-6">
              {patientsLoading ? (
                <div className="text-center text-slate-400 text-sm mt-16">Loading patients…</div>
              ) : zipPatients.length === 0 ? (
                <div className="text-center text-slate-400 text-sm mt-16">
                  <Users className="w-10 h-10 mx-auto mb-3 opacity-30" />
                  No patients with this zip code yet.
                </div>
              ) : (
                <div className="space-y-2">
                  {zipPatients.map(p => (
                    <div key={p.id} className="bg-white rounded-lg border border-slate-200 p-4 flex items-center gap-4 hover:border-blue-300 transition-colors">
                      <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-semibold text-sm shrink-0">
                        {p.name.split(" ").map(n => n[0]).join("").slice(0, 2)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-sm text-slate-900">{p.name}</span>
                          <span className={`text-xs px-2 py-0.5 rounded-full ${
                            p.status === "active" ? "bg-green-100 text-green-700" :
                            p.status === "discharged" ? "bg-slate-100 text-slate-600" :
                            "bg-amber-100 text-amber-700"
                          }`}>{p.status}</span>
                        </div>
                        <div className="text-xs text-slate-500 mt-0.5">
                          MRN: {p.mrn}
                          {p.primary_dx && <span className="ml-2">· {p.primary_dx}</span>}
                        </div>
                      </div>
                      {p.ai_risk_score != null && (
                        <div className={`text-xs font-semibold px-2 py-1 rounded-full ${
                          p.ai_risk_score >= 0.7 ? "bg-red-100 text-red-700" :
                          p.ai_risk_score >= 0.4 ? "bg-amber-100 text-amber-700" :
                          "bg-green-100 text-green-700"
                        }`}>
                          Risk {Math.round(p.ai_risk_score * 100)}%
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-center">
            <div>
              <MapPin className="w-12 h-12 text-slate-200 mx-auto mb-4" />
              <p className="text-slate-500 font-medium">Select a zip code</p>
              <p className="text-slate-400 text-sm mt-1">Click any zip to see its patients and assign a provider</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
