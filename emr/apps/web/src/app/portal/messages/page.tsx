"use client";
import { useEffect, useState, useRef } from "react";
import { portalApi } from "@/lib/api";
import { Send, MessageSquare } from "lucide-react";

type Message = {
  id: string;
  direction: "patient" | "staff";
  sender_name: string;
  content: string;
  is_read: boolean;
  created_at: string;
};

export default function PortalMessages() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  async function load() {
    const res = await portalApi.get("/portal/messages");
    setMessages(res.data.messages ?? []);
  }

  useEffect(() => {
    load().finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function send() {
    if (!input.trim() || sending) return;
    setSending(true);
    try {
      await portalApi.post("/portal/messages", { content: input.trim() });
      setInput("");
      await load();
    } finally {
      setSending(false);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); }
  }

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-slate-400 text-sm">Loading messages…</div>
    </div>
  );

  return (
    <div className="flex flex-col max-w-lg mx-auto" style={{ height: "calc(100vh - 120px)" }}>
      {/* Header */}
      <div className="px-4 py-4 border-b border-slate-200 bg-white">
        <h1 className="text-lg font-bold text-slate-900">Messages</h1>
        <p className="text-xs text-slate-500 mt-0.5">Secure messages with your care team</p>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
        {messages.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-48 text-center">
            <MessageSquare className="w-12 h-12 text-slate-200 mb-3" />
            <p className="text-slate-500 font-medium text-sm">No messages yet</p>
            <p className="text-slate-400 text-xs mt-1">Send a message to your care team below</p>
          </div>
        ) : (
          <>
            <div className="text-center">
              <span className="text-xs text-slate-400 bg-slate-100 px-3 py-1 rounded-full">
                Messages are reviewed during business hours
              </span>
            </div>
            {messages.map(m => {
              const isMe = m.direction === "patient";
              return (
                <div key={m.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[80%] ${isMe ? "items-end" : "items-start"} flex flex-col gap-1`}>
                    {!isMe && (
                      <span className="text-xs text-slate-500 px-1">{m.sender_name}</span>
                    )}
                    <div className={`rounded-2xl px-4 py-2.5 text-sm ${
                      isMe
                        ? "bg-blue-600 text-white rounded-tr-sm"
                        : "bg-white border border-slate-200 text-slate-800 rounded-tl-sm"
                    }`}>
                      {m.content}
                    </div>
                    <span className="text-xs text-slate-400 px-1">
                      {new Date(m.created_at).toLocaleTimeString("en-US", {
                        hour: "numeric", minute: "2-digit",
                      })}
                      {" · "}
                      {new Date(m.created_at).toLocaleDateString("en-US", {
                        month: "short", day: "numeric",
                      })}
                    </span>
                  </div>
                </div>
              );
            })}
            <div ref={bottomRef} />
          </>
        )}
      </div>

      {/* Input */}
      <div className="px-4 py-3 border-t border-slate-200 bg-white">
        <div className="flex items-end gap-2">
          <textarea
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Message your care team…"
            rows={1}
            className="flex-1 px-4 py-2.5 text-sm border border-slate-200 rounded-2xl resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 max-h-28"
            style={{ minHeight: "42px" }}
          />
          <button
            onClick={send}
            disabled={!input.trim() || sending}
            className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white hover:bg-blue-700 transition-colors disabled:opacity-40 shrink-0"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
        <p className="text-xs text-slate-400 mt-1.5 text-center">
          Not for emergencies — call 911 if you need immediate help
        </p>
      </div>
    </div>
  );
}
