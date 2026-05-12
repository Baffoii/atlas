"use client";

import { useState } from "react";
import type { PendingEvent } from "@/db/schema";

const CONFIDENCE_LABEL = (c: number) =>
  c >= 0.85 ? "High" : c >= 0.5 ? "Medium" : "Low";

const CONFIDENCE_COLOR = (c: number) =>
  c >= 0.85
    ? "text-green-600 bg-green-50"
    : c >= 0.5
    ? "text-yellow-600 bg-yellow-50"
    : "text-gray-500 bg-gray-50";

interface PendingReviewPanelProps {
  pendingEvents: PendingEvent[];
  onUpdate: () => void;
  onToast: (msg: Omit<import("@/components/Toast").ToastData, "id">) => void;
}

export function PendingReviewPanel({
  pendingEvents,
  onUpdate,
  onToast,
}: PendingReviewPanelProps) {
  const [loading, setLoading] = useState<string | null>(null);

  async function handleAction(id: string, action: "approve" | "dismiss") {
    setLoading(id);
    try {
      const res = await fetch(`/api/pending-events/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action }),
      });
      const data = await res.json();

      if (res.status === 409) {
        // Conflict
        const conflictNames = (data.conflicts as Array<{ title: string; startTime: string; endTime: string }>)
          .map((c) => `${c.title} (${c.startTime}–${c.endTime})`)
          .join(", ");
        onToast({
          type: "conflict",
          title: "Scheduling conflict",
          body: `Conflicts with: ${conflictNames}. Dismissed pending event.`,
        });
      } else if (action === "approve") {
        onToast({ type: "event_added", title: "Event added", body: "Event moved to your calendar." });
      }
      onUpdate();
    } finally {
      setLoading(null);
    }
  }

  if (pendingEvents.length === 0) {
    return (
      <p className="text-sm text-gray-400 text-center py-6">
        No events waiting for review.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {pendingEvents.map((e) => (
        <div
          key={e.id}
          className="bg-white border border-yellow-200 rounded-xl p-4 shadow-sm"
        >
          <div className="flex items-start justify-between gap-2 mb-2">
            <h4 className="font-semibold text-gray-800 text-sm">{e.title}</h4>
            <span
              className={`text-xs font-medium px-2 py-0.5 rounded-full shrink-0 ${CONFIDENCE_COLOR(e.confidence)}`}
            >
              {CONFIDENCE_LABEL(e.confidence)} ({Math.round(e.confidence * 100)}%)
            </span>
          </div>

          <div className="text-xs text-gray-500 space-y-0.5 mb-3">
            {e.date && <p>📅 {e.date}{e.startTime ? ` at ${e.startTime}` : ""}</p>}
            {e.location && <p>📍 {e.location}</p>}
            {e.reasoningSummary && (
              <p className="italic text-gray-400 mt-1">&ldquo;{e.reasoningSummary}&rdquo;</p>
            )}
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => handleAction(e.id, "approve")}
              disabled={loading === e.id}
              className="flex-1 bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white text-xs font-medium rounded-lg py-1.5 transition-colors"
            >
              {loading === e.id ? "…" : "Add to calendar"}
            </button>
            <button
              onClick={() => handleAction(e.id, "dismiss")}
              disabled={loading === e.id}
              className="flex-1 border border-gray-300 hover:bg-gray-50 text-gray-600 text-xs font-medium rounded-lg py-1.5 transition-colors"
            >
              Dismiss
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
