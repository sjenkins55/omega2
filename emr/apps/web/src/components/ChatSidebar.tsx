"use client";
import { useState, useRef, useEffect, useCallback } from "react";
import { cn } from "@/lib/utils";
import { MessageSquare, X, Send, Loader2, MapPin, AlertTriangle, ChevronDown } from "lucide-react";

type ChatMessage = { role: "user" | "assistant"; content: string };
type Source = { type: string; id: string; name: string; mrn: string };

interface StreamEvent {
  type: "sources" | "text" | "error";
  text?: string;
  sources?: Source[];
  states?: string[];
  message?: string;
}

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

// Sample prompts to help clinicians get started
const QUICK_PROMPTS = [
  "Who are my highest risk patients right now?",
  "Any critical lab results I should know about?",
  "Which patients are due for recertification this month?",
  "Show me patients with unrecaptured HCC conditions",
];

export function ChatSidebar() {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState("");
  const [history, setHistory] = useState<ChatMessage[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [currentReply, setCurrentReply] = useState("");
  const [sources, setSources] = useState<Source[]>([]);
  const [licensedStates, setLicensedStates] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [history, currentReply]);

  const send = useCallback(async (messageText?: string) => {
    const text = (messageText ?? input).trim();
    if (!text || streaming) return;

    setInput("");
    setError(null);
    setSources([]);
    const userMsg: ChatMessage = { role: "user", content: text };
    const updatedHistory = [...history, userMsg];
    setHistory(updatedHistory);
    setStreaming(true);
    setCurrentReply("");

    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    const ctrl = new AbortController();
    abortRef.current = ctrl;

    try {
      const resp = await fetch(`${BASE_URL}/chat`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          message: text,
          history: updatedHistory.slice(-10).map((m) => ({ role: m.role, content: m.content })),
        }),
        signal: ctrl.signal,
      });

      if (!resp.ok) {
        const err = await resp.json().catch(() => ({}));
        throw new Error(err.detail ?? `Error ${resp.status}`);
      }

      const reader = resp.body?.getReader();
      const decoder = new TextDecoder();
      let reply = "";

      while (reader) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        for (const line of chunk.split("\n")) {
          if (!line.startsWith("data: ")) continue;
          const raw = line.slice(6).trim();
          if (raw === "[DONE]") break;
          try {
            const evt: StreamEvent = JSON.parse(raw);
            if (evt.type === "sources") {
              setSources(evt.sources ?? []);
              setLicensedStates(evt.states ?? []);
            } else if (evt.type === "text" && evt.text) {
              reply += evt.text;
              setCurrentReply(reply);
            } else if (evt.type === "error") {
              throw new Error(evt.message);
            }
          } catch (_) { /* ignore malformed events */ }
        }
      }

      setHistory([...updatedHistory, { role: "assistant", content: reply }]);
    } catch (err: unknown) {
      if ((err as { name?: string }).name !== "AbortError") {
        setError((err as Error).message ?? "Something went wrong");
      }
    } finally {
      setStreaming(false);
      setCurrentReply("");
    }
  }, [input, history, streaming]);

  const stop = () => {
    abortRef.current?.abort();
    if (currentReply) {
      setHistory((h) => [...h, { role: "assistant", content: currentReply }]);
    }
    setStreaming(false);
    setCurrentReply("");
  };

  return (
    <>
      {/* Toggle button */}
      <button
        onClick={() => setOpen((o) => !o)}
        className={cn(
          "fixed bottom-6 right-6 z-40 flex items-center gap-2 px-4 py-3 rounded-full shadow-lg text-sm font-medium transition-all",
          open
            ? "bg-gray-800 text-white"
            : "bg-blue-600 text-white hover:bg-blue-700"
        )}
      >
        <MessageSquare className="w-4 h-4" />
        {open ? "Close" : "Ask AI"}
      </button>

      {/* Sidebar panel */}
      <div
        className={cn(
          "fixed right-0 top-0 h-full w-[420px] bg-white shadow-2xl border-l border-gray-200 flex flex-col z-30 transition-transform duration-200",
          open ? "translate-x-0" : "translate-x-full"
        )}
      >
        {/* Header */}
        <div className="px-4 py-3 border-b border-gray-100 flex items-center justify-between shrink-0">
          <div>
            <h2 className="font-semibold text-gray-900 flex items-center gap-2">
              <MessageSquare className="w-4 h-4 text-blue-600" />
              Clinical AI Assistant
            </h2>
            {licensedStates.length > 0 && (
              <div className="flex items-center gap-1 mt-0.5">
                <MapPin className="w-3 h-3 text-gray-400" />
                <span className="text-xs text-gray-500">
                  Scoped to: <span className="font-medium text-gray-700">{licensedStates.join(", ")}</span>
                </span>
              </div>
            )}
          </div>
          <button onClick={() => setOpen(false)} className="p-1 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* HIPAA notice */}
        <div className="mx-3 mt-3 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg shrink-0">
          <p className="text-xs text-amber-700 flex items-start gap-1.5">
            <AlertTriangle className="w-3.5 h-3.5 shrink-0 mt-0.5" />
            Responses are limited to patients in your licensed state(s). Do not share this session — it contains PHI.
          </p>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
          {history.length === 0 && !streaming && (
            <div>
              <p className="text-sm text-gray-400 mb-3">Ask anything about your patients:</p>
              <div className="space-y-2">
                {QUICK_PROMPTS.map((p) => (
                  <button
                    key={p}
                    onClick={() => send(p)}
                    className="w-full text-left text-sm px-3 py-2 bg-gray-50 hover:bg-blue-50 hover:text-blue-700 border border-gray-200 hover:border-blue-200 rounded-lg transition-colors"
                  >
                    {p}
                  </button>
                ))}
              </div>
            </div>
          )}

          {history.map((m, i) => (
            <div key={i} className={cn("flex", m.role === "user" ? "justify-end" : "justify-start")}>
              <div
                className={cn(
                  "max-w-[85%] rounded-2xl px-4 py-2.5 text-sm",
                  m.role === "user"
                    ? "bg-blue-600 text-white rounded-tr-sm"
                    : "bg-gray-100 text-gray-800 rounded-tl-sm"
                )}
              >
                <p className="whitespace-pre-wrap leading-relaxed">{m.content}</p>
              </div>
            </div>
          ))}

          {/* Streaming reply */}
          {streaming && (
            <div className="flex justify-start">
              <div className="max-w-[85%] bg-gray-100 text-gray-800 rounded-2xl rounded-tl-sm px-4 py-2.5 text-sm">
                {currentReply ? (
                  <p className="whitespace-pre-wrap leading-relaxed">{currentReply}<span className="inline-block w-1.5 h-4 bg-gray-400 animate-pulse ml-0.5 align-text-bottom" /></p>
                ) : (
                  <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
                )}
              </div>
            </div>
          )}

          {/* Error */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-sm text-red-700">
              {error}
            </div>
          )}

          {/* Sources */}
          {sources.length > 0 && !streaming && (
            <details className="text-xs text-gray-400 cursor-pointer">
              <summary className="flex items-center gap-1 select-none hover:text-gray-600">
                <ChevronDown className="w-3 h-3" />
                {sources.length} patient record{sources.length !== 1 ? "s" : ""} referenced
              </summary>
              <div className="mt-1 space-y-0.5 pl-4">
                {sources.map((s) => (
                  <div key={s.id}>{s.name} ({s.mrn})</div>
                ))}
              </div>
            </details>
          )}

          <div ref={bottomRef} />
        </div>

        {/* Input */}
        <div className="px-4 py-3 border-t border-gray-100 shrink-0">
          {history.length > 0 && (
            <button
              onClick={() => { setHistory([]); setSources([]); setError(null); }}
              className="text-xs text-gray-400 hover:text-gray-600 mb-2 block"
            >
              Clear conversation
            </button>
          )}
          <div className="flex items-end gap-2">
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }}
              placeholder="Ask about patients, conditions, labs…"
              rows={2}
              className="flex-1 text-sm border border-gray-200 rounded-xl px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={streaming}
            />
            {streaming ? (
              <button
                onClick={stop}
                className="p-2.5 rounded-xl bg-red-500 text-white hover:bg-red-600 shrink-0"
              >
                <X className="w-4 h-4" />
              </button>
            ) : (
              <button
                onClick={() => send()}
                disabled={!input.trim()}
                className="p-2.5 rounded-xl bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-40 shrink-0"
              >
                <Send className="w-4 h-4" />
              </button>
            )}
          </div>
          <p className="text-[10px] text-gray-300 mt-1.5 text-center">Shift+Enter for new line · Enter to send</p>
        </div>
      </div>
    </>
  );
}
