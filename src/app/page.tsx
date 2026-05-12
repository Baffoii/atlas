"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { InboxPanel } from "@/components/InboxPanel";
import { CalendarPanel } from "@/components/CalendarPanel";
import { PendingReviewPanel } from "@/components/PendingReviewPanel";
import { DeadlinesPanel } from "@/components/DeadlinesPanel";
import { NotificationsPanel } from "@/components/NotificationsPanel";
import { ToastContainer, type ToastData } from "@/components/Toast";
import type { Message, CalendarEvent, PendingEvent, Deadline, Notification } from "@/db/schema";

type Tab = "inbox" | "calendar" | "deadlines" | "notifications";

export default function Home() {
  const [activeTab, setActiveTab] = useState<Tab>("calendar");
  const [messages, setMessages] = useState<Message[]>([]);
  const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);
  const [pendingEvents, setPendingEvents] = useState<PendingEvent[]>([]);
  const [deadlines, setDeadlines] = useState<Deadline[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [toasts, setToasts] = useState<ToastData[]>([]);

  const prevNotifIds = useRef<Set<string>>(new Set());

  const dismissToast = useCallback((id: string) => {
    setToasts((ts) => ts.filter((t) => t.id !== id));
  }, []);

  const pushToast = useCallback((data: Omit<ToastData, "id">) => {
    const id = crypto.randomUUID();
    setToasts((ts) => [...ts.slice(-4), { ...data, id } as ToastData]);
  }, []);

  const fetchAll = useCallback(async () => {
    const [msgs, events, pending, dl, notifs] = await Promise.all([
      fetch("/api/messages").then((r) => r.json()),
      fetch("/api/calendar-events").then((r) => r.json()),
      fetch("/api/pending-events").then((r) => r.json()),
      fetch("/api/deadlines").then((r) => r.json()),
      fetch("/api/notifications").then((r) => r.json()),
    ]);
    setMessages(msgs);
    setCalendarEvents(events);
    setPendingEvents(pending);
    setDeadlines(dl);
    setNotifications(notifs);

    // Surface new notifications as toasts
    const newNotifs = (notifs as Notification[]).filter(
      (n) => !n.read && !prevNotifIds.current.has(n.id)
    );
    for (const n of newNotifs.slice(0, 3)) {
      pushToast({ type: n.type as ToastData["type"], title: n.title, body: n.body });
      prevNotifIds.current.add(n.id);
    }
  }, [pushToast]);

  useEffect(() => {
    fetchAll();
    const interval = setInterval(fetchAll, 3000);
    return () => clearInterval(interval);
  }, [fetchAll]);

  async function handleDeleteEvent(id: string) {
    await fetch(`/api/calendar-events/${id}`, { method: "DELETE" });
    fetchAll();
  }

  async function handleMarkRead(id: string) {
    await fetch(`/api/notifications/${id}/read`, { method: "POST" });
    setNotifications((ns) => ns.map((n) => (n.id === id ? { ...n, read: 1 } : n)));
  }

  const unreadCount = notifications.filter((n) => !n.read).length;
  const pendingCount = pendingEvents.length;

  const TABS: { key: Tab; label: string; badge?: number }[] = [
    { key: "calendar", label: "Calendar", badge: calendarEvents.length || undefined },
    { key: "inbox", label: "Inbox", badge: messages.filter((m) => m.status === "pending").length || undefined },
    { key: "deadlines", label: "Deadlines", badge: deadlines.length || undefined },
    { key: "notifications", label: "Alerts", badge: unreadCount || undefined },
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-2xl">🗓️</span>
            <h1 className="text-xl font-bold text-gray-900">Atlas</h1>
            <span className="text-xs text-gray-400 font-normal hidden sm:inline">AI Chief of Staff</span>
          </div>
          {pendingCount > 0 && (
            <button
              onClick={() => setActiveTab("inbox")}
              className="flex items-center gap-1.5 bg-yellow-50 border border-yellow-300 text-yellow-700 text-xs font-medium px-3 py-1.5 rounded-full hover:bg-yellow-100 transition-colors"
            >
              <span>🔍</span>
              {pendingCount} event{pendingCount !== 1 ? "s" : ""} to review
            </button>
          )}
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-4 py-6 flex gap-6">
        {/* Sidebar navigation */}
        <nav className="w-48 shrink-0 hidden md:block">
          <ul className="space-y-1">
            {TABS.map((tab) => (
              <li key={tab.key}>
                <button
                  onClick={() => setActiveTab(tab.key)}
                  className={`w-full flex items-center justify-between text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                    activeTab === tab.key
                      ? "bg-indigo-50 text-indigo-700"
                      : "text-gray-600 hover:bg-gray-100"
                  }`}
                >
                  <span>{tab.label}</span>
                  {tab.badge !== undefined && (
                    <span
                      className={`text-xs px-1.5 py-0.5 rounded-full ${
                        activeTab === tab.key
                          ? "bg-indigo-200 text-indigo-700"
                          : "bg-gray-200 text-gray-500"
                      }`}
                    >
                      {tab.badge}
                    </span>
                  )}
                </button>
              </li>
            ))}
          </ul>
        </nav>

        {/* Mobile tab bar */}
        <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 flex z-20">
          {TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 py-3 text-xs font-medium relative ${
                activeTab === tab.key ? "text-indigo-600" : "text-gray-500"
              }`}
            >
              {tab.label}
              {tab.badge !== undefined && (
                <span className="absolute top-1.5 right-[20%] bg-red-500 text-white text-[10px] w-4 h-4 rounded-full flex items-center justify-center">
                  {tab.badge > 9 ? "9+" : tab.badge}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Main content */}
        <main className="flex-1 min-w-0 pb-20 md:pb-0">
          {activeTab === "calendar" && (
            <section>
              <h2 className="text-lg font-bold text-gray-900 mb-4">Upcoming Events</h2>
              <CalendarPanel events={calendarEvents} onDelete={handleDeleteEvent} />

              {pendingCount > 0 && (
                <div className="mt-8">
                  <h2 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                    Review Queue
                    <span className="bg-yellow-100 text-yellow-700 text-sm font-medium px-2 py-0.5 rounded-full">
                      {pendingCount}
                    </span>
                  </h2>
                  <PendingReviewPanel
                    pendingEvents={pendingEvents}
                    onUpdate={fetchAll}
                    onToast={pushToast}
                  />
                </div>
              )}
            </section>
          )}

          {activeTab === "inbox" && (
            <section>
              <h2 className="text-lg font-bold text-gray-900 mb-4">Message Inbox</h2>
              <InboxPanel messages={messages} onMessageSent={fetchAll} />

              {pendingCount > 0 && (
                <div className="mt-8">
                  <h2 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                    Review Queue
                    <span className="bg-yellow-100 text-yellow-700 text-sm font-medium px-2 py-0.5 rounded-full">
                      {pendingCount}
                    </span>
                  </h2>
                  <PendingReviewPanel
                    pendingEvents={pendingEvents}
                    onUpdate={fetchAll}
                    onToast={pushToast}
                  />
                </div>
              )}
            </section>
          )}

          {activeTab === "deadlines" && (
            <section>
              <h2 className="text-lg font-bold text-gray-900 mb-4">Deadlines & Tasks</h2>
              <DeadlinesPanel deadlines={deadlines} onUpdate={fetchAll} />
            </section>
          )}

          {activeTab === "notifications" && (
            <section>
              <h2 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                Notifications
                {unreadCount > 0 && (
                  <span className="bg-red-100 text-red-600 text-sm font-medium px-2 py-0.5 rounded-full">
                    {unreadCount} new
                  </span>
                )}
              </h2>
              <NotificationsPanel
                notifications={notifications}
                onMarkRead={handleMarkRead}
              />
            </section>
          )}
        </main>
      </div>

      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </div>
  );
}
