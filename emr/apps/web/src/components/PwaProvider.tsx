"use client";

import { useEffect, useState } from "react";
import { Download, X } from "lucide-react";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

const DISMISS_KEY = "pwa_install_dismissed";

export function PwaProvider() {
  const [installEvent, setInstallEvent] = useState<BeforeInstallPromptEvent | null>(null);
  const [showBanner, setShowBanner] = useState(false);

  useEffect(() => {
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // Registration can fail in unsupported/private contexts — app works fine without it
      });
    }

    const onBeforeInstall = (e: Event) => {
      e.preventDefault();
      setInstallEvent(e as BeforeInstallPromptEvent);
      if (typeof window !== "undefined" && !localStorage.getItem(DISMISS_KEY)) {
        setShowBanner(true);
      }
    };
    const onInstalled = () => {
      setInstallEvent(null);
      setShowBanner(false);
    };

    window.addEventListener("beforeinstallprompt", onBeforeInstall);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onBeforeInstall);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  const install = async () => {
    if (!installEvent) return;
    await installEvent.prompt();
    const choice = await installEvent.userChoice;
    if (choice.outcome === "accepted") setInstallEvent(null);
    setShowBanner(false);
  };

  const dismiss = () => {
    setShowBanner(false);
    localStorage.setItem(DISMISS_KEY, "1");
  };

  if (!showBanner || !installEvent) return null;

  return (
    <div className="fixed bottom-4 left-4 z-50 flex items-center gap-3 rounded-xl bg-white px-4 py-3 shadow-lg ring-1 ring-gray-200">
      <img src="/icons/icon-192.png" alt="" className="h-9 w-9 rounded-lg" />
      <div className="mr-2">
        <p className="text-sm font-semibold text-gray-900">Install ConcertoCare</p>
        <p className="text-xs text-gray-500">Add to your desktop for quick access</p>
      </div>
      <button
        onClick={install}
        className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700"
      >
        <Download className="h-3.5 w-3.5" />
        Install
      </button>
      <button onClick={dismiss} className="rounded p-1 text-gray-400 hover:text-gray-600" aria-label="Dismiss">
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
