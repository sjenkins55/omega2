"use client";
import { useState, useEffect, FormEvent } from "react";
import { useRouter } from "next/navigation";
import axios from "axios";
import { microsoftLogin, isMicrosoftSSOEnabled } from "@/lib/microsoft-auth";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

function MicrosoftIcon() {
  return (
    <svg viewBox="0 0 21 21" className="w-4 h-4 shrink-0" fill="none">
      <rect x="1"  y="1"  width="9" height="9" fill="#F25022"/>
      <rect x="11" y="1"  width="9" height="9" fill="#7FBA00"/>
      <rect x="1"  y="11" width="9" height="9" fill="#00A4EF"/>
      <rect x="11" y="11" width="9" height="9" fill="#FFB900"/>
    </svg>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [msLoading, setMsLoading] = useState(false);
  const [ssoEnabled, setSsoEnabled] = useState(false);

  useEffect(() => {
    setSsoEnabled(isMicrosoftSSOEnabled());
    // If already logged in, redirect away
    if (typeof window !== "undefined" && localStorage.getItem("token")) {
      router.replace("/dashboard");
    }
  }, [router]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await axios.post(`${BASE}/auth/login`, { email, password });
      localStorage.setItem("token", res.data.access_token);
      localStorage.setItem("user", JSON.stringify(res.data.user));
      router.push("/dashboard");
    } catch (err: unknown) {
      const msg = axios.isAxiosError(err) ? err.response?.data?.detail : null;
      setError(msg ?? "Login failed. Please check your credentials.");
    } finally {
      setLoading(false);
    }
  }

  async function handleMicrosoftLogin() {
    setMsLoading(true);
    setError("");
    try {
      await microsoftLogin(); // redirects — execution stops here
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Microsoft sign-in failed");
      setMsLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-3 mb-8">
          <div className="w-10 h-10 rounded-xl bg-blue-500 flex items-center justify-center text-white font-bold text-sm">CC</div>
          <div>
            <div className="text-white font-semibold text-lg leading-tight">ConcertoCare</div>
            <div className="text-slate-400 text-xs">Electronic Medical Record</div>
          </div>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h1 className="text-xl font-semibold text-slate-900 mb-1">Sign in</h1>
          <p className="text-sm text-slate-500 mb-6">Use your work credentials to continue</p>

          {/* Microsoft SSO button */}
          {ssoEnabled && (
            <>
              <button
                type="button"
                onClick={handleMicrosoftLogin}
                disabled={msLoading}
                className="w-full flex items-center justify-center gap-3 py-2.5 border border-slate-200 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-50 mb-4"
              >
                <MicrosoftIcon />
                {msLoading ? "Redirecting to Microsoft…" : "Sign in with Microsoft"}
              </button>

              <div className="relative mb-4">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-slate-200" />
                </div>
                <div className="relative flex justify-center">
                  <span className="bg-white px-3 text-xs text-slate-400">or sign in with password</span>
                </div>
              </div>
            </>
          )}

          {/* Email / password form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Email</label>
              <input
                type="email"
                required
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="you@concertocare.com"
                className="w-full px-3 py-2.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Password</label>
              <input
                type="password"
                required
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="••••••••"
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
              className="w-full py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
            >
              {loading ? "Signing in…" : "Sign in"}
            </button>
          </form>

          <div className="mt-6 pt-5 border-t border-slate-100 text-center">
            <a href="/portal/login" className="text-xs text-slate-400 hover:text-blue-600 transition-colors">
              Patient? Access your portal →
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
