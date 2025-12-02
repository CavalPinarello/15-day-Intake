"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import {
  CheckCircle,
  Circle,
  Clock,
  Sun,
  Moon,
  Sunset,
  Coffee,
  ChevronRight,
  Trophy,
  Target,
  TrendingUp,
  MessageSquare,
  X,
  Send,
  Sparkles,
  ArrowLeft,
  Settings,
} from "lucide-react";

interface TreatmentTask {
  id: string;
  name: string;
  category: string;
  instructions: string;
  timing: string;
  frequency: string;
  isCompleted: boolean;
}

interface DayHistory {
  date: string;
  completedTasks: number;
  totalTasks: number;
}

const timingIcons: Record<string, React.ReactNode> = {
  Morning: <Sun className="w-4 h-4" />,
  Afternoon: <Coffee className="w-4 h-4" />,
  Evening: <Sunset className="w-4 h-4" />,
  "Before bed": <Moon className="w-4 h-4" />,
  "With meals": <Coffee className="w-4 h-4" />,
};

const timingColors: Record<string, { bg: string; text: string; border: string }> = {
  Morning: { bg: "bg-amber-50", text: "text-amber-700", border: "border-amber-200" },
  Afternoon: { bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  Evening: { bg: "bg-purple-50", text: "text-purple-700", border: "border-purple-200" },
  "Before bed": { bg: "bg-indigo-50", text: "text-indigo-700", border: "border-indigo-200" },
  "With meals": { bg: "bg-green-50", text: "text-green-700", border: "border-green-200" },
};

// Sample treatment tasks - in production these would come from the physician dashboard
const sampleTasks: TreatmentTask[] = [
  {
    id: "1",
    name: "Morning Light Exposure",
    category: "Sleep Hygiene",
    instructions: "Get 15-30 minutes of bright light within 1 hour of waking",
    timing: "Morning",
    frequency: "Daily",
    isCompleted: false,
  },
  {
    id: "2",
    name: "Caffeine Cutoff",
    category: "Sleep Hygiene",
    instructions: "No caffeine after 2 PM",
    timing: "Afternoon",
    frequency: "Daily",
    isCompleted: false,
  },
  {
    id: "3",
    name: "Screen-Free Wind Down",
    category: "Sleep Hygiene",
    instructions: "Turn off all screens 1 hour before bed",
    timing: "Evening",
    frequency: "Daily",
    isCompleted: false,
  },
  {
    id: "4",
    name: "Relaxation Practice",
    category: "Stress Management",
    instructions: "Practice deep breathing or progressive muscle relaxation for 10 minutes",
    timing: "Before bed",
    frequency: "Daily",
    isCompleted: false,
  },
  {
    id: "5",
    name: "Consistent Bedtime",
    category: "Sleep Schedule",
    instructions: "Get into bed at the same time each night (within 30 minutes)",
    timing: "Before bed",
    frequency: "Daily",
    isCompleted: false,
  },
];

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return "Good morning";
  if (hour >= 12 && hour < 17) return "Good afternoon";
  if (hour >= 17 && hour < 21) return "Good evening";
  return "Good night";
}

export default function TreatmentPage() {
  const [tasks, setTasks] = useState<TreatmentTask[]>([]);
  const [showNoteModal, setShowNoteModal] = useState(false);
  const [activeTaskId, setActiveTaskId] = useState<string | null>(null);
  const [noteText, setNoteText] = useState("");
  const [weekHistory, setWeekHistory] = useState<DayHistory[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadTreatmentData();
  }, []);

  const loadTreatmentData = () => {
    setIsLoading(true);
    try {
      // Load tasks from localStorage or use defaults
      const savedTasks = localStorage.getItem('treatmentTasks');
      if (savedTasks) {
        setTasks(JSON.parse(savedTasks));
      } else {
        setTasks(sampleTasks);
        localStorage.setItem('treatmentTasks', JSON.stringify(sampleTasks));
      }

      // Load week history
      const savedHistory = localStorage.getItem('treatmentHistory');
      if (savedHistory) {
        setWeekHistory(JSON.parse(savedHistory));
      } else {
        // Generate empty history for last 7 days
        const history: DayHistory[] = [];
        for (let i = 6; i >= 0; i--) {
          const date = new Date();
          date.setDate(date.getDate() - i);
          history.push({
            date: date.toISOString().split('T')[0],
            completedTasks: 0,
            totalTasks: sampleTasks.length,
          });
        }
        setWeekHistory(history);
      }
    } catch (error) {
      console.error('Error loading treatment data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleTask = (taskId: string) => {
    setTasks(prev => {
      const updated = prev.map(task =>
        task.id === taskId ? { ...task, isCompleted: !task.isCompleted } : task
      );
      localStorage.setItem('treatmentTasks', JSON.stringify(updated));

      // Update today's history
      const today = new Date().toISOString().split('T')[0];
      const completedCount = updated.filter(t => t.isCompleted).length;
      setWeekHistory(prevHistory => {
        const updatedHistory = prevHistory.map(day =>
          day.date === today
            ? { ...day, completedTasks: completedCount }
            : day
        );
        localStorage.setItem('treatmentHistory', JSON.stringify(updatedHistory));
        return updatedHistory;
      });

      return updated;
    });
  };

  const handleSaveNote = () => {
    if (!activeTaskId || !noteText.trim()) return;
    // Save note to localStorage
    const notes = JSON.parse(localStorage.getItem('treatmentNotes') || '{}');
    notes[activeTaskId] = notes[activeTaskId] || [];
    notes[activeTaskId].push({
      text: noteText,
      date: new Date().toISOString(),
    });
    localStorage.setItem('treatmentNotes', JSON.stringify(notes));
    setNoteText("");
    setShowNoteModal(false);
    setActiveTaskId(null);
  };

  // Group tasks by timing
  const tasksByTiming = tasks.reduce((acc, task) => {
    const timing = task.timing || "Anytime";
    if (!acc[timing]) acc[timing] = [];
    acc[timing].push(task);
    return acc;
  }, {} as Record<string, TreatmentTask[]>);

  // Calculate progress
  const completedCount = tasks.filter(t => t.isCompleted).length;
  const totalCount = tasks.length;
  const completionPercentage = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-teal-50 to-blue-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-teal-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-teal-50 via-white to-blue-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Link href="/dashboard" className="p-2 hover:bg-gray-100 rounded-full">
                <ArrowLeft className="w-5 h-5 text-gray-600" />
              </Link>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Treatment Tasks</h1>
                <p className="text-sm text-gray-500">{getGreeting()}</p>
              </div>
            </div>
            <Link href="/settings" className="p-2 hover:bg-gray-100 rounded-full">
              <Settings className="w-5 h-5 text-gray-600" />
            </Link>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 py-6 space-y-6">
        {/* Progress Card */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2">
              <Target className="w-5 h-5 text-teal-600" />
              Today's Progress
            </h3>
            <span className="text-2xl font-bold text-teal-600">
              {completionPercentage}%
            </span>
          </div>

          {/* Progress Bar */}
          <div className="h-3 bg-gray-100 rounded-full overflow-hidden mb-4">
            <div
              className="h-full bg-gradient-to-r from-teal-500 to-blue-500 rounded-full transition-all duration-500"
              style={{ width: `${completionPercentage}%` }}
            />
          </div>

          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600">
              <CheckCircle className="w-4 h-4 inline mr-1 text-green-500" />
              {completedCount} completed
            </span>
            <span className="text-gray-600">
              <Circle className="w-4 h-4 inline mr-1 text-gray-400" />
              {totalCount - completedCount} remaining
            </span>
          </div>

          {completionPercentage === 100 && (
            <div className="mt-4 p-4 bg-gradient-to-r from-amber-50 to-yellow-50 rounded-xl border border-amber-200 flex items-center gap-3">
              <Trophy className="w-8 h-8 text-amber-500" />
              <div>
                <p className="font-semibold text-amber-700">All tasks completed!</p>
                <p className="text-sm text-amber-600">Great job staying on track today.</p>
              </div>
            </div>
          )}
        </section>

        {/* Tasks by Time of Day */}
        <section className="space-y-6">
          {Object.entries(tasksByTiming).map(([timing, timingTasks]) => {
            const colors = timingColors[timing] || timingColors.Morning;
            const icon = timingIcons[timing] || <Clock className="w-4 h-4" />;
            const completedInTiming = timingTasks.filter(t => t.isCompleted).length;

            return (
              <div key={timing}>
                <div className="flex items-center gap-2 mb-3">
                  <div className={`p-2 rounded-lg ${colors.bg} ${colors.text}`}>
                    {icon}
                  </div>
                  <h3 className="font-semibold text-gray-900">{timing}</h3>
                  <span className="text-sm text-gray-500">
                    ({completedInTiming}/{timingTasks.length})
                  </span>
                </div>

                <div className="space-y-3">
                  {timingTasks.map((task) => (
                    <div
                      key={task.id}
                      className={`bg-white rounded-xl border transition-all ${
                        task.isCompleted
                          ? "border-green-200 bg-green-50/50"
                          : "border-gray-200 hover:border-teal-300 hover:shadow-sm"
                      }`}
                    >
                      <div className="p-4">
                        <div className="flex items-start gap-4">
                          {/* Checkbox */}
                          <button
                            onClick={() => handleToggleTask(task.id)}
                            className={`flex-shrink-0 w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all ${
                              task.isCompleted
                                ? "bg-green-500 border-green-500"
                                : "border-gray-300 hover:border-teal-500"
                            }`}
                          >
                            {task.isCompleted && (
                              <CheckCircle className="w-4 h-4 text-white" />
                            )}
                          </button>

                          {/* Task Content */}
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <h4
                                className={`font-medium ${
                                  task.isCompleted
                                    ? "text-gray-500 line-through"
                                    : "text-gray-900"
                                }`}
                              >
                                {task.name}
                              </h4>
                              <span className="px-2 py-0.5 bg-gray-100 text-gray-600 rounded text-xs">
                                {task.category}
                              </span>
                            </div>
                            <p
                              className={`text-sm mt-1 ${
                                task.isCompleted ? "text-gray-400" : "text-gray-600"
                              }`}
                            >
                              {task.instructions}
                            </p>
                            <p className="text-xs text-gray-400 mt-2">
                              <Clock className="w-3 h-3 inline mr-1" />
                              {task.frequency}
                            </p>
                          </div>

                          {/* Note Button */}
                          <button
                            onClick={() => {
                              setActiveTaskId(task.id);
                              setShowNoteModal(true);
                            }}
                            className="p-2 text-gray-400 hover:text-teal-600 hover:bg-teal-50 rounded-lg transition-colors"
                            title="Add note"
                          >
                            <MessageSquare className="w-5 h-5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}

          {tasks.length === 0 && (
            <div className="text-center py-12 bg-white rounded-2xl border border-gray-200">
              <Sparkles className="w-12 h-12 mx-auto mb-4 text-gray-300" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                No treatment tasks yet
              </h3>
              <p className="text-gray-500 max-w-sm mx-auto">
                Complete your 15-day intake to receive personalized treatment
                recommendations from your physician.
              </p>
              <Link
                href="/journey"
                className="inline-flex items-center gap-2 mt-4 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
              >
                Continue Journey
                <ChevronRight className="w-4 h-4" />
              </Link>
            </div>
          )}
        </section>

        {/* Weekly Progress */}
        {weekHistory.length > 0 && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2 mb-4">
              <TrendingUp className="w-5 h-5 text-teal-600" />
              7-Day Streak
            </h3>

            <div className="flex justify-between gap-2">
              {weekHistory.map((day) => {
                const percentage = day.totalTasks > 0
                  ? Math.round((day.completedTasks / day.totalTasks) * 100)
                  : 0;
                const isToday = day.date === new Date().toISOString().split("T")[0];

                return (
                  <div key={day.date} className="flex-1 text-center">
                    <div
                      className={`h-16 rounded-lg flex items-end justify-center mb-2 overflow-hidden ${
                        isToday ? "ring-2 ring-teal-500" : ""
                      }`}
                    >
                      <div
                        className={`w-full transition-all duration-300 ${
                          percentage >= 80
                            ? "bg-teal-500"
                            : percentage >= 50
                            ? "bg-amber-400"
                            : percentage > 0
                            ? "bg-red-400"
                            : "bg-gray-200"
                        }`}
                        style={{ height: `${Math.max(percentage, 10)}%` }}
                      />
                    </div>
                    <p className="text-xs font-medium text-gray-700">{percentage}%</p>
                    <p className="text-xs text-gray-500">
                      {new Date(day.date).toLocaleDateString("en-US", { weekday: "short" })}
                    </p>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* Back to Dashboard Link */}
        <Link
          href="/dashboard"
          className="block bg-gradient-to-r from-teal-500 to-blue-500 rounded-2xl p-4 text-white hover:opacity-90 transition-opacity"
        >
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-semibold">Back to Dashboard</h3>
              <p className="text-sm text-white/80">View your full sleep journey</p>
            </div>
            <ChevronRight className="w-6 h-6" />
          </div>
        </Link>
      </main>

      {/* Note Modal */}
      {showNoteModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900">Add a Note</h3>
              <button
                onClick={() => {
                  setShowNoteModal(false);
                  setNoteText("");
                  setActiveTaskId(null);
                }}
                className="p-2 text-gray-400 hover:text-gray-600 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <textarea
              value={noteText}
              onChange={(e) => setNoteText(e.target.value)}
              placeholder="How did this task go? Any observations..."
              className="w-full p-3 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-teal-500"
              rows={4}
            />

            <div className="flex justify-end gap-3 mt-4">
              <button
                onClick={() => {
                  setShowNoteModal(false);
                  setNoteText("");
                  setActiveTaskId(null);
                }}
                className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveNote}
                disabled={!noteText.trim()}
                className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50"
              >
                <Send className="w-4 h-4" />
                Save Note
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
