"use client";

import { useState } from "react";
import type { Message } from "@/db/schema";

const STATUS_BADGE: Record<string, string> = {
  pending: "bg-gray-100 text-gray-600",
  classified: "bg-green-100 text-green-700",
  classification_failed: "bg-red-100 text-red-700",
  ignored: "bg-gray-100 text-gray-400",
};

const STATUS_LABEL: Record<string, string> = {
  pending: "Processing…",
  classified: "Classified",
  classification_failed: "Failed",
  ignored: "Ignored",
};

interface InboxPanelProps {
  messages: Message[];
  onMessageSent: () => void;
}

export function InboxPanel({ messages, onMessageSent }: InboxPanelProps) {
  const [sender, setSender] = useState("");
  const [body, setBody] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!sender.trim() || !body.trim()) return;
    setSubmitting(true);
    try {
      await fetch("/api/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sender: sender.trim(), recipient: "You", messageBody: body.trim() }),
      });
      setSender("");
      setBody("");
      onMessageSent();
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-gray-200 p-4 shadow-sm">
        <h3 className="font-semibold text-gray-700 mb-3 text-sm uppercase tracking-wide">
          Simulate a message
        </h3>
        <div className="flex gap-2 mb-2">
          <input
            className="border border-gray-300 rounded-lg px-3 py-2 text-sm flex-1 focus:outline-none focus:ring-2 focus:ring-indigo-400"
            placeholder="Sender name"
            value={sender}
            onChange={(e) => setSender(e.target.value)}
            required
          />
        </div>
        <textarea
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-400"
          placeholder='e.g. "sounds good, see you at 7"'
          rows={3}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          required
        />
        <button
          type="submit"
          disabled={submitting}
          className="mt-2 w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-sm font-medium rounded-lg py-2 transition-colors"
        >
          {submitting ? "Sending…" : "Send message"}
        </button>
      </form>

      <div className="flex flex-col gap-2 max-h-[60vh] overflow-y-auto pr-1">
        {messages.length === 0 && (
          <p className="text-sm text-gray-400 text-center py-6">No messages yet.</p>
        )}
        {messages.map((m) => (
          <div
            key={m.id}
            className="bg-white border border-gray-200 rounded-xl p-3 shadow-sm hover:shadow transition-shadow"
          >
            <div className="flex items-center justify-between mb-1">
              <span className="font-medium text-sm text-gray-800">{m.sender}</span>
              <span
                className={`text-xs px-2 py-0.5 rounded-full font-medium ${STATUS_BADGE[m.status] ?? "bg-gray-100 text-gray-500"}`}
              >
                {STATUS_LABEL[m.status] ?? m.status}
              </span>
            </div>
            <p className="text-sm text-gray-600 leading-snug">{m.body}</p>
            <p className="text-xs text-gray-400 mt-1">
              {new Date(m.receivedAt).toLocaleString()}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
