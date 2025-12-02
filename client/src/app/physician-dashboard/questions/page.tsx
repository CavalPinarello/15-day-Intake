"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import Link from "next/link";
import { useState } from "react";
import { UserButton } from "@clerk/nextjs";
import {
  Moon,
  Users,
  ClipboardList,
  Settings,
  Search,
  Plus,
  GripVertical,
  ChevronDown,
  ChevronRight,
  Edit,
  Trash2,
  Save,
  X,
  Calendar,
  FileText,
  Layers,
} from "lucide-react";

type ViewMode = "days" | "modules" | "questions";

const pillarColors: Record<string, { bg: string; text: string; border: string }> = {
  Sleep: { bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  Health: { bg: "bg-green-50", text: "text-green-700", border: "border-green-200" },
  Lifestyle: { bg: "bg-purple-50", text: "text-purple-700", border: "border-purple-200" },
  Environment: { bg: "bg-amber-50", text: "text-amber-700", border: "border-amber-200" },
  Demographics: { bg: "bg-gray-50", text: "text-gray-700", border: "border-gray-200" },
};

const questionTypeLabels: Record<string, string> = {
  scale: "Scale (1-10)",
  yes_no: "Yes/No",
  single_select: "Single Select",
  multi_select: "Multi Select",
  number: "Number",
  time: "Time",
  text: "Text",
  date: "Date",
  duration: "Duration",
};

export default function QuestionManagerPage() {
  const [viewMode, setViewMode] = useState<ViewMode>("days");
  const [searchTerm, setSearchTerm] = useState("");
  const [expandedDays, setExpandedDays] = useState<Set<number>>(new Set([1]));
  const [expandedModules, setExpandedModules] = useState<Set<string>>(new Set());
  const [editingQuestion, setEditingQuestion] = useState<string | null>(null);

  // Queries
  const allQuestions = useQuery(api.assessment.getMasterQuestions, {});
  const allModules = useQuery(api.assessment.getModules, {});
  const dayAssignments = useQuery(api.assessment.getDayAssignments, {});

  // Mutations
  const updateQuestion = useMutation(api.assessment.updateAssessmentQuestion);
  const reorderModuleQuestions = useMutation(api.assessment.reorderModuleQuestions);
  const reorderDayModules = useMutation(api.assessment.reorderDayModules);

  // Filter questions by search
  const filteredQuestions = allQuestions?.filter(
    (q) =>
      q.question_text.toLowerCase().includes(searchTerm.toLowerCase()) ||
      q.question_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      q.pillar.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const toggleDay = (day: number) => {
    setExpandedDays((prev) => {
      const next = new Set(prev);
      if (next.has(day)) {
        next.delete(day);
      } else {
        next.add(day);
      }
      return next;
    });
  };

  const toggleModule = (moduleId: string) => {
    setExpandedModules((prev) => {
      const next = new Set(prev);
      if (next.has(moduleId)) {
        next.delete(moduleId);
      } else {
        next.add(moduleId);
      }
      return next;
    });
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-teal-500 to-blue-600 flex items-center justify-center">
                <Moon className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zoe Sleep</h1>
                <p className="text-xs text-gray-500">Physician Dashboard</p>
              </div>
            </div>

            <nav className="flex items-center gap-6">
              <Link
                href="/physician-dashboard"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Users className="w-5 h-5" />
                Patients
              </Link>
              <Link
                href="/physician-dashboard/questions"
                className="flex items-center gap-2 text-teal-600 font-medium"
              >
                <ClipboardList className="w-5 h-5" />
                Questions
              </Link>
              <Link
                href="/physician-dashboard/settings"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Settings className="w-5 h-5" />
                Settings
              </Link>
              <UserButton
                appearance={{
                  elements: {
                    avatarBox: "w-9 h-9",
                  },
                }}
              />
            </nav>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Page Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">Question Manager</h2>
            <p className="text-gray-600 mt-1">
              Manage assessment questions, modules, and day assignments
            </p>
          </div>

          <div className="flex items-center gap-3">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search questions..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-9 pr-4 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 w-64"
              />
            </div>
          </div>
        </div>

        {/* View Mode Tabs */}
        <div className="flex gap-2 mb-6">
          {[
            { id: "days" as const, label: "By Day", icon: <Calendar className="w-4 h-4" /> },
            { id: "modules" as const, label: "By Module", icon: <Layers className="w-4 h-4" /> },
            { id: "questions" as const, label: "All Questions", icon: <FileText className="w-4 h-4" /> },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setViewMode(tab.id)}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
                viewMode === tab.id
                  ? "bg-teal-600 text-white"
                  : "bg-white text-gray-600 hover:bg-gray-100 border border-gray-200"
              }`}
            >
              {tab.icon}
              {tab.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          {/* Days View */}
          {viewMode === "days" && (
            <div className="divide-y divide-gray-100">
              {Array.from({ length: 15 }, (_, i) => i + 1).map((day) => {
                const dayModules = dayAssignments?.[day] || [];
                const isExpanded = expandedDays.has(day);
                const totalQuestions = dayModules.reduce(
                  (sum: number, dm: any) => sum + (dm.module?.question_count || 0),
                  0
                );

                return (
                  <div key={day}>
                    <button
                      onClick={() => toggleDay(day)}
                      className="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-10 h-10 rounded-full bg-teal-100 text-teal-700 flex items-center justify-center font-bold">
                          {day}
                        </div>
                        <div className="text-left">
                          <h3 className="font-semibold text-gray-900">Day {day}</h3>
                          <p className="text-sm text-gray-500">
                            {dayModules.length} modules &bull; {totalQuestions} questions
                          </p>
                        </div>
                      </div>
                      {isExpanded ? (
                        <ChevronDown className="w-5 h-5 text-gray-400" />
                      ) : (
                        <ChevronRight className="w-5 h-5 text-gray-400" />
                      )}
                    </button>

                    {isExpanded && dayModules.length > 0 && (
                      <div className="bg-gray-50 px-4 pb-4">
                        <div className="space-y-2">
                          {dayModules.map((dm: any, index: number) => (
                            <div
                              key={dm.module.module_id}
                              className="flex items-center gap-3 p-3 bg-white rounded-lg border border-gray-200"
                            >
                              <GripVertical className="w-4 h-4 text-gray-400 cursor-grab" />
                              <span className="text-sm text-gray-500 w-6">
                                {index + 1}.
                              </span>
                              <div className="flex-1">
                                <p className="font-medium text-gray-900">
                                  {dm.module.name}
                                </p>
                                <p className="text-sm text-gray-500">
                                  {dm.module.question_count} questions &bull;{" "}
                                  {dm.module.estimated_time_minutes} min
                                </p>
                              </div>
                              <span
                                className={`px-2 py-0.5 rounded text-xs font-medium ${
                                  pillarColors[dm.module.pillar]?.bg || "bg-gray-100"
                                } ${pillarColors[dm.module.pillar]?.text || "text-gray-700"}`}
                              >
                                {dm.module.pillar}
                              </span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {isExpanded && dayModules.length === 0 && (
                      <div className="bg-gray-50 px-4 py-8 text-center text-gray-500">
                        <p>No modules assigned to this day</p>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* Modules View */}
          {viewMode === "modules" && (
            <div className="divide-y divide-gray-100">
              {allModules?.map((module) => {
                const isExpanded = expandedModules.has(module.module_id);
                const pillarStyle = pillarColors[module.pillar] || pillarColors.Demographics;

                return (
                  <div key={module.module_id}>
                    <button
                      onClick={() => toggleModule(module.module_id)}
                      className="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <div
                          className={`w-10 h-10 rounded-lg ${pillarStyle.bg} ${pillarStyle.text} flex items-center justify-center font-bold text-sm`}
                        >
                          {module.module_id.slice(0, 2)}
                        </div>
                        <div className="text-left">
                          <div className="flex items-center gap-2">
                            <h3 className="font-semibold text-gray-900">
                              {module.name}
                            </h3>
                            <span
                              className={`px-2 py-0.5 rounded text-xs font-medium ${pillarStyle.bg} ${pillarStyle.text}`}
                            >
                              {module.pillar}
                            </span>
                          </div>
                          <p className="text-sm text-gray-500">
                            {module.question_count} questions &bull;{" "}
                            {module.estimated_time_minutes} min &bull; Tier{" "}
                            {module.tier}
                          </p>
                        </div>
                      </div>
                      {isExpanded ? (
                        <ChevronDown className="w-5 h-5 text-gray-400" />
                      ) : (
                        <ChevronRight className="w-5 h-5 text-gray-400" />
                      )}
                    </button>

                    {isExpanded && (
                      <div className="bg-gray-50 px-4 pb-4">
                        <p className="text-sm text-gray-600 mb-3">
                          {module.description}
                        </p>
                        <div className="space-y-2">
                          {/* Module questions would be loaded here */}
                          <p className="text-sm text-gray-500 italic">
                            Questions in this module will appear here
                          </p>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* Questions View */}
          {viewMode === "questions" && (
            <div>
              <div className="px-4 py-3 border-b border-gray-100 bg-gray-50">
                <p className="text-sm text-gray-600">
                  Showing {filteredQuestions?.length || 0} of{" "}
                  {allQuestions?.length || 0} questions
                </p>
              </div>
              <div className="divide-y divide-gray-100 max-h-[calc(100vh-400px)] overflow-y-auto">
                {filteredQuestions?.map((question) => {
                  const pillarStyle =
                    pillarColors[question.pillar] || pillarColors.Demographics;
                  const isEditing = editingQuestion === question.question_id;

                  return (
                    <div
                      key={question.question_id}
                      className={`p-4 ${isEditing ? "bg-blue-50" : "hover:bg-gray-50"} transition-colors`}
                    >
                      <div className="flex items-start gap-4">
                        <div className="flex-shrink-0">
                          <span className="inline-block px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs font-mono">
                            {question.question_id}
                          </span>
                        </div>
                        <div className="flex-1 min-w-0">
                          {isEditing ? (
                            <div className="space-y-3">
                              <textarea
                                defaultValue={question.question_text}
                                className="w-full p-2 border border-gray-300 rounded-lg text-sm resize-none focus:outline-none focus:ring-2 focus:ring-teal-500"
                                rows={2}
                              />
                              <div className="flex gap-2">
                                <button
                                  onClick={() => setEditingQuestion(null)}
                                  className="px-3 py-1 bg-teal-600 text-white rounded text-sm hover:bg-teal-700"
                                >
                                  <Save className="w-4 h-4 inline mr-1" />
                                  Save
                                </button>
                                <button
                                  onClick={() => setEditingQuestion(null)}
                                  className="px-3 py-1 border border-gray-300 text-gray-600 rounded text-sm hover:bg-gray-100"
                                >
                                  <X className="w-4 h-4 inline mr-1" />
                                  Cancel
                                </button>
                              </div>
                            </div>
                          ) : (
                            <>
                              <p className="text-gray-900">
                                {question.question_text}
                              </p>
                              <div className="flex items-center gap-2 mt-2">
                                <span
                                  className={`px-2 py-0.5 rounded text-xs font-medium ${pillarStyle.bg} ${pillarStyle.text}`}
                                >
                                  {question.pillar}
                                </span>
                                <span className="px-2 py-0.5 bg-gray-100 text-gray-600 rounded text-xs">
                                  {questionTypeLabels[question.question_type] ||
                                    question.question_type}
                                </span>
                                <span className="text-xs text-gray-400">
                                  Tier {question.tier}
                                </span>
                                {question.estimated_time && (
                                  <span className="text-xs text-gray-400">
                                    ~{question.estimated_time}s
                                  </span>
                                )}
                              </div>
                            </>
                          )}
                        </div>
                        {!isEditing && (
                          <button
                            onClick={() => setEditingQuestion(question.question_id)}
                            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Stats Footer */}
        <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">Total Questions</p>
            <p className="text-2xl font-bold text-gray-900">
              {allQuestions?.length || 0}
            </p>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">Total Modules</p>
            <p className="text-2xl font-bold text-gray-900">
              {allModules?.length || 0}
            </p>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">Days Configured</p>
            <p className="text-2xl font-bold text-gray-900">15</p>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">Question Types</p>
            <p className="text-2xl font-bold text-gray-900">9</p>
          </div>
        </div>
      </main>
    </div>
  );
}
