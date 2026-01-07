"use client";
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useQuery, useMutation, useAction } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import Link from "next/link";
import { useState } from "react";
import { useParams } from "next/navigation";
import { PhysicianLogoutButton } from "@/components/PhysicianAuthGuard";
import { Patient360Tab } from "@/components/patient";
import { MainDashboardTab } from "@/components/patient/tabs/MainDashboardTab";
import { AIInsightsTab } from "@/components/patient/tabs/AIInsightsTab";
import { ComplianceTab } from "@/components/patient/tabs/ComplianceTab";
import { ProtocolAssignment } from "@/components/physician/ProtocolAssignment";
import { ScoreDetailModal } from "@/components/physician";
import {
  ArrowLeft,
  Calendar,
  Clock,
  Activity,
  FileText,
  Pill,
  ChevronRight,
  Plus,
  Send,
  Sparkles,
  Users,
  ClipboardList,
  Settings,
  MessageSquare,
  CheckCircle,
  LayoutDashboard,
  Eye,
  Zap,
  Code,
  Shield,
} from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

type TabType = "overview" | "responses" | "questionnaires" | "ai-insights" | "compliance" | "interventions" | "notes";

const statusConfig: Record<
  string,
  { label: string; color: string; bgColor: string }
> = {
  intake_in_progress: {
    label: "In Progress",
    color: "text-blue-700",
    bgColor: "bg-blue-100",
  },
  pending_review: {
    label: "Pending Review",
    color: "text-amber-700",
    bgColor: "bg-amber-100",
  },
  under_review: {
    label: "Under Review",
    color: "text-purple-700",
    bgColor: "bg-purple-100",
  },
  interventions_prepared: {
    label: "Interventions Ready",
    color: "text-teal-700",
    bgColor: "bg-teal-100",
  },
  interventions_active: {
    label: "Active Treatment",
    color: "text-green-700",
    bgColor: "bg-green-100",
  },
};

export default function PatientDetailPage() {
  const params = useParams();
  const id = params.id as string;
  const userId = id as Id<"users">;

  const [activeTab, setActiveTab] = useState<TabType>("overview");
  const [selectedDay, setSelectedDay] = useState<number | null>(null);
  const [noteText, setNoteText] = useState("");
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [_isAnalyzing, setIsAnalyzing] = useState(false);
  const [selectedScore, setSelectedScore] = useState<{
    _id: string;
    questionnaire_name: string;
    score: number;
    max_score?: number;
    category?: string;
    interpretation?: string;
    calculated_at: number;
  } | null>(null);
  const [targetDay, setTargetDay] = useState<number>(1);
  const [isTogglingDevMode, setIsTogglingDevMode] = useState(false);
  const [isChangingDay, setIsChangingDay] = useState(false);
  const [showOnlyTriggered, setShowOnlyTriggered] = useState(false);

  // Queries
  const patient = useQuery(api.physician.getPatientDetails, { userId });
  const responsesByDay = useQuery(api.physician.getPatientResponsesByDay, {
    userId,
  });
  const dayData = useQuery(
    api.physician.getPatientDayData,
    selectedDay ? { userId, dayNumber: selectedDay } : "skip"
  );
  const scores = useQuery(api.physician.getQuestionnaireScores, { userId });
  const calculatedScores = useQuery(api.physician.calculatePatientScores, { userId });
  const interventions = useQuery(api.physician.getPatientInterventions, {
    userId,
  });
  const notes = useQuery(api.physician.getPhysicianNotes, { userId });
  const devModeStatus = useQuery(api.physician.getDeveloperModeStatus, { userId });

  // Mutations
  const saveNote = useMutation(api.physician.savePhysicianNote);
  const updateStatus = useMutation(api.physician.updatePatientReviewStatus);
  const toggleDeveloperMode = useMutation(api.physician.toggleDeveloperMode);
  const setPatientDay = useMutation(api.physician.setPatientDay);

  // Actions
  const analyzePatient = useAction(api.llm.analyzePatientResponses);

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [_analysis, setAnalysis] = useState<{
    summary: string;
    riskFactors: string[];
    recommendations: string[];
  } | null>(null);

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const handleAnalyze = async () => {
    setIsAnalyzing(true);
    try {
      const result = await analyzePatient({ userId });
      setAnalysis(result);
    } catch (error) {
      console.error("Analysis failed:", error);
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleSaveNote = async () => {
    if (!noteText.trim()) return;
    await saveNote({
      userId,
      dayNumber: selectedDay || undefined,
      noteText: noteText.trim(),
    });
    setNoteText("");
  };

  const handleStatusChange = async (newStatus: string) => {
    await updateStatus({ userId, status: newStatus });
  };

  const handleToggleDeveloperMode = async () => {
    if (!devModeStatus) return;
    setIsTogglingDevMode(true);
    try {
      await toggleDeveloperMode({
        userId,
        enabled: !devModeStatus.developerMode,
      });
    } finally {
      setIsTogglingDevMode(false);
    }
  };

  const handleSetDay = async () => {
    if (!devModeStatus?.developerMode) return;
    setIsChangingDay(true);
    try {
      await setPatientDay({
        userId,
        dayNumber: targetDay,
      });
    } finally {
      setIsChangingDay(false);
    }
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  if (!patient) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  const status = statusConfig[patient.reviewStatus?.status || "intake_in_progress"];

  const tabs: { id: TabType; label: string; icon: React.ReactNode }[] = [
    { id: "overview", label: "Main Dashboard", icon: <LayoutDashboard className="w-4 h-4" /> },
    {
      id: "responses",
      label: "Responses",
      icon: <FileText className="w-4 h-4" />,
    },
    { id: "questionnaires", label: "Questionnaires", icon: <Activity className="w-4 h-4" /> },
    { id: "ai-insights", label: "AI Insights", icon: <Sparkles className="w-4 h-4" /> },
    { id: "compliance", label: "Compliance", icon: <CheckCircle className="w-4 h-4" /> },
    {
      id: "interventions",
      label: "Interventions",
      icon: <Pill className="w-4 h-4" />,
    },
    {
      id: "notes",
      label: "Notes",
      icon: <MessageSquare className="w-4 h-4" />,
    },
  ];

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
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
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
        {/* Back Link */}
        <Link
          href="/physician-dashboard"
          className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Patients
        </Link>

        {/* Patient Header */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-bold text-2xl">
                {(patient.name || patient.user.username)?.[0]?.toUpperCase() || "?"}
              </div>
              <div>
                <h2 className="text-2xl font-bold text-gray-900">
                  {patient.name ? (
                    <>
                      {patient.name}
                      <span className="text-gray-400 font-normal text-lg ml-2">
                        ({patient.user.username})
                      </span>
                    </>
                  ) : (
                    patient.user.username
                  )}
                </h2>
                <div className="flex items-center gap-4 mt-1 text-sm text-gray-500">
                  {patient.demographics.dateOfBirth && (
                    <span>DOB: {patient.demographics.dateOfBirth}</span>
                  )}
                  {patient.demographics.sex && (
                    <span>Sex: {patient.demographics.sex}</span>
                  )}
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              {/* Developer Mode Badge */}
              {devModeStatus?.developerMode && (
                <span className="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 rounded text-xs font-medium">
                  <Code className="w-3 h-3" />
                  DEV
                </span>
              )}

              <span
                className={`px-3 py-1.5 rounded-full text-sm font-medium ${status.bgColor} ${status.color}`}
              >
                {status.label}
              </span>

              <select
                value={patient.reviewStatus?.status || "intake_in_progress"}
                onChange={(e) => handleStatusChange(e.target.value)}
                className="px-3 py-1.5 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="intake_in_progress">In Progress</option>
                <option value="pending_review">Pending Review</option>
                <option value="under_review">Under Review</option>
                <option value="interventions_prepared">
                  Interventions Ready
                </option>
                <option value="interventions_active">Active Treatment</option>
              </select>

              <Link
                href={`/physician-dashboard/patient/${id}/prescription`}
                className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
              >
                <Pill className="w-4 h-4" />
                Prescribe
              </Link>
            </div>
          </div>

          {/* Developer Mode Controls */}
          <div className="mt-4 pt-4 border-t border-gray-100">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <label className="flex items-center gap-2 cursor-pointer">
                  <span className="text-sm text-gray-600 flex items-center gap-1">
                    <Code className="w-4 h-4" />
                    Developer Mode
                  </span>
                  <button
                    onClick={handleToggleDeveloperMode}
                    disabled={isTogglingDevMode}
                    className={`relative w-11 h-6 rounded-full transition-colors ${
                      devModeStatus?.developerMode
                        ? "bg-purple-600"
                        : "bg-gray-300"
                    } ${isTogglingDevMode ? "opacity-50" : ""}`}
                  >
                    <span
                      className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-transform ${
                        devModeStatus?.developerMode ? "left-6" : "left-1"
                      }`}
                    />
                  </button>
                </label>
                <span className="text-xs text-gray-400">
                  Skip time gates & unlock any day
                </span>
              </div>

              {/* Day Selector (visible when dev mode is ON) */}
              {devModeStatus?.developerMode && (
                <div className="flex items-center gap-2">
                  <span className="text-sm text-gray-600">Jump to Day:</span>
                  <select
                    value={targetDay}
                    onChange={(e) => setTargetDay(Number(e.target.value))}
                    className="px-3 py-1.5 rounded-lg border border-purple-200 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 bg-purple-50"
                  >
                    {Array.from({ length: 10 }, (_, i) => i + 1).map((day) => (
                      <option key={day} value={day}>
                        Day {day}
                      </option>
                    ))}
                  </select>
                  <button
                    onClick={handleSetDay}
                    disabled={isChangingDay || targetDay === patient.user.current_day}
                    className="px-3 py-1.5 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isChangingDay ? "..." : "Go"}
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* Quick Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
            <div className="p-4 bg-gray-50 rounded-xl">
              <div className="flex items-center gap-2 text-gray-500 mb-1">
                <Calendar className="w-4 h-4" />
                <span className="text-sm">Day</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {patient.user.current_day}
                <span className="text-lg text-gray-400">/10</span>
              </p>
            </div>
            <div className="p-4 bg-gray-50 rounded-xl">
              <div className="flex items-center gap-2 text-gray-500 mb-1">
                <FileText className="w-4 h-4" />
                <span className="text-sm">Responses</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {patient.totalResponses}
              </p>
            </div>
            <div className="p-4 bg-gray-50 rounded-xl">
              <div className="flex items-center gap-2 text-gray-500 mb-1">
                <CheckCircle className="w-4 h-4" />
                <span className="text-sm">Days Done</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {patient.completedDays}
              </p>
            </div>
            <div className="p-4 bg-gray-50 rounded-xl">
              <div className="flex items-center gap-2 text-gray-500 mb-1">
                <Clock className="w-4 h-4" />
                <span className="text-sm">Started</span>
              </div>
              <p className="text-lg font-bold text-gray-900">
                {formatDate(patient.user.started_at)}
              </p>
            </div>
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors whitespace-nowrap ${
                activeTab === tab.id
                  ? "bg-teal-600 text-white"
                  : "bg-white text-gray-600 hover:bg-gray-100 border border-gray-200"
              }`}
            >
              {tab.icon}
              {tab.label}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <div className={`rounded-2xl border ${activeTab === "overview" ? "bg-gray-900 border-gray-700" : "bg-white border-gray-200"} p-6`}>
          {/* Overview Tab - Main Dashboard */}
          {activeTab === "overview" && (
            <MainDashboardTab userId={userId} patientId={id} patient={patient} />
          )}

          {/* Responses Tab */}
          {activeTab === "responses" && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Day List */}
              <div className="md:col-span-1">
                <h3 className="text-lg font-semibold mb-4">Days</h3>
                <div className="space-y-2">
                  {Array.from({ length: 10 }, (_, i) => i + 1).map((day) => {
                    const dayInfo = responsesByDay?.days.find(
                      // eslint-disable-next-line @typescript-eslint/no-explicit-any
                      (d: any) => d.dayNumber === day
                    );
                    const isSelected = selectedDay === day;
                    return (
                      <button
                        key={day}
                        onClick={() => setSelectedDay(day)}
                        className={`w-full flex items-center justify-between p-3 rounded-lg transition-colors ${
                          isSelected
                            ? "bg-teal-600 text-white"
                            : dayInfo
                              ? "bg-gray-50 hover:bg-gray-100 text-gray-900"
                              : "bg-gray-50 text-gray-400"
                        }`}
                      >
                        <span className="font-medium">Day {day}</span>
                        {dayInfo && (
                          <span
                            className={`text-sm ${isSelected ? "text-teal-100" : "text-gray-500"}`}
                          >
                            {dayInfo.responseCount} responses
                          </span>
                        )}
                        <ChevronRight className="w-4 h-4" />
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Response Details */}
              <div className="md:col-span-2">
                {selectedDay ? (
                  <>
                    <div className="flex items-center justify-between mb-4">
                      <h3 className="text-lg font-semibold">
                        Day {selectedDay} Responses
                      </h3>
                      <div className="flex items-center gap-2 text-sm">
                        <span className="flex items-center gap-1.5 px-2 py-1 bg-green-50 text-green-600 rounded-full">
                          <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                          Live
                        </span>
                      </div>
                    </div>
                    {dayData ? (
                      <div className="space-y-4">
                        {dayData.responses.length === 0 ? (
                          <p className="text-gray-500 text-center py-8">
                            No responses for this day yet.
                          </p>
                        ) : (
                          dayData.responses.map((response: any) => {
                            const isRecent = response.updated_at &&
                              (Date.now() - response.updated_at) < 5 * 60 * 1000; // Within 5 minutes
                            return (
                              <div
                                key={response._id}
                                className={`border rounded-lg p-4 transition-all ${
                                  isRecent
                                    ? "border-teal-300 bg-teal-50/30 ring-1 ring-teal-200"
                                    : "border-gray-200"
                                }`}
                              >
                                <div className="flex items-start justify-between mb-2">
                                  <div className="flex items-center gap-2">
                                    <span className="text-xs font-mono text-gray-400 bg-gray-100 px-2 py-0.5 rounded">
                                      {response.question_id}
                                    </span>
                                    {isRecent && (
                                      <span className="text-xs text-teal-600 bg-teal-100 px-2 py-0.5 rounded flex items-center gap-1">
                                        <span className="w-1.5 h-1.5 bg-teal-500 rounded-full animate-pulse" />
                                        Just received
                                      </span>
                                    )}
                                  </div>
                                  <div className="flex items-center gap-2">
                                    {response.pillar && (
                                      <span className="text-xs text-purple-600 bg-purple-50 px-2 py-0.5 rounded">
                                        {response.pillar}
                                      </span>
                                    )}
                                  </div>
                                </div>
                                <p className="text-gray-700 mb-2">
                                  {response.question_text || "Question text not available"}
                                </p>
                                <p className="font-medium text-gray-900 bg-gray-50 p-2 rounded">
                                  {response.response_value || "No response"}
                                </p>
                                {response.updated_at && (
                                  <p className="text-xs text-gray-400 mt-2 flex items-center gap-1">
                                    <Clock className="w-3 h-3" />
                                    {new Date(response.updated_at).toLocaleString()}
                                  </p>
                                )}
                              </div>
                            );
                          })
                        )}
                      </div>
                    ) : (
                      <div className="flex items-center justify-center py-8">
                        <div className="animate-spin w-6 h-6 border-2 border-teal-500 border-t-transparent rounded-full" />
                      </div>
                    )}
                  </>
                ) : (
                  <div className="flex flex-col items-center justify-center py-12 text-gray-500">
                    <FileText className="w-12 h-12 mb-4 text-gray-300" />
                    <p>Select a day to view responses</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Questionnaires Tab (renamed from Scores) */}
          {activeTab === "questionnaires" && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">
                  Questionnaire Scores
                </h3>
                <div className="flex items-center gap-4">
                  {/* Filter Toggle */}
                  <label className="flex items-center gap-2 cursor-pointer">
                    <span className="text-sm text-gray-600">Show only triggered</span>
                    <button
                      onClick={() => setShowOnlyTriggered(!showOnlyTriggered)}
                      className={`relative w-10 h-5 rounded-full transition-colors ${
                        showOnlyTriggered ? "bg-teal-600" : "bg-gray-300"
                      }`}
                    >
                      <span
                        className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${
                          showOnlyTriggered ? "left-5" : "left-0.5"
                        }`}
                      />
                    </button>
                  </label>
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    <Zap className="w-4 h-4 text-teal-500" />
                    <span>Real-time</span>
                  </div>
                </div>
              </div>

              {/* Calculated Scores (real-time from responses) */}
              {calculatedScores && calculatedScores.scores.length > 0 && (
                <div className="mb-6">
                  <h4 className="text-sm font-medium text-gray-500 mb-3 flex items-center gap-2">
                    <Activity className="w-4 h-4" />
                    Live Calculated Scores
                    {showOnlyTriggered && (
                      <span className="text-xs text-teal-600 bg-teal-50 px-2 py-0.5 rounded-full">
                        Filtered: {calculatedScores.scores.filter((s: any) => s.score !== null || s.questionsAnswered > 0).length} with data
                      </span>
                    )}
                  </h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {calculatedScores.scores
                      .filter((score: any) => {
                        // Core questionnaires (Days 1-2) always show when filter is on
                        const coreQuestionnaires = ["PSQI"];
                        const isCore = coreQuestionnaires.includes(score.abbreviation);
                        // Show if: filter off, OR is core, OR has data
                        return !showOnlyTriggered || isCore || score.score !== null || score.questionsAnswered > 0;
                      })
                      .map((score: any) => {
                      // Core questionnaires completed in Days 1-2 (not expansion)
                      const coreQuestionnaires = ["PSQI"];
                      const isCore = coreQuestionnaires.includes(score.abbreviation);
                      const severityColors: Record<string, string> = {
                        normal: "border-green-200 bg-green-50",
                        mild: "border-yellow-200 bg-yellow-50",
                        moderate: "border-orange-200 bg-orange-50",
                        severe: "border-red-200 bg-red-50",
                        unknown: "border-gray-200 bg-gray-50",
                      };
                      const severityTextColors: Record<string, string> = {
                        normal: "text-green-600",
                        mild: "text-yellow-600",
                        moderate: "text-orange-600",
                        severe: "text-red-600",
                        unknown: "text-gray-600",
                      };
                      return (
                        <div
                          key={score.abbreviation}
                          onClick={() => score.score !== null && setSelectedScore({
                            _id: score.abbreviation,
                            questionnaire_name: score.name,
                            score: score.score,
                            max_score: score.maxScore,
                            category: score.severity,
                            interpretation: score.interpretation,
                            calculated_at: Date.now(),
                          })}
                          className={`border rounded-xl p-4 cursor-pointer hover:shadow-md transition-all ${severityColors[score.severity] || severityColors.unknown}`}
                        >
                          <div className="flex items-center justify-between mb-2">
                            <div className="flex items-center gap-2">
                              <span className="text-xs font-bold text-gray-500">{score.abbreviation}</span>
                              {isCore && (
                                <span className="text-[10px] font-medium text-blue-600 bg-blue-100 px-1.5 py-0.5 rounded">
                                  Core
                                </span>
                              )}
                            </div>
                            {score.score !== null ? (
                              <span className={`text-2xl font-bold ${severityTextColors[score.severity]}`}>
                                {score.score}
                                <span className="text-sm text-gray-400">/{score.maxScore}</span>
                              </span>
                            ) : (
                              <span className="text-sm text-gray-400">
                                {score.questionsAnswered}/{score.questionsRequired} answered
                              </span>
                            )}
                          </div>
                          <p className="text-sm font-medium text-gray-900 mb-1">{score.name}</p>
                          <p className="text-xs text-gray-600">{score.interpretation}</p>
                          {score.score !== null && (
                            <div className="mt-2 pt-2 border-t border-gray-200/50 flex items-center justify-between">
                              <span className={`text-xs font-medium capitalize ${severityTextColors[score.severity]}`}>
                                {score.severity}
                              </span>
                              <span className="text-xs text-teal-600 flex items-center gap-1">
                                <Eye className="w-3 h-3" />
                                View details
                              </span>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Gateway Triggers */}
              {calculatedScores && (
                <div className="mb-6 p-4 bg-gray-50 rounded-xl border border-gray-200">
                  <h4 className="text-sm font-medium text-gray-700 mb-3">Gateway Triggers</h4>
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(calculatedScores.gateways).map(([key, triggered]) => (
                      <span
                        key={key}
                        className={`px-3 py-1 rounded-full text-xs font-medium ${
                          triggered
                            ? "bg-amber-100 text-amber-700 border border-amber-200"
                            : "bg-gray-100 text-gray-500"
                        }`}
                      >
                        {key.replace(/([A-Z])/g, " $1").trim()}
                        {triggered ? " ✓" : ""}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Sleep Metrics */}
              {calculatedScores?.sleepMetrics && calculatedScores.sleepMetrics.daysLogged > 0 && (
                <div className="mb-6 p-4 bg-blue-50 rounded-xl border border-blue-200">
                  <h4 className="text-sm font-medium text-blue-700 mb-3">Sleep Log Metrics ({calculatedScores.sleepMetrics.daysLogged} days)</h4>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    {calculatedScores.sleepMetrics.avgBedtime && (
                      <div>
                        <p className="text-xs text-blue-600">Avg Bedtime</p>
                        <p className="text-lg font-semibold text-blue-900">{calculatedScores.sleepMetrics.avgBedtime}</p>
                      </div>
                    )}
                    {calculatedScores.sleepMetrics.avgWakeTime && (
                      <div>
                        <p className="text-xs text-blue-600">Avg Wake Time</p>
                        <p className="text-lg font-semibold text-blue-900">{calculatedScores.sleepMetrics.avgWakeTime}</p>
                      </div>
                    )}
                    {calculatedScores.sleepMetrics.avgSleepQuality !== undefined && (
                      <div>
                        <p className="text-xs text-blue-600">Avg Quality</p>
                        <p className="text-lg font-semibold text-blue-900">{calculatedScores.sleepMetrics.avgSleepQuality.toFixed(1)}/10</p>
                      </div>
                    )}
                    {calculatedScores.sleepMetrics.avgAwakenings !== undefined && (
                      <div>
                        <p className="text-xs text-blue-600">Avg Awakenings</p>
                        <p className="text-lg font-semibold text-blue-900">{calculatedScores.sleepMetrics.avgAwakenings.toFixed(1)}</p>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Saved Scores (from database) */}
              {scores && scores.length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-3">Saved Scores History</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {scores.map((score: any) => (
                      <div
                        key={score._id}
                        onClick={() => setSelectedScore(score)}
                        className="border border-gray-200 rounded-xl p-4 cursor-pointer hover:border-teal-300 hover:bg-teal-50/30 transition-all group"
                      >
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-2">
                            <h4 className="font-semibold text-gray-900">
                              {score.questionnaire_name}
                            </h4>
                            <Eye className="w-4 h-4 text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity" />
                          </div>
                          <span className="text-2xl font-bold text-teal-600">
                            {score.score}
                            {score.max_score && (
                              <span className="text-lg text-gray-400">
                                /{score.max_score}
                              </span>
                            )}
                          </span>
                        </div>
                        {score.category && (
                          <span className="inline-block px-2 py-0.5 bg-gray-100 text-gray-700 rounded text-sm mb-2">
                            {score.category}
                          </span>
                        )}
                        {score.interpretation && (
                          <p className="text-gray-600 text-sm">
                            {score.interpretation}
                          </p>
                        )}
                        <div className="mt-2 pt-2 border-t border-gray-100 flex items-center justify-between text-xs text-gray-400">
                          <span>Saved {new Date(score.calculated_at).toLocaleDateString()}</span>
                          <span className="text-teal-500 opacity-0 group-hover:opacity-100 transition-opacity">
                            Click for detailed analysis
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Empty state - only show if no calculated scores either */}
              {(!calculatedScores || calculatedScores.scores.every((s: any) => s.score === null)) && (!scores || scores.length === 0) && (
                <div className="text-center py-12 text-gray-500">
                  <Activity className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                  <p>No scores available yet.</p>
                  <p className="text-sm mt-1">
                    Scores are calculated as the patient answers standardized questionnaires (ISI, PHQ-9, GAD-7, ESS).
                  </p>
                </div>
              )}
            </div>
          )}

          {/* AI Insights Tab */}
          {activeTab === "ai-insights" && (
            <AIInsightsTab userId={userId} patientId={id} />
          )}

          {/* Compliance Tab */}
          {activeTab === "compliance" && (
            <ComplianceTab userId={userId} />
          )}

          {/* Interventions Tab */}
          {activeTab === "interventions" && (
            <div className="space-y-6">
              {/* Header with Action Button */}
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">Treatment Plan</h3>
                <Link
                  href={`/physician-dashboard/patient/${id}/prescription`}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-purple-600 to-teal-600 text-white rounded-lg hover:opacity-90 transition-opacity"
                >
                  <Sparkles className="w-4 h-4" />
                  Prescribe Interventions
                </Link>
              </div>

              {/* Active Interventions */}
              {interventions && interventions.filter((i: any) => i.status === "active").length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-3 flex items-center gap-2">
                    <CheckCircle className="w-4 h-4 text-green-500" />
                    Active Interventions ({interventions.filter((i: any) => i.status === "active").length})
                  </h4>
                  <div className="grid gap-3">
                    {interventions.filter((i: any) => i.status === "active").map((intervention: any) => (
                      <div
                        key={intervention._id}
                        className="border border-green-200 bg-green-50/50 rounded-xl p-4"
                      >
                        <div className="flex items-start justify-between mb-2">
                          <div>
                            <h4 className="font-semibold text-gray-900">
                              {intervention.intervention_name}
                            </h4>
                            <div className="flex items-center gap-3 mt-1 text-sm text-gray-600">
                              {intervention.frequency && (
                                <span className="flex items-center gap-1">
                                  <Clock className="w-3 h-3" />
                                  {intervention.frequency}
                                </span>
                              )}
                              {intervention.timing && (
                                <span className="px-2 py-0.5 bg-white rounded text-xs">
                                  {intervention.timing}
                                </span>
                              )}
                            </div>
                          </div>
                          <span className="px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-medium">
                            Active
                          </span>
                        </div>
                        <div className="flex items-center gap-4 text-xs text-gray-500 mt-2">
                          <span>Started: {intervention.start_date}</span>
                          {intervention.end_date && (
                            <span>Ends: {intervention.end_date}</span>
                          )}
                        </div>
                        {intervention.custom_instructions && (
                          <p className="mt-3 text-sm text-gray-600 bg-white p-2 rounded border border-gray-100">
                            {intervention.custom_instructions}
                          </p>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Draft Interventions */}
              {interventions && interventions.filter((i: any) => i.status === "draft").length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-3 flex items-center gap-2">
                    <Clock className="w-4 h-4 text-amber-500" />
                    Pending Activation ({interventions.filter((i: any) => i.status === "draft").length})
                  </h4>
                  <div className="grid gap-3">
                    {interventions.filter((i: any) => i.status === "draft").map((intervention: any) => (
                      <div
                        key={intervention._id}
                        className="border border-amber-200 bg-amber-50/50 rounded-xl p-4"
                      >
                        <div className="flex items-start justify-between mb-2">
                          <h4 className="font-semibold text-gray-900">
                            {intervention.intervention_name}
                          </h4>
                          <span className="px-2 py-1 bg-amber-100 text-amber-700 rounded text-xs font-medium">
                            Draft
                          </span>
                        </div>
                        <div className="flex items-center gap-3 text-sm text-gray-600">
                          {intervention.frequency && (
                            <span>{intervention.frequency}</span>
                          )}
                          {intervention.timing && (
                            <span>{intervention.timing}</span>
                          )}
                          <span className="text-gray-400">•</span>
                          <span>Scheduled: {intervention.start_date}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                  <Link
                    href={`/physician-dashboard/patient/${id}/prescription`}
                    className="mt-3 inline-flex items-center gap-2 px-4 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors text-sm"
                  >
                    Review & Activate
                    <ChevronRight className="w-4 h-4" />
                  </Link>
                </div>
              )}

              {/* Empty State */}
              {(!interventions || interventions.length === 0) && (
                <div className="text-center py-12 bg-gray-50 rounded-xl border-2 border-dashed border-gray-200">
                  <Pill className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                  <p className="text-gray-600 font-medium">No interventions prescribed yet</p>
                  <p className="text-sm text-gray-500 mt-1 mb-4">
                    Create a personalized treatment plan for this patient
                  </p>
                  <Link
                    href={`/physician-dashboard/patient/${id}/prescription`}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                    Create Treatment Plan
                  </Link>
                </div>
              )}

              {/* Completed/Cancelled Interventions */}
              {interventions && interventions.filter((i: any) => i.status === "completed" || i.status === "cancelled").length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-500 mb-3">
                    Past Interventions
                  </h4>
                  <div className="grid gap-2">
                    {interventions.filter((i: any) => i.status === "completed" || i.status === "cancelled").map((intervention: any) => (
                      <div
                        key={intervention._id}
                        className="border border-gray-200 bg-gray-50 rounded-lg p-3 opacity-70"
                      >
                        <div className="flex items-center justify-between">
                          <span className="text-gray-700">{intervention.intervention_name}</span>
                          <span className="px-2 py-0.5 bg-gray-200 text-gray-600 rounded text-xs">
                            {intervention.status}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Protocol Assignment */}
              <div className="mt-6">
                <ProtocolAssignment userId={userId} physicianId={id} />
              </div>
            </div>
          )}

          {/* Notes Tab */}
          {activeTab === "notes" && (
            <div>
              <h3 className="text-lg font-semibold mb-4">Physician Notes</h3>

              {/* Add Note Form */}
              <div className="mb-6 p-4 border border-gray-200 rounded-xl">
                <textarea
                  value={noteText}
                  onChange={(e) => setNoteText(e.target.value)}
                  placeholder="Add a note about this patient..."
                  className="w-full p-3 border border-gray-200 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-teal-500"
                  rows={3}
                />
                <div className="flex justify-end mt-2">
                  <button
                    onClick={handleSaveNote}
                    disabled={!noteText.trim()}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Send className="w-4 h-4" />
                    Save Note
                  </button>
                </div>
              </div>

              {/* Notes List */}
              {notes && notes.length > 0 ? (
                <div className="space-y-4">
                  {notes.map((note: any) => (
                    <div
                      key={note._id}
                      className="border border-gray-200 rounded-lg p-4"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-gray-500">
                          {note.day_number
                            ? `Day ${note.day_number}`
                            : "General Note"}
                        </span>
                        <span className="text-xs text-gray-400">
                          {formatDate(note.created_at)}
                        </span>
                      </div>
                      <p className="text-gray-700">{note.note_text}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-gray-500">
                  <MessageSquare className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                  <p>No notes yet. Add your first note above.</p>
                </div>
              )}
            </div>
          )}
        </div>
      </main>

      {/* Score Detail Modal */}
      {selectedScore && (
        <ScoreDetailModal
          isOpen={!!selectedScore}
          onClose={() => setSelectedScore(null)}
          userId={userId}
          score={selectedScore}
        />
      )}
    </div>
  );
}
