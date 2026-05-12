"use client";

import type { CalendarEvent } from "@/db/schema";

interface CalendarPanelProps {
  events: CalendarEvent[];
  onDelete: (id: string) => void;
}

function formatDate(date: string) {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

const today = () => new Date().toISOString().slice(0, 10);

export function CalendarPanel({ events, onDelete }: CalendarPanelProps) {
  if (events.length === 0) {
    return (
      <p className="text-sm text-gray-400 text-center py-6">
        No upcoming events. Confirmed plans will appear here.
      </p>
    );
  }

  const todayStr = today();

  return (
    <div className="flex flex-col gap-2">
      {events.map((e) => {
        const isToday = e.date === todayStr;
        const isPast = e.date < todayStr;
        return (
          <div
            key={e.id}
            className={`bg-white border rounded-xl p-4 shadow-sm transition-opacity ${
              isPast ? "opacity-50" : ""
            } ${isToday ? "border-indigo-400 ring-1 ring-indigo-200" : "border-gray-200"}`}
          >
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="font-semibold text-gray-800 text-sm">{e.title}</p>
                <p className="text-xs text-gray-500 mt-0.5">
                  {isToday ? (
                    <span className="text-indigo-600 font-medium">Today</span>
                  ) : (
                    formatDate(e.date)
                  )}{" "}
                  · {e.startTime}–{e.endTime}
                </p>
                {e.location && (
                  <p className="text-xs text-gray-400 mt-0.5">📍 {e.location}</p>
                )}
              </div>
              <button
                onClick={() => onDelete(e.id)}
                className="text-gray-300 hover:text-red-400 transition-colors text-lg leading-none shrink-0"
                aria-label="Remove event"
              >
                ×
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
