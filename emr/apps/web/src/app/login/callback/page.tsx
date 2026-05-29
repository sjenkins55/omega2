"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import axios from "axios";
import { handleMicrosoftCallback } from "@/lib/microsoft-auth";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

/**
 * Microsoft OAuth callback page.
 * Microsoft redirects here after the user authenticates.
 * This page exchanges the auth code for tokens, then exchanges the
 * ID token for a ConcertoCare JWT.
 */
export default function CallbackPage() {
  const router = useRouter();
  const [status, setStatus] = useState<"processing" | "error">("processing");
  const [error, setError] = useState("");

  useEffect(() => {
    async function complete() {
      try {
        // Exchange auth code for Microsoft tokens
        const { id_token } = await handleMicrosoftCallback();

        // Exchange Microsoft ID token for our JWT
        const res = await axios.post(`${BASE}/auth/microsoft`, { id_token });
        localStorage.setItem("token", res.data.access_token);
        localStorage.setItem("user", JSON.stringify(res.data.user));
        router.replace("/dashboard");
      } catch (err: unknown) {
        const msg = axios.isAxiosError(err)
          ? err.response?.data?.detail
          : err instanceof Error ? err.message : null;
        setError(msg ?? "Sign-in failed. Please try again.");
        setStatus("error");
      }
    }
    complete();
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-sm text-center">
        {status === "processing" ? (
          <>
            <div className="w-10 h-10 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-slate-700 font-medium">Signing you in…</p>
            <p className="text-slate-400 text-sm mt-1">Verifying your Microsoft account</p>
          </>
        ) : (
          <>
            <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-4">
              <span className="text-red-600 text-xl">!</span>
            </div>
            <p className="text-slate-900 font-semibold mb-2">Sign-in failed</p>
            <p className="text-red-600 text-sm mb-6">{error}</p>
            <a
              href="/login"
              className="inline-block px-6 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
            >
              Back to login
            </a>
          </>
        )}
      </div>
    </div>
  );
}
