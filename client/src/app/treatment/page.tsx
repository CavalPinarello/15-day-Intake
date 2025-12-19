"use client";

import { useState } from "react";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
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
  Loader2,
  AlertCircle,
} from "lucide-react";

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

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return "Good morning";
  if (hour >= 12 && hour < 17) return "Good afternoon";
  if (hour >= 17 && hour < 21) return "Good evening";
  return "Good night";
}

export default function TreatmentPage() {
  const [showNoteModal, setShowNoteModal] = useState(false);
  const [activeTaskId, setActiveTaskId] = useState<Id<"user_interventions"> | null>(null);
  const [noteText, setNoteText] = useState("");

  // Get user ID from localStorage (set during login)
  const storedUserId = typeof window !== "undefined" ? localStorage.getItem("convex_user_id") : null;
  const userId = storedUserId as Id<"users"> | null;

  // Convex queries
  const activeInterventions = useQuery(
    api.treatment.getActiveInterventions,
    userId ? { userId } : "skip"
  );

  const todaySummary = useQuery(
    api.treatment.getTodayTasksSummary,
    userId ? { userId } : "skip"
  );

  const complianceHistory = useQuery(
    api.treatment.getComplianceHistory,
    userId ? { userId, days: 7 } : "skip"
  );

  const treatmentPhase = useQuery(
    api.treatment.getTreatmentPhase,
    userId ? { userId } : "skip"
  );

  // Convex mutations
  const completeTask = useMutation(api.treatment.completeTask);
  const uncompleteTask = useMutation(api.treatment.uncompleteTask);
  const addTaskNote = useMutation(api.treatment.addTaskNote);

  const handleToggleTask = async (taskId: Id<"user_interventions">, isCurrentlyCompleted: boolean) => {
    try {
      if (isCurrentlyCompleted) {
        await uncompleteTask({ userInterventionId: taskId });
      } else {
        await completeTask({ userInterventionId: taskId });
      }
    } catch (error) {
      console.error("Error toggling task:", error);
    }
  };

  const handleSaveNote = async () => {
    if (!activeTaskId || !noteText.trim()) return;
    try {
      await addTaskNote({
        userInterventionId: activeTaskId,
        noteText: noteText.trim(),
      });
      setNoteText("");
      setShowNoteModal(false);
      setActiveTaskId(null);
    } catch (error) {
      console.error("Error saving note:", error);
    }
  };

  // Group tasks by timing
  const tasksByTiming = (activeInterventions || []).reduce((acc, task) => {
    const timing = task.timing || "Anytime";
    if (!acc[timing]) acc[timing] = [];
    acc[timing].push(task);
    return acc;
  }, {} as Record<string, typeof activeInterventions>);

  // Calculate progress
  const completionPercentage = todaySummary?.completionPercentage || 0;
  const completedCount = todaySummary?.completedTasks || 0;
  const totalCount = todaySummary?.totalTasks || 0;

  // Loading state
  if (!userId) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-teal-50 to-blue-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl shadow-lg p-8 max-w-md w-full text-center">
          <AlertCircle className="w-12 h-12 mx-auto mb-4 text-amber-500" />
          <h2 className="text-xl font-bold text-gray-900 mb-2">Not Logged In</h2>
          <p className="text-gray-600 mb-4">
            Please log in to view your treatment tasks.
          </p>
          <Link
            href="/login"
            className="inline-flex items-center gap-2 px-6 py-3 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
          >
            Go to Login
            <ChevronRight className="w-4 h-4" />
          </Link>
        </div>
      </div>
    );
  }

  if (activeInterventions === undefined || todaySummary === undefined) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-teal-50 to-blue-50 flex items-center justify-center">
        <div className="flex items-center gap-3">
          <Loader2 className="w-8 h-8 text-teal-600 animate-spin" />
          <span className="text-gray-600">Loading treatment tasks...</span>
        </div>
      </div>
    );
  }

  // Check if user is in treatment phase
  if (treatmentPhase && treatmentPhase.phase === "intake") {
    return (
      <div className="min-h-screen bg-gradient-to-br from-teal-50 via-white to-blue-50">
        <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
          <div className="max-w-2xl mx-auto px-4 py-4">
            <div className="flex items-center gap-3">
              <Link href="/dashboard" className="p-2 hover:bg-gray-100 rounded-full">
                <ArrowLeft className="w-5 h-5 text-gray-600" />
              </Link>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Treatment Tasks</h1>
                <p className="text-sm text-gray-500">{getGreeting()}</p>
              </div>
            </div>
          </div>
        </header>

        <main className="max-w-2xl mx-auto px-4 py-12">
          <div className="text-center bg-white rounded-2xl border border-gray-200 p-8">
            <div className="w-16 h-16 bg-teal-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Sparkles className="w-8 h-8 text-teal-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Complete Your Assessment First
            </h2>
            <p className="text-gray-600 mb-2">
              You're on day {treatmentPhase.intakeDay} of your 15-day intake assessment.
            </p>
            <p className="text-gray-500 text-sm mb-6">
              Once you complete the assessment, your physician will create a personalized
              treatment plan just for you.
            </p>
            <Link
              href="/journey"
              className="inline-flex items-center gap-2 px-6 py-3 bg-teal-600 text-white rounded-xl hover:bg-teal-700 transition-colors"
            >
              Continue Assessment
              <ChevronRight className="w-5 h-5" />
            </Link>
          </div>
        </main>
      </div>
    );
  }

  // Check if waiting for physician
  if (treatmentPhase && treatmentPhase.phase === "completed" && totalCount === 0) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-teal-50 via-white to-blue-50">
        <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
          <div className="max-w-2xl mx-auto px-4 py-4">
            <div className="flex items-center gap-3">
              <Link href="/dashboard" className="p-2 hover:bg-gray-100 rounded-full">
                <ArrowLeft className="w-5 h-5 text-gray-600" />
              </Link>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Treatment Tasks</h1>
                <p className="text-sm text-gray-500">{getGreeting()}</p>
              </div>
            </div>
          </div>
        </header>

        <main className="max-w-2xl mx-auto px-4 py-12">
          <div className="text-center bg-white rounded-2xl border border-gray-200 p-8">
            <div className="w-16 h-16 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Clock className="w-8 h-8 text-amber-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Assessment Complete!
            </h2>
            <p className="text-gray-600 mb-4">
              Great job completing your 15-day assessment. Your physician is now reviewing
              your results and creating a personalized treatment plan.
            </p>
            <p className="text-gray-500 text-sm">
              You'll receive a notification when your treatment plan is ready.
            </p>
          </div>
        </main>
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
                <p className="text-sm text-gray-500">
                  {getGreeting()}
                  {treatmentPhase?.treatmentWeek && ` • Week ${treatmentPhase.treatmentWeek}`}
                </p>
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
            if (!timingTasks || timingTasks.length === 0) return null;

            const colors = timingColors[timing] || timingColors.Morning;
            const icon = timingIcons[timing] || <Clock className="w-4 h-4" />;
            const completedInTiming = timingTasks.filter(t => t.todayCompleted).length;

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
                      key={task._id}
                      className={`bg-white rounded-xl border transition-all ${
                        task.todayCompleted
                          ? "border-green-200 bg-green-50/50"
                          : "border-gray-200 hover:border-teal-300 hover:shadow-sm"
                      }`}
                    >
                      <div className="p-4">
                        <div className="flex items-start gap-4">
                          {/* Checkbox */}
                          <button
                            onClick={() => handleToggleTask(task._id, task.todayCompleted)}
                            className={`flex-shrink-0 w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all ${
                              task.todayCompleted
                                ? "bg-green-500 border-green-500"
                                : "border-gray-300 hover:border-teal-500"
                            }`}
                          >
                            {task.todayCompleted && (
                              <CheckCircle className="w-4 h-4 text-white" />
                            )}
                          </button>

                          {/* Task Content */}
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <h4
                                className={`font-medium ${
                                  task.todayCompleted
                                    ? "text-gray-500 line-through"
                                    : "text-gray-900"
                                }`}
                              >
                                {task.name}
                              </h4>
                              {task.category && (
                                <span className="px-2 py-0.5 bg-gray-100 text-gray-600 rounded text-xs">
                                  {task.category}
                                </span>
                              )}
                            </div>
                            <p
                              className={`text-sm mt-1 ${
                                task.todayCompleted ? "text-gray-400" : "text-gray-600"
                              }`}
                            >
                              {task.custom_instructions || task.instructions}
                            </p>
                            {task.frequency && (
                              <p className="text-xs text-gray-400 mt-2">
                                <Clock className="w-3 h-3 inline mr-1" />
                                {task.frequency}
                              </p>
                            )}
                          </div>

                          {/* Note Button */}
                          <button
                            onClick={() => {
                              setActiveTaskId(task._id);
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

          {totalCount === 0 && (
            <div className="text-center py-12 bg-white rounded-2xl border border-gray-200">
              <Sparkles className="w-12 h-12 mx-auto mb-4 text-gray-300" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                No treatment tasks yet
              </h3>
              <p className="text-gray-500 max-w-sm mx-auto">
                Your physician hasn't assigned any treatment tasks yet.
                Check back soon!
              </p>
            </div>
          )}
        </section>

        {/* Weekly Progress */}
        {complianceHistory && complianceHistory.length > 0 && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2 mb-4">
              <TrendingUp className="w-5 h-5 text-teal-600" />
              7-Day Streak
            </h3>

            <div className="flex justify-between gap-2">
              {complianceHistory.slice().reverse().map((day) => {
                const percentage = day.totalTasks > 0
                  ? Math.round((day.completedTasks / day.totalTasks) * 100)
                  : 0;
                const isToday = day.date === new Date().toISOString().split("T")[0];

                return (
                  <div key={day.date} className="flex-1 text-center">
                    <div
                      className={`h-16 rounded-lg flex items-end justify-center mb-2 overflow-hidden bg-gray-100 ${
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
