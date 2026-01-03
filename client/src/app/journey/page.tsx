"use client";

import { useEffect, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import { QuestionRenderer } from "@/components/questions";
import { ResponseValue } from "@/components/questions/types";
import {
  ChevronLeft,
  ChevronRight,
  Moon,
  ClipboardList,
  CheckCircle,
  Home,
  X,
  Sparkles,
  AlertCircle,
} from "lucide-react";
import { useCircadianTheme } from "@/hooks/useCircadianTheme";
import { useConvexUser, useJourneyState } from "@/hooks/useConvexUser";
import { useConvexQuestionnaire, useSectionManager } from "@/hooks/useConvexQuestionnaire";
import { SignInButton, useAuth, UserButton } from "@clerk/nextjs";

// Section types
type QuestionnaireSection = "sleepLog" | "assessment";

// Section styles matching iOS
const sectionStyles = {
  sleepLog: {
    color: "#2196F3",
    bgColor: "bg-blue-500",
    bgLight: "bg-blue-50",
    textColor: "text-blue-600",
    borderColor: "border-blue-200",
    gradient: "from-blue-500 to-blue-600",
    icon: Moon,
    title: "SLEEP LOG",
    subtitle: "Stanford Sleep Diary",
  },
  assessment: {
    color: "#9C27B0",
    bgColor: "bg-purple-500",
    bgLight: "bg-purple-50",
    textColor: "text-purple-600",
    borderColor: "border-purple-200",
    gradient: "from-purple-500 to-purple-600",
    icon: ClipboardList,
    title: "ASSESSMENT",
    subtitle: "Day Assessment",
  },
};

// Day configuration titles
const dayConfigurations: Record<number, { title: string; description: string }> = {
  1: { title: "Demographics & Sleep Quality", description: "Tell us about yourself and your sleep habits" },
  2: { title: "PSQI & Sleep Patterns", description: "Detailed sleep quality assessment" },
  3: { title: "Sleep Timing & Mental Health", description: "Understand your sleep schedule" },
  4: { title: "Physical & Metabolic Health", description: "Health factors affecting sleep" },
  5: { title: "Nutritional & Social Factors", description: "Lifestyle influences on sleep" },
  6: { title: "Insomnia Assessment", description: "ISI & DBAS-16 questionnaires" },
  7: { title: "Sleepiness Assessment", description: "ESS & FSS scales" },
  8: { title: "Mental Health Deep Dive", description: "PHQ-9 & GAD-7 assessments" },
  9: { title: "Function & Behavior", description: "Sleep habits, pain, and functional outcomes" },
  10: { title: "Lifestyle & Rhythm", description: "Cognitive function, diet, and chronotype" },
};

function normalizeSection(section: string | null): QuestionnaireSection {
  if (!section) return "sleepLog";
  const lower = section.toLowerCase();
  if (lower === "sleeplog" || lower === "sleep-log" || lower === "sleep_log") return "sleepLog";
  if (lower === "assessment") return "assessment";
  return "sleepLog";
}

function JourneyPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialSection = normalizeSection(searchParams.get("section"));
  const dayParam = searchParams.get("day");

  // Auth
  const { isSignedIn } = useAuth();
  const { userId, isLoading: userLoading, error: userError } = useConvexUser();

  // Theme
  const { textClasses, bgClasses, cardClasses, buttonClasses, isWarm } = useCircadianTheme();

  // Journey state
  const { currentDay: journeyCurrentDay, sleepLogCompleted, assessmentCompleted } = useJourneyState();
  const currentDay = dayParam ? parseInt(dayParam, 10) : journeyCurrentDay;

  // Section management
  const {
    currentSection,
    setCurrentSection,
    showSectionTransition,
    showDayCompletion,
    handleSectionComplete,
    continueToAssessment,
  } = useSectionManager(userId, currentDay);

  // Initialize section from URL or journey state
  useEffect(() => {
    if (initialSection) {
      setCurrentSection(initialSection);
    } else if (sleepLogCompleted && !assessmentCompleted) {
      setCurrentSection("assessment");
    }
  }, [initialSection, sleepLogCompleted, assessmentCompleted, setCurrentSection]);

  // Questionnaire logic
  const {
    currentQuestion,
    currentQuestionIndex,
    totalQuestions,
    questions,
    progress,
    isLoading: questionsLoading,
    isSaving,
    saveError,
    currentResponse,
    responses,
    isResponseValid,
    metadata,
    saveResponse,
    goToNextQuestion,
    goToPreviousQuestion,
    completeSection,
    clearError,
  } = useConvexQuestionnaire({
    userId,
    dayNumber: currentDay,
    section: currentSection,
  });

  const sectionStyle = sectionStyles[currentSection];
  const SectionIcon = sectionStyle.icon;
  const dayConfig = dayConfigurations[currentDay] || { title: `Day ${currentDay}`, description: "" };

  // Handlers
  const handleResponseChange = (questionId: string, value: ResponseValue) => {
    saveResponse(questionId, value);
  };

  const handleNext = async () => {
    const result = await goToNextQuestion();

    if (result?.sectionComplete) {
      try {
        await completeSection();
        handleSectionComplete(currentSection);
      } catch {
        // Error already handled in hook
      }
    }
  };

  const handlePrevious = () => {
    goToPreviousQuestion();
  };

  const handleContinueToAssessment = () => {
    continueToAssessment();
  };

  const handleDayComplete = () => {
    if (currentDay >= 15) {
      router.push("/treatment");
    } else {
      router.push("/dashboard");
    }
  };

  // === RENDER STATES ===

  // Not signed in
  if (!isSignedIn) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center p-4`}>
        <div className={`max-w-md w-full ${cardClasses.combined} rounded-2xl shadow-lg p-8 text-center`}>
          <div className={`w-16 h-16 mx-auto mb-4 ${isWarm ? "bg-[#F28C40]/20" : "bg-blue-100"} rounded-full flex items-center justify-center`}>
            <Moon className={`w-8 h-8 ${isWarm ? "text-[#F28C40]" : "text-blue-600"}`} />
          </div>
          <h2 className={`text-xl font-bold mb-2 ${textClasses.primary}`}>Welcome to Zoe Sleep</h2>
          <p className={`mb-6 ${textClasses.secondary}`}>Sign in to start your 10-day sleep journey</p>
          <SignInButton mode="modal">
            <button className={`w-full py-3 px-6 ${buttonClasses.primary} font-semibold rounded-xl`}>
              Sign In to Continue
            </button>
          </SignInButton>
        </div>
      </div>
    );
  }

  // Loading user
  if (userLoading) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center`}>
        <div className="text-center">
          <div className={`animate-spin rounded-full h-12 w-12 border-b-2 ${isWarm ? "border-[#F28C40]" : "border-blue-600"} mx-auto mb-4`}></div>
          <p className={textClasses.secondary}>Setting up your journey...</p>
        </div>
      </div>
    );
  }

  // User error
  if (userError) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center p-4`}>
        <div className={`max-w-md w-full ${cardClasses.combined} rounded-2xl shadow-lg p-8 text-center`}>
          <div className={`w-16 h-16 mx-auto mb-4 ${isWarm ? "bg-[#F87171]/20" : "bg-red-100"} rounded-full flex items-center justify-center`}>
            <X className={`w-8 h-8 ${isWarm ? "text-[#F87171]" : "text-red-500"}`} />
          </div>
          <h2 className={`text-xl font-bold mb-2 ${textClasses.primary}`}>Setup Error</h2>
          <p className={`mb-6 ${textClasses.secondary}`}>{userError}</p>
          <button
            onClick={() => window.location.reload()}
            className={`px-6 py-2 ${buttonClasses.primary} rounded-lg`}
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  // Section Transition View
  if (showSectionTransition) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center p-4`}>
        <div className={`max-w-md w-full ${cardClasses.combined} rounded-2xl shadow-lg p-8 text-center`}>
          <div className="w-20 h-20 mx-auto mb-6 relative">
            <div className={`absolute inset-0 ${isWarm ? "bg-[#34D399]/20" : "bg-green-100"} rounded-full animate-ping opacity-50`}></div>
            <div className={`relative w-20 h-20 ${isWarm ? "bg-[#34D399]" : "bg-green-500"} rounded-full flex items-center justify-center`}>
              <CheckCircle className="w-10 h-10 text-white" />
            </div>
          </div>

          <h2 className={`text-2xl font-bold mb-2 ${textClasses.primary}`}>Sleep Log Complete!</h2>
          <p className={`mb-8 ${textClasses.secondary}`}>Great job recording your sleep data</p>

          <div className={`border-t ${isWarm ? "border-[#5C3D2E]" : "border-gray-100"} pt-6 mb-6`}>
            <p className={`text-sm uppercase tracking-wide mb-4 ${textClasses.muted}`}>Up Next</p>
            <div className={`${isWarm ? "bg-[#4A3020]" : sectionStyles.assessment.bgLight} rounded-xl p-4 text-left`}>
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 ${sectionStyles.assessment.bgColor} rounded-lg flex items-center justify-center`}>
                  <ClipboardList className="w-5 h-5 text-white" />
                </div>
                <div>
                  <span className={`text-xs font-semibold ${isWarm ? "text-[#F28C40]" : sectionStyles.assessment.textColor}`}>
                    {sectionStyles.assessment.title}
                  </span>
                  <h3 className={`font-medium ${textClasses.primary}`}>{dayConfig.title}</h3>
                  <p className={`text-sm ${textClasses.muted}`}>{metadata?.assessmentCount || 0} questions</p>
                </div>
              </div>
            </div>
          </div>

          <button
            onClick={handleContinueToAssessment}
            className={`w-full py-3 px-6 ${isWarm ? buttonClasses.primary : `bg-gradient-to-r ${sectionStyles.assessment.gradient} text-white`} font-semibold rounded-xl hover:opacity-90 transition-opacity`}
          >
            Continue to Assessment
          </button>
        </div>
      </div>
    );
  }

  // Day Completion View
  if (showDayCompletion) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center p-4`}>
        <div className={`max-w-md w-full ${cardClasses.combined} rounded-2xl shadow-lg p-8 text-center`}>
          <div className="w-24 h-24 mx-auto mb-6 relative">
            <div className={`absolute inset-0 ${isWarm ? "bg-[#34D399]/20" : "bg-green-100"} rounded-full animate-ping opacity-50`}></div>
            <div className={`relative w-24 h-24 ${isWarm ? "bg-gradient-to-br from-[#F28C40] to-[#D97706]" : "bg-gradient-to-br from-green-400 to-emerald-500"} rounded-full flex items-center justify-center`}>
              <Sparkles className="w-12 h-12 text-white" />
            </div>
          </div>

          <h2 className={`text-2xl font-bold mb-2 ${textClasses.primary}`}>Day {currentDay} Complete!</h2>
          <p className={`mb-6 ${textClasses.secondary}`}>Excellent work on your sleep journey</p>

          <div className="grid grid-cols-2 gap-3 mb-6">
            <div className={`${isWarm ? "bg-[#4A3020]" : sectionStyles.sleepLog.bgLight} rounded-xl p-4`}>
              <Moon className={`w-6 h-6 ${isWarm ? "text-[#F28C40]" : sectionStyles.sleepLog.textColor} mx-auto mb-2`} />
              <p className={`text-sm font-medium ${textClasses.primary}`}>Sleep Log</p>
              <p className={`text-xs ${textClasses.muted}`}>{metadata?.sleepLogCount || 0} questions</p>
            </div>
            <div className={`${isWarm ? "bg-[#4A3020]" : sectionStyles.assessment.bgLight} rounded-xl p-4`}>
              <ClipboardList className={`w-6 h-6 ${isWarm ? "text-[#F28C40]" : sectionStyles.assessment.textColor} mx-auto mb-2`} />
              <p className={`text-sm font-medium ${textClasses.primary}`}>Assessment</p>
              <p className={`text-xs ${textClasses.muted}`}>{metadata?.assessmentCount || 0} questions</p>
            </div>
          </div>

          {currentDay < 15 ? (
            <button
              onClick={handleDayComplete}
              className={`w-full py-3 px-6 ${isWarm ? buttonClasses.primary : "bg-gradient-to-r from-green-500 to-emerald-500 text-white"} font-semibold rounded-xl hover:opacity-90 transition-opacity`}
            >
              Continue to Day {currentDay + 1}
            </button>
          ) : (
            <button
              onClick={handleDayComplete}
              className={`w-full py-3 px-6 ${isWarm ? buttonClasses.primary : "bg-gradient-to-r from-purple-500 to-pink-500 text-white"} font-semibold rounded-xl hover:opacity-90 transition-opacity`}
            >
              Complete Journey
            </button>
          )}
        </div>
      </div>
    );
  }

  // Loading questions
  if (questionsLoading) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center`}>
        <div className="text-center">
          <div className={`animate-spin rounded-full h-12 w-12 border-b-2 ${isWarm ? "border-[#F28C40]" : "border-blue-600"} mx-auto mb-4`}></div>
          <p className={textClasses.secondary}>Loading your assessment...</p>
        </div>
      </div>
    );
  }

  // No questions available
  if (questions.length === 0) {
    return (
      <div className={`min-h-screen ${bgClasses} flex items-center justify-center p-4`}>
        <div className={`max-w-md w-full ${cardClasses.combined} rounded-2xl shadow-lg p-8 text-center`}>
          <div className={`w-16 h-16 mx-auto mb-4 ${isWarm ? "bg-[#F28C40]/20" : "bg-blue-100"} rounded-full flex items-center justify-center`}>
            <CheckCircle className={`w-8 h-8 ${isWarm ? "text-[#F28C40]" : "text-blue-600"}`} />
          </div>
          <h2 className={`text-xl font-bold mb-2 ${textClasses.primary}`}>No Questions Today</h2>
          <p className={`mb-6 ${textClasses.secondary}`}>
            {currentSection === "sleepLog"
              ? "Sleep log has been completed for today."
              : "No assessment questions for today based on your profile."}
          </p>
          <Link
            href="/dashboard"
            className={`inline-block px-6 py-2 ${buttonClasses.primary} rounded-lg`}
          >
            Return to Dashboard
          </Link>
        </div>
      </div>
    );
  }

  // Main questionnaire view
  return (
    <div className={`min-h-screen ${bgClasses}`}>
      {/* Section Header */}
      <header className={`${isWarm ? "bg-gradient-to-r from-[#F28C40] to-[#D97706]" : `bg-gradient-to-r ${sectionStyle.gradient}`} text-white`}>
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <Link href="/dashboard" className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                <Home className="w-5 h-5" />
              </Link>
              <UserButton afterSignOutUrl="/" />
            </div>
            <div className="flex items-center gap-2">
              <SectionIcon className="w-5 h-5" />
              <span className="font-semibold">{sectionStyle.title}</span>
            </div>
            <span className="text-sm opacity-80">
              {currentQuestionIndex + 1}/{totalQuestions}
            </span>
          </div>
          <p className="text-sm opacity-80 text-center">{sectionStyle.subtitle}</p>
        </div>

        {/* Progress Bar */}
        <div className="h-2 bg-white/20">
          <div
            className="h-full bg-white transition-all duration-300"
            style={{ width: `${progress}%` }}
          />
        </div>
      </header>

      {/* Day Info */}
      <div className={`max-w-2xl mx-auto px-4 py-3 border-b ${isWarm ? "border-[#5C3D2E] bg-[#3D2418]/50" : "border-gray-100 bg-white/50"}`}>
        <div className="flex items-center justify-between">
          <div>
            <span className={`text-sm ${textClasses.muted}`}>Day {currentDay} of 10</span>
            {currentSection === "assessment" && (
              <h2 className={`font-medium ${textClasses.primary}`}>{dayConfig.title}</h2>
            )}
          </div>
          {/* Progress Dots */}
          <div className="flex gap-1 flex-wrap max-w-[120px] justify-end">
            {questions.slice(0, 15).map((_, idx) => (
              <div
                key={idx}
                className={`w-2 h-2 rounded-full transition-all ${
                  idx < currentQuestionIndex
                    ? isWarm
                      ? "bg-[#34D399]"
                      : "bg-green-500"
                    : idx === currentQuestionIndex
                    ? isWarm
                      ? "bg-[#F28C40]"
                      : sectionStyle.bgColor
                    : isWarm
                    ? "bg-[#5C3D2E]"
                    : "bg-gray-200"
                }`}
              />
            ))}
            {questions.length > 15 && (
              <span className={`text-xs ${textClasses.muted}`}>+{questions.length - 15}</span>
            )}
          </div>
        </div>
      </div>

      {/* Save Error Banner */}
      {saveError && (
        <div className={`max-w-2xl mx-auto px-4 py-2`}>
          <div className={`flex items-center gap-2 p-3 ${isWarm ? "bg-[#F87171]/20 text-[#FCA5A5]" : "bg-red-50 text-red-600"} rounded-lg`}>
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span className="text-sm">{saveError}</span>
            <button onClick={clearError} className="ml-auto text-sm underline">
              Dismiss
            </button>
          </div>
        </div>
      )}

      {/* Question Content */}
      <main className="max-w-2xl mx-auto px-4 py-8 pb-24">
        {currentQuestion && (
          <div className={`${cardClasses.combined} rounded-2xl shadow-sm border p-6`}>
            <QuestionRenderer
              question={currentQuestion}
              value={currentResponse ?? null}
              onChange={(value) => handleResponseChange(currentQuestion.question_id, value)}
              previousResponses={responses}
            />
          </div>
        )}
      </main>

      {/* Navigation Footer */}
      <footer className={`fixed bottom-0 left-0 right-0 ${isWarm ? "bg-[#2D1A14] border-[#5C3D2E]" : "bg-white border-gray-100"} border-t p-4`}>
        <div className="max-w-2xl mx-auto flex items-center justify-between gap-4">
          <button
            onClick={handlePrevious}
            disabled={currentQuestionIndex === 0}
            className={`flex items-center gap-2 px-4 py-2 ${isWarm ? "text-[#FCD34D] hover:bg-[#3D2418]" : "text-gray-600 hover:bg-gray-100"} rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors`}
          >
            <ChevronLeft className="w-5 h-5" />
            <span>Back</span>
          </button>

          <button
            onClick={handleNext}
            disabled={!isResponseValid || isSaving}
            className={`flex items-center gap-2 px-6 py-2 ${isWarm ? buttonClasses.primary : `bg-gradient-to-r ${sectionStyle.gradient} text-white`} font-semibold rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all hover:opacity-90`}
          >
            {isSaving ? (
              <span>Saving...</span>
            ) : (
              <>
                <span>
                  {currentQuestionIndex === totalQuestions - 1
                    ? currentSection === "sleepLog"
                      ? "Complete Sleep Log"
                      : "Complete Day"
                    : "Next"}
                </span>
                <ChevronRight className="w-5 h-5" />
              </>
            )}
          </button>
        </div>
      </footer>
    </div>
  );
}

export default function JourneyPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen flex items-center justify-center bg-gray-900">
        <div className="animate-pulse text-gray-400">Loading...</div>
      </div>
    }>
      <JourneyPageContent />
    </Suspense>
  );
}
