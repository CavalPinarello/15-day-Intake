"use client";
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import Link from "next/link";
import { useState } from "react";
import { PhysicianLogoutButton } from "@/components/PhysicianAuthGuard";
import {
  Users,
  ClipboardList,
  Settings,
  Search,
  GripVertical,
  ChevronDown,
  ChevronRight,
  Edit,
  Save,
  X,
  Calendar,
  FileText,
  Layers,
  Zap,
  Clock,
  Shield,
} from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

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
  const [expandedDayModuleId, setExpandedDayModuleId] = useState<string | null>(null);

  // Queries
  const allQuestions = useQuery(api.assessment.getMasterQuestions, {});
  const allModules = useQuery(api.assessment.getModules, {});
  // Use enhanced query with computed question counts
  const dayAssignments = useQuery(api.assessment.getDayAssignmentsEnhanced, {});
  // Lazy-load questions when a module is expanded
  const moduleQuestions = useQuery(
    api.assessment.getQuestionsForModule,
    expandedDayModuleId ? { moduleId: expandedDayModuleId } : "skip"
  );
  // Get all gateways for expansion preview
  const allGateways = useQuery(api.assessment.getAllGateways, {});

  // Mutations (available for future editing features)
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const _updateQuestion = useMutation(api.assessment.updateAssessmentQuestion);
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const _reorderModuleQuestions = useMutation(api.assessment.reorderModuleQuestions);
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const _reorderDayModules = useMutation(api.assessment.reorderDayModules);

  // Filter questions by search
  const filteredQuestions = allQuestions?.filter(
    (q: any) =>
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
              <ZoeLogo size={40} />
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zoé Sleep</h1>
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
                href="/physician-dashboard/admin"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Shield className="w-5 h-5" />
                Admin
              </Link>
              <Link
                href="/physician-dashboard/settings"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Settings className="w-5 h-5" />
                Settings
              </Link>
              <PhysicianLogoutButton />
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
                const dayData = dayAssignments?.[day];
                const dayModules = dayData?.modules || [];
                const isExpanded = expandedDays.has(day);
                const totalQuestions = dayData?.total_questions || 0;
                const totalMinutes = dayData?.total_minutes || 0;
                const dayGateways = dayData?.gateways || [];

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
                          <div className="flex items-center gap-2">
                            <h3 className="font-semibold text-gray-900">Day {day}</h3>
                            {dayGateways.length > 0 && (
                              <span className="flex items-center gap-1 px-1.5 py-0.5 bg-amber-100 text-amber-700 rounded text-xs">
                                <Zap className="w-3 h-3" />
                                {dayGateways.length} gateway{dayGateways.length > 1 ? "s" : ""}
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-500">
                            {dayModules.length} modules &bull; {totalQuestions} questions
                            {totalMinutes > 0 && (
                              <span> &bull; ~{Math.ceil(totalMinutes)} min</span>
                            )}
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
                          {dayModules.map((dm: any, index: number) => {
                            const isModuleExpanded = expandedDayModuleId === dm.module.module_id;

                            return (
                              <div key={dm.module.module_id}>
                                <div
                                  onClick={() =>
                                    setExpandedDayModuleId(
                                      isModuleExpanded ? null : dm.module.module_id
                                    )
                                  }
                                  className={`flex items-center gap-3 p-3 bg-white rounded-lg border cursor-pointer transition-colors ${
                                    dm.is_expansion
                                      ? "border-dashed border-purple-300 bg-purple-50/50 hover:bg-purple-50"
                                      : "border-gray-200 hover:border-teal-300"
                                  }`}
                                >
                                  <GripVertical className="w-4 h-4 text-gray-400 cursor-grab" />
                                  <span className="text-sm text-gray-500 w-6">
                                    {index + 1}.
                                  </span>
                                  <div className="flex-1">
                                    <div className="flex items-center gap-2">
                                      <p className="font-medium text-gray-900">
                                        {dm.module.name}
                                      </p>
                                      {dm.is_expansion && (
                                        <span className="px-1.5 py-0.5 bg-purple-100 text-purple-600 text-xs rounded font-medium">
                                          EXPANSION
                                        </span>
                                      )}
                                      {dm.module.tier === "GATEWAY" && (
                                        <span className="px-1.5 py-0.5 bg-amber-100 text-amber-600 text-xs rounded font-medium">
                                          GATEWAY
                                        </span>
                                      )}
                                    </div>
                                    <p className="text-sm text-gray-500">
                                      {dm.module.question_count} questions
                                      {dm.module.estimated_minutes && (
                                        <span> &bull; ~{dm.module.estimated_minutes} min</span>
                                      )}
                                    </p>
                                  </div>
                                  <span
                                    className={`px-2 py-0.5 rounded text-xs font-medium ${
                                      pillarColors[dm.module.pillar]?.bg || "bg-gray-100"
                                    } ${pillarColors[dm.module.pillar]?.text || "text-gray-700"}`}
                                  >
                                    {dm.module.pillar}
                                  </span>
                                  {isModuleExpanded ? (
                                    <ChevronDown className="w-4 h-4 text-gray-400" />
                                  ) : (
                                    <ChevronRight className="w-4 h-4 text-gray-400" />
                                  )}
                                </div>

                                {/* Expanded Question List */}
                                {isModuleExpanded && moduleQuestions && (
                                  <div className="ml-10 mt-2 space-y-1 border-l-2 border-gray-200 pl-4">
                                    {moduleQuestions.map((q: any) => (
                                      <div
                                        key={q.question_id}
                                        className="p-2 bg-white rounded text-sm border border-gray-100"
                                      >
                                        <div className="flex items-start gap-2">
                                          <span className="font-mono text-xs text-gray-400 bg-gray-50 px-1 rounded shrink-0">
                                            {q.question_id}
                                          </span>
                                          <span className="text-gray-700">{q.question_text}</span>
                                        </div>
                                        <div className="flex items-center gap-2 mt-1 ml-8">
                                          <span className="text-xs text-gray-400">
                                            {q.answer_format}
                                          </span>
                                          {q.estimated_time_seconds && (
                                            <span className="text-xs text-gray-400 flex items-center gap-0.5">
                                              <Clock className="w-3 h-3" />
                                              {q.estimated_time_seconds}s
                                            </span>
                                          )}
                                        </div>
                                      </div>
                                    ))}
                                  </div>
                                )}
                              </div>
                            );
                          })}
                        </div>

                        {/* Gateway/Expansion Preview */}
                        {dayGateways.length > 0 && (
                          <div className="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
                            <h4 className="text-sm font-semibold text-amber-800 mb-3 flex items-center gap-2">
                              <Zap className="w-4 h-4" />
                              Gateway Triggers on This Day
                            </h4>
                            <div className="space-y-3">
                              {dayGateways.map((gateway: any) => {
                                const gatewayDetail = allGateways?.find(
                                  (g: any) => g.gateway_id === gateway.gateway_id
                                );

                                return (
                                  <div
                                    key={gateway.gateway_id}
                                    className="p-3 bg-white rounded border border-amber-100"
                                  >
                                    <div className="flex items-center gap-2 mb-1">
                                      <span className="px-2 py-0.5 bg-amber-100 text-amber-700 text-xs rounded font-medium">
                                        GATEWAY
                                      </span>
                                      <span className="font-medium text-gray-900">
                                        {gateway.name}
                                      </span>
                                    </div>
                                    <p className="text-sm text-gray-600 mb-2">
                                      {gateway.description}
                                    </p>
                                    <div className="text-xs text-gray-500 mb-2">
                                      Trigger questions: {gateway.trigger_question_ids?.join(", ")}
                                    </div>

                                    {/* Expansion modules that this gateway can trigger */}
                                    {gatewayDetail?.expansion_modules?.map((em: any) => (
                                      <div
                                        key={em.module_id}
                                        className="mt-2 p-2 bg-purple-50 rounded border border-dashed border-purple-200"
                                      >
                                        <div className="flex items-center justify-between mb-1">
                                          <div className="flex items-center gap-2">
                                            <span className="px-1.5 py-0.5 bg-purple-100 text-purple-600 text-xs rounded font-medium">
                                              EXPANSION
                                            </span>
                                            <span className="text-sm font-medium text-purple-700">
                                              {em.name}
                                            </span>
                                          </div>
                                          <span className="text-xs text-purple-500">
                                            {em.question_count} questions
                                            {em.estimated_minutes && ` • ~${em.estimated_minutes} min`}
                                          </span>
                                        </div>
                                        <p className="text-xs text-purple-600 italic">
                                          Unlocks if gateway condition is met
                                        </p>
                                      </div>
                                    ))}
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        )}
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
              {allModules?.map((module: NonNullable<typeof allModules>[number]) => {
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
                {filteredQuestions?.map((question: any) => {
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
