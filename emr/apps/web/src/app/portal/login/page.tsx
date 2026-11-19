"use client";
import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import axios from "axios";
import { Heart } from "lucide-react";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

export default function PortalLoginPage() {
  const router = useRouter();
  const [mrn, setMrn] = useState("");
  const [dob, setDob] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await axios.post(`${BASE}/auth/portal/login`, {
        mrn: mrn.trim(),
        date_of_birth: dob,
      });
      localStorage.setItem("portal_token", res.data.access_token);
      localStorage.setItem("portal_patient", JSON.stringify(res.data.patient));
      router.push("/portal");
    } catch (err: unknown) {
      const msg = axios.isAxiosError(err) ? err.response?.data?.detail : null;
      setError(msg ?? "We couldn't find a match. Please check your MRN and date of birth.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-slate-100 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-3 mb-8">
          <div className="w-12 h-12 rounded-2xl bg-blue-500 flex items-center justify-center shadow-lg">
            <Heart className="w-6 h-6 text-white" />
          </div>
          <div>
            <div className="text-slate-900 font-bold text-xl">My Health Portal</div>
            <div className="text-slate-500 text-sm">ConcertoCare</div>
          </div>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <h1 className="text-xl font-semibold text-slate-900 mb-1">Welcome back</h1>
          <p className="text-sm text-slate-500 mb-6">
            Sign in with your Medical Record Number and date of birth.
          </p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Medical Record Number (MRN)
              </label>
              <input
                type="text"
                required
                value={mrn}
                onChange={e => setMrn(e.target.value)}
                placeholder="e.g. MRN-00001"
                className="w-full px-3 py-2.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p className="text-xs text-slate-400 mt-1">Found on your welcome letter or insurance card</p>
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Date of Birth</label>
              <input
                type="date"
                required
                value={dob}
                onChange={e => setDob(e.target.value)}
                className="w-full px-3 py-2.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            {error && (
              <div className="text-xs text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50 shadow-sm"
            >
              {loading ? "Looking you up…" : "Sign in to my portal"}
            </button>
          </form>

          <p className="mt-6 text-center text-xs text-slate-400">
            Need help? Call your care team or visit{" "}
            <span className="text-blue-500">concertocare.com</span>
          </p>
        </div>

        <div className="mt-4 text-center">
          <a href="/login" className="text-xs text-slate-400 hover:text-slate-600 transition-colors">
            Staff? Sign in here →
          </a>
        </div>
      </div>
    </div>
  );
}
