"use client";

import { useState } from "react";
import type { Deadline } from "@/db/schema";

const PRIORITY_STYLES: Record<string, string> = {
  high: "bg-red-50 text-red-600 border-red-200",
  medium: "bg-yellow-50 text-yellow-600 border-yellow-200",
  low: "bg-gray-50 text-gray-500 border-gray-200",
};

interface DeadlinesPanelProps {
  deadlines: Deadline[];
  onUpdate: () => void;
}

export function DeadlinesPanel({ deadlines, onUpdate }: DeadlinesPanelProps) {
  const [title, setTitle] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<"low" | "medium" | "high">("medium");
  const [submitting, setSubmitting] = useState(false);

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!title || !dueDate) return;
    setSubmitting(true);
    try {
      await fetch("/api/deadlines", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, dueDate, description, priority }),
      });
      setTitle("");
      setDueDate("");
      setDescription("");
      setPriority("medium");
      onUpdate();
    } finally {
      setSubmitting(false);
    }
  }

  async function handleComplete(id: string) {
    await fetch(`/api/deadlines/${id}`, { method: "DELETE" });
    onUpdate();
  }

  return (
    <div className="flex flex-col gap-4">
      <form onSubmit={handleAdd} className="bg-white border border-gray-200 rounded-xl p-4 shadow-sm">
        <h3 className="font-semibold text-gray-700 mb-3 text-sm uppercase tracking-wide">
          Add deadline
        </h3>
        <input
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm mb-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
          placeholder="Deadline title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
        <input
          type="datetime-local"
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm mb-2 focus:outline-none focus:ring-2 focus:ring-indigo-400"
          value={dueDate}
          onChange={(e) => setDueDate(e.target.value)}
          required
        />
        <textarea
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm mb-2 resize-none focus:outline-none focus:ring-2 focus:ring-indigo-400"
          placeholder="Description (optional)"
          rows={2}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="flex gap-2 mb-3">
          {(["low", "medium", "high"] as const).map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => setPriority(p)}
              className={`flex-1 text-xs font-medium rounded-lg py-1.5 border transition-colors capitalize ${
                priority === p
                  ? PRIORITY_STYLES[p]
                  : "border-gray-200 text-gray-400 hover:border-gray-300"
              }`}
            >
              {p}
            </button>
          ))}
        </div>
        <button
          type="submit"
          disabled={submitting}
          className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-sm font-medium rounded-lg py-2 transition-colors"
        >
          {submitting ? "Adding…" : "Add deadline"}
        </button>
      </form>

      <div className="flex flex-col gap-2">
        {deadlines.length === 0 && (
          <p className="text-sm text-gray-400 text-center py-4">No upcoming deadlines.</p>
        )}
        {deadlines.map((d) => {
          const due = new Date(d.dueDate);
          const hoursUntil = (due.getTime() - Date.now()) / 1000 / 3600;
          const urgent = hoursUntil < 24;
          return (
            <div
              key={d.id}
              className={`bg-white border rounded-xl p-3 shadow-sm ${
                urgent ? "border-red-300 ring-1 ring-red-100" : "border-gray-200"
              }`}
            >
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="font-medium text-sm text-gray-800">{d.title}</p>
                  <p className={`text-xs mt-0.5 ${urgent ? "text-red-500 font-medium" : "text-gray-400"}`}>
                    Due {due.toLocaleString()}
                  </p>
                  {d.description && (
                    <p className="text-xs text-gray-400 mt-1">{d.description}</p>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span
                    className={`text-xs px-2 py-0.5 rounded-full border font-medium capitalize ${PRIORITY_STYLES[d.priority ?? "medium"]}`}
                  >
                    {d.priority}
                  </span>
                  <button
                    onClick={() => handleComplete(d.id)}
                    className="text-gray-300 hover:text-green-500 transition-colors text-lg leading-none"
                    aria-label="Mark complete"
                    title="Mark complete"
                  >
                    ✓
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
