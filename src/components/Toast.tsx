"use client";

import { useEffect } from "react";

export type ToastData = {
  id: string;
  type: "conflict" | "pending_review" | "event_added" | "deadline_reminder" | "extraction_error";
  title: string;
  body: string;
};

const TYPE_STYLES: Record<ToastData["type"], string> = {
  conflict: "border-red-500 bg-red-50 text-red-900",
  pending_review: "border-yellow-400 bg-yellow-50 text-yellow-900",
  event_added: "border-green-500 bg-green-50 text-green-900",
  deadline_reminder: "border-blue-500 bg-blue-50 text-blue-900",
  extraction_error: "border-orange-500 bg-orange-50 text-orange-900",
};

const ICONS: Record<ToastData["type"], string> = {
  conflict: "⚠️",
  pending_review: "🔍",
  event_added: "✓",
  deadline_reminder: "⏰",
  extraction_error: "✗",
};

const AUTO_DISMISS: Record<ToastData["type"], boolean> = {
  event_added: true,
  deadline_reminder: true,
  pending_review: false,
  conflict: false,
  extraction_error: false,
};

interface ToastProps {
  toast: ToastData;
  onDismiss: (id: string) => void;
}

export function Toast({ toast, onDismiss }: ToastProps) {
  useEffect(() => {
    if (AUTO_DISMISS[toast.type]) {
      const t = setTimeout(() => onDismiss(toast.id), 3000);
      return () => clearTimeout(t);
    }
  }, [toast.id, toast.type, onDismiss]);

  return (
    <div
      className={`flex items-start gap-3 p-4 rounded-lg border-l-4 shadow-md max-w-sm ${TYPE_STYLES[toast.type]} animate-slide-in`}
      role="alert"
    >
      <span className="text-lg shrink-0">{ICONS[toast.type]}</span>
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-sm">{toast.title}</p>
        <p className="text-xs mt-0.5 leading-relaxed">{toast.body}</p>
      </div>
      <button
        onClick={() => onDismiss(toast.id)}
        className="text-current opacity-50 hover:opacity-100 text-lg leading-none shrink-0"
        aria-label="Dismiss"
      >
        ×
      </button>
    </div>
  );
}

interface ToastContainerProps {
  toasts: ToastData[];
  onDismiss: (id: string) => void;
}

export function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  return (
    <div className="fixed bottom-4 right-4 flex flex-col gap-2 z-50">
      {toasts.map((t) => (
        <Toast key={t.id} toast={t} onDismiss={onDismiss} />
      ))}
    </div>
  );
}
