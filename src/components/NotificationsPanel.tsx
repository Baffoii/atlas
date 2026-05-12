"use client";

import type { Notification } from "@/db/schema";

const TYPE_ICON: Record<string, string> = {
  conflict: "⚠️",
  pending_review: "🔍",
  event_added: "✓",
  deadline_reminder: "⏰",
  extraction_error: "✗",
};

const TYPE_BG: Record<string, string> = {
  conflict: "bg-red-50 border-red-200",
  pending_review: "bg-yellow-50 border-yellow-200",
  event_added: "bg-green-50 border-green-200",
  deadline_reminder: "bg-blue-50 border-blue-200",
  extraction_error: "bg-orange-50 border-orange-200",
};

interface NotificationsPanelProps {
  notifications: Notification[];
  onMarkRead: (id: string) => void;
}

export function NotificationsPanel({ notifications, onMarkRead }: NotificationsPanelProps) {
  const unread = notifications.filter((n) => !n.read);
  const read = notifications.filter((n) => n.read);

  if (notifications.length === 0) {
    return (
      <p className="text-sm text-gray-400 text-center py-6">No notifications yet.</p>
    );
  }

  return (
    <div className="flex flex-col gap-2 max-h-[70vh] overflow-y-auto pr-1">
      {unread.length > 0 && (
        <>
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Unread</p>
          {unread.map((n) => (
            <NotificationCard key={n.id} n={n} onMarkRead={onMarkRead} />
          ))}
        </>
      )}
      {read.length > 0 && (
        <>
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mt-2 mb-1">Read</p>
          {read.map((n) => (
            <NotificationCard key={n.id} n={n} onMarkRead={onMarkRead} />
          ))}
        </>
      )}
    </div>
  );
}

function NotificationCard({
  n,
  onMarkRead,
}: {
  n: Notification;
  onMarkRead: (id: string) => void;
}) {
  return (
    <div
      className={`border rounded-xl p-3 transition-opacity ${TYPE_BG[n.type] ?? "bg-gray-50 border-gray-200"} ${n.read ? "opacity-60" : ""}`}
    >
      <div className="flex items-start gap-2">
        <span className="text-base shrink-0">{TYPE_ICON[n.type] ?? "•"}</span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-800">{n.title}</p>
          <p className="text-xs text-gray-600 mt-0.5 leading-snug">{n.body}</p>
          <p className="text-xs text-gray-400 mt-1">
            {new Date(n.createdAt).toLocaleString()}
          </p>
        </div>
        {!n.read && (
          <button
            onClick={() => onMarkRead(n.id)}
            className="text-xs text-gray-400 hover:text-gray-600 shrink-0 transition-colors"
          >
            Mark read
          </button>
        )}
      </div>
    </div>
  );
}
