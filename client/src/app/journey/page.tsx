"use client";

import { useState, useEffect, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { QuestionRenderer } from '@/components/questions';
import { ResponseValue, Question, AnswerFormat } from '@/components/questions/types';
import {
  ChevronLeft, ChevronRight, Moon, ClipboardList,
  CheckCircle, Home, X, Sparkles
} from 'lucide-react';
import * as convexService from '@/lib/convexService';
import { useCircadianTheme } from '@/hooks/useCircadianTheme';

// Section types matching iOS
type QuestionnaireSection = 'sleepLog' | 'assessment';

interface DayInfo {
  id: number;
  day_number: number;
  title: string;
  description: string;
}

interface QuestionData {
  id: string;
  question_text: string;
  question_type: string;
  options: any;
  required: boolean;
  order_index: number;
  section?: string;
  conditional_logic?: string;
}

interface ConditionalLogic {
  question_key?: string;  // Cross-platform sync key matching iOS/Watch IDs
  is_daily_log?: boolean;
  pillar?: string;
  is_gateway?: boolean;
  gateway_condition?: string;
  gateway_threshold?: number;
  help_text?: string;
}

// Section colors matching iOS QuestionnaireSections.swift
const sectionStyles = {
  sleepLog: {
    color: '#2196F3',
    bgColor: 'bg-blue-500',
    bgLight: 'bg-blue-50',
    textColor: 'text-blue-600',
    borderColor: 'border-blue-200',
    gradient: 'from-blue-500 to-blue-600',
    icon: Moon,
    title: 'SLEEP LOG',
    subtitle: 'Stanford Sleep Diary',
  },
  assessment: {
    color: '#9C27B0',
    bgColor: 'bg-purple-500',
    bgLight: 'bg-purple-50',
    textColor: 'text-purple-600',
    borderColor: 'border-purple-200',
    gradient: 'from-purple-500 to-purple-600',
    icon: ClipboardList,
    title: 'ASSESSMENT',
    subtitle: 'Day Assessment',
  },
};

// Helper to parse conditional logic JSON
function parseConditionalLogic(logicStr: string | null | undefined): ConditionalLogic | null {
  if (!logicStr) return null;
  try {
    return JSON.parse(logicStr);
  } catch {
    return null;
  }
}

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
  9: { title: "Sleep Apnea Screening", description: "STOP-BANG questionnaire" },
  10: { title: "Pain & Discomfort", description: "Brief Pain Inventory" },
  11: { title: "Chronotype Assessment", description: "Morningness-Eveningness questionnaire" },
  12: { title: "Diet & Nutrition", description: "MEDAS assessment" },
  13: { title: "Cognitive Function", description: "PROMIS cognitive assessment" },
  14: { title: "Sleep Hygiene Review", description: "Environmental and behavioral factors" },
  15: { title: "Journey Completion", description: "Final review and summary" },
};

// Helper to normalize section param
function normalizeSection(section: string | null): QuestionnaireSection {
  if (!section) return 'sleepLog';
  const lower = section.toLowerCase();
  if (lower === 'sleeplog' || lower === 'sleep-log' || lower === 'sleep_log') return 'sleepLog';
  if (lower === 'assessment') return 'assessment';
  return 'sleepLog';
}

export default function JourneyPage() {
  const searchParams = useSearchParams();
  const initialSection = normalizeSection(searchParams.get('section'));

  // Circadian theme for time-aware colors
  const { textClasses, bgClasses, cardClasses, buttonClasses, isWarm, colors } = useCircadianTheme();

  const [currentDay, setCurrentDay] = useState(1);
  const [currentSection, setCurrentSection] = useState<QuestionnaireSection>(initialSection);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [sleepLogResponses, setSleepLogResponses] = useState<Map<string, ResponseValue>>(new Map());
  const [assessmentResponses, setAssessmentResponses] = useState<Map<string, ResponseValue>>(new Map());
  const [sleepLogQuestions, setSleepLogQuestions] = useState<Question[]>([]);
  const [assessmentQuestions, setAssessmentQuestions] = useState<Question[]>([]);
  const [dayInfo, setDayInfo] = useState<DayInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showSectionTransition, setShowSectionTransition] = useState(false);
  const [showDayCompletion, setShowDayCompletion] = useState(false);
  const [sleepLogComplete, setSleepLogComplete] = useState(false);
  const [assessmentComplete, setAssessmentComplete] = useState(false);

  // Get current questions based on section
  const currentQuestions = currentSection === 'sleepLog' ? sleepLogQuestions : assessmentQuestions;
  const currentResponses = currentSection === 'sleepLog' ? sleepLogResponses : assessmentResponses;
  const setCurrentResponses = currentSection === 'sleepLog' ? setSleepLogResponses : setAssessmentResponses;
  const sectionStyle = sectionStyles[currentSection];
  const SectionIcon = sectionStyle.icon;

  // Load journey progress on mount
  useEffect(() => {
    const savedProgress = localStorage.getItem('journeyProgress');
    if (savedProgress) {
      const progress = JSON.parse(savedProgress);
      setCurrentDay(progress.currentDay || 1);
    }
    loadDayData();
  }, []);

  // Load day data when currentDay changes
  useEffect(() => {
    loadDayData();
  }, [currentDay]);

  const loadDayData = async () => {
    try {
      setLoading(true);
      setError(null);

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';
      const dayResponse = await fetch(`${apiUrl}/days/${currentDay}`);

      if (!dayResponse.ok) {
        throw new Error(`Failed to fetch day info: ${dayResponse.statusText}`);
      }

      const dayData = await dayResponse.json();
      const config = dayConfigurations[currentDay] || { title: `Day ${currentDay}`, description: '' };

      setDayInfo({
        id: dayData.day?.id || currentDay,
        day_number: currentDay,
        title: config.title,
        description: config.description,
      });

      // Transform and filter questions by is_daily_log
      if (dayData.questions) {
        const sleepLogQs: Question[] = [];
        const assessmentQs: Question[] = [];

        dayData.questions.forEach((q: QuestionData) => {
          const logic = parseConditionalLogic(q.conditional_logic);
          // Use question_key from conditional_logic for cross-platform sync with iOS/Watch
          // Falls back to database id if no question_key exists
          const questionId = logic?.question_key || q.id.toString();
          const transformedQuestion: Question = {
            question_id: questionId,
            question_text: q.question_text,
            answer_format: mapQuestionType(q.question_type),
            format_config: JSON.stringify(createConfig(q.question_type, q.options, logic?.question_key)),
            required: q.required || false,
            order_index: q.order_index,
            estimated_time_seconds: 60,
          };

          // Separate by is_daily_log flag
          if (logic?.is_daily_log) {
            sleepLogQs.push(transformedQuestion);
          } else {
            assessmentQs.push(transformedQuestion);
          }
        });

        // Sort by order_index
        sleepLogQs.sort((a, b) => (a.order_index ?? 0) - (b.order_index ?? 0));
        assessmentQs.sort((a, b) => (a.order_index ?? 0) - (b.order_index ?? 0));

        setSleepLogQuestions(sleepLogQs);
        setAssessmentQuestions(assessmentQs);

        // Load saved progress from Convex for cross-device sync
        await loadSavedProgress(sleepLogQs, assessmentQs);
      }
    } catch (err) {
      console.error('Error fetching day data:', err);
      setError(err instanceof Error ? err.message : 'Failed to load questionnaire');
    } finally {
      setLoading(false);
    }
  };

  // Load saved progress from Convex for cross-device sync
  const loadSavedProgress = async (sleepLogQs: Question[], assessmentQs: Question[]) => {
    try {
      const section = currentSection;
      const questions = section === 'sleepLog' ? sleepLogQs : assessmentQs;

      // Load question progress (which question user was on)
      const progress = await convexService.getQuestionProgress(currentDay, section);
      if (progress && !progress.completed && progress.currentQuestionIndex < questions.length) {
        setCurrentQuestionIndex(progress.currentQuestionIndex);
        console.log(`[Web] Resuming ${section} at question ${progress.currentQuestionIndex + 1}/${questions.length} (last device: ${progress.lastDevice})`);
      }

      // Load saved responses to pre-fill answers
      const savedResponses = await convexService.getSavedResponses(currentDay);
      const sleepLogMap = new Map<string, ResponseValue>();
      const assessmentMap = new Map<string, ResponseValue>();

      Object.entries(savedResponses).forEach(([questionId, value]) => {
        const responseValue: ResponseValue = value.stringValue ?? value.numberValue ?? value.arrayValue ?? null;
        if (responseValue !== null) {
          // Determine which section this question belongs to
          if (sleepLogQs.some(q => q.question_id === questionId)) {
            sleepLogMap.set(questionId, responseValue);
          } else {
            assessmentMap.set(questionId, responseValue);
          }
        }
      });

      if (sleepLogMap.size > 0) setSleepLogResponses(sleepLogMap);
      if (assessmentMap.size > 0) setAssessmentResponses(assessmentMap);
      console.log(`[Web] Loaded ${Object.keys(savedResponses).length} saved responses from Convex`);
    } catch (err) {
      console.error('[Web] Failed to load saved progress:', err);
    }
  };

  // Sync question progress to Convex after each question
  const syncProgressToConvex = useCallback(async (questionIndex: number) => {
    const questions = currentSection === 'sleepLog' ? sleepLogQuestions : assessmentQuestions;
    try {
      await convexService.updateQuestionProgress(
        currentDay,
        currentSection,
        questionIndex,
        questions.length
      );
    } catch (err) {
      console.error('[Web] Failed to sync progress:', err);
    }
  }, [currentDay, currentSection, sleepLogQuestions, assessmentQuestions]);

  const mapQuestionType = (dbType: string): AnswerFormat => {
    const typeMap: Record<string, AnswerFormat> = {
      'textarea': 'textarea',
      'scale': 'slider_scale',
      'time': 'time_picker',
      'select': 'single_select_chips',
      'checkbox': 'multi_select_chips',
      'number': 'number_input',
    };
    return typeMap[dbType] || 'textarea';
  };

  const createConfig = (questionType: string, dbOptions: any, questionKey?: string) => {
    switch (questionType) {
      case 'select':
        return {
          options: Array.isArray(dbOptions)
            ? dbOptions.map((opt: string) => ({ value: opt, label: opt }))
            : [],
          layout: 'vertical'
        };
      case 'checkbox':
        return {
          options: Array.isArray(dbOptions)
            ? dbOptions.map((opt: string) => ({ value: opt, label: opt }))
            : [],
          layout: 'grid'
        };
      case 'scale':
        return {
          min: dbOptions?.min || 1,
          max: dbOptions?.max || 10,
          step: dbOptions?.step || 1,
          labels: { min: dbOptions?.minLabel || 'Low', max: dbOptions?.maxLabel || 'High' },
          questionKey
        };
      case 'time':
        return { format: 'HH:MM', questionKey };
      case 'number':
        return { min: dbOptions?.min, max: dbOptions?.max, step: dbOptions?.step || 1, unit: dbOptions?.unit, questionKey };
      default:
        return { placeholder: 'Enter your response...', maxLength: 1000, rows: 4 };
    }
  };

  const handleResponseChange = (questionId: string, value: ResponseValue) => {
    setCurrentResponses(prev => {
      const newResponses = new Map(prev);
      newResponses.set(questionId, value);
      return newResponses;
    });

    // Save to API
    saveResponse(questionId, value);
  };

  const saveResponse = async (questionId: string, value: ResponseValue) => {
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';
      await fetch(`${apiUrl}/responses`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: 1,
          question_id: questionId,
          response_value: typeof value === 'string' ? value : null,
          response_number: typeof value === 'number' ? value : null,
          response_array: Array.isArray(value) ? JSON.stringify(value) : null,
        }),
      });
    } catch (err) {
      console.error('Error saving response:', err);
    }
  };

  const currentQuestion = currentQuestions[currentQuestionIndex];
  const currentResponse = currentQuestion ? currentResponses.get(currentQuestion.question_id) : null;
  const isResponseValid = currentQuestion?.required ? currentResponse !== null && currentResponse !== undefined && currentResponse !== '' : true;
  const progress = currentQuestions.length > 0 ? ((currentQuestionIndex + 1) / currentQuestions.length) * 100 : 0;

  const handleNext = () => {
    if (currentQuestionIndex < currentQuestions.length - 1) {
      const newIndex = currentQuestionIndex + 1;
      setCurrentQuestionIndex(newIndex);
      // Sync progress to Convex for cross-device sync
      syncProgressToConvex(newIndex);
    } else {
      // Section complete
      if (currentSection === 'sleepLog') {
        setSleepLogComplete(true);
        saveSleepLogData();
        setShowSectionTransition(true);
      } else {
        setAssessmentComplete(true);
        setShowDayCompletion(true);
      }
    }
  };

  const handlePrevious = () => {
    if (currentQuestionIndex > 0) {
      setCurrentQuestionIndex(prev => prev - 1);
    }
  };

  const saveSleepLogData = async () => {
    // Save sleep log to localStorage
    // Build the entry from all sleep log responses
    const sleepLogEntry: Record<string, any> = {
      date: new Date().toLocaleDateString(),
    };

    // Map responses by looking for common sleep log field patterns in question text
    sleepLogQuestions.forEach(q => {
      const qText = q.question_text.toLowerCase();
      const response = sleepLogResponses.get(q.question_id);

      if (qText.includes('bed') && qText.includes('time')) {
        sleepLogEntry.bedtime = response;
      } else if (qText.includes('wake') || qText.includes('get up')) {
        sleepLogEntry.wakeTime = response;
      } else if (qText.includes('fall asleep') || qText.includes('fell asleep')) {
        sleepLogEntry.asleepTime = response;
      } else if (qText.includes('woke up') || qText.includes('awakenings') || qText.includes('times')) {
        sleepLogEntry.awakenings = response;
      } else if (qText.includes('quality') || qText.includes('rate')) {
        sleepLogEntry.sleepQuality = response;
      }
    });

    const existingLogs = JSON.parse(localStorage.getItem('sleepLogs') || '[]');
    existingLogs.unshift(sleepLogEntry);
    localStorage.setItem('sleepLogs', JSON.stringify(existingLogs.slice(0, 30)));

    // Update journey progress with section completion status
    const savedProgress = JSON.parse(localStorage.getItem('journeyProgress') || '{}');
    const newProgress = {
      ...savedProgress,
      currentDay: savedProgress.currentDay || currentDay,
      sleepLogCompleted: true,
      assessmentCompleted: savedProgress.assessmentCompleted || false,
    };
    localStorage.setItem('journeyProgress', JSON.stringify(newProgress));

    // Call Convex to mark sleep log section as complete for cross-device sync
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';
      await fetch(`${apiUrl}/section-complete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: 1,
          day_number: currentDay,
          section: 'sleepLog',
          source: 'web'
        }),
      });
      console.log('[Web] Sleep log section marked complete');
    } catch (err) {
      console.error('[Web] Error marking sleep log complete:', err);
    }
  };

  const handleContinueToAssessment = () => {
    setShowSectionTransition(false);
    setCurrentSection('assessment');
    setCurrentQuestionIndex(0);
  };

  const handleDayComplete = async () => {
    // Save progress
    const savedProgress = JSON.parse(localStorage.getItem('journeyProgress') || '{}');
    const completedDays = savedProgress.completedDays || [];
    if (!completedDays.includes(currentDay)) {
      completedDays.push(currentDay);
    }

    const newProgress = {
      ...savedProgress,
      currentDay: Math.min(currentDay + 1, 15),
      completedDays,
      phase: currentDay >= 5 ? 'expansion' : 'core',
      // Reset section completion for next day
      sleepLogCompleted: false,
      assessmentCompleted: false,
    };
    localStorage.setItem('journeyProgress', JSON.stringify(newProgress));

    // Call Convex to mark assessment section as complete for cross-device sync
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';
      await fetch(`${apiUrl}/section-complete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: 1,
          day_number: currentDay,
          section: 'assessment',
          source: 'web'
        }),
      });
      console.log('[Web] Assessment section marked complete');
    } catch (err) {
      console.error('[Web] Error marking assessment complete:', err);
    }

    if (currentDay >= 15) {
      // Journey complete
      window.location.href = '/treatment';
    } else {
      // Go to dashboard
      window.location.href = '/dashboard';
    }
  };

  // Section Transition View
  if (showSectionTransition) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-2xl shadow-lg p-8 text-center">
          {/* Success Animation */}
          <div className="w-20 h-20 mx-auto mb-6 relative">
            <div className="absolute inset-0 bg-green-100 rounded-full animate-ping opacity-50"></div>
            <div className="relative w-20 h-20 bg-green-500 rounded-full flex items-center justify-center">
              <CheckCircle className="w-10 h-10 text-white" />
            </div>
          </div>

          <h2 className="text-2xl font-bold text-gray-900 mb-2">Sleep Log Complete!</h2>
          <p className="text-gray-600 mb-8">Great job recording your sleep data</p>

          <div className="border-t border-gray-100 pt-6 mb-6">
            <p className="text-sm text-gray-500 uppercase tracking-wide mb-4">Up Next</p>
            <div className={`${sectionStyles.assessment.bgLight} rounded-xl p-4 text-left`}>
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 ${sectionStyles.assessment.bgColor} rounded-lg flex items-center justify-center`}>
                  <ClipboardList className="w-5 h-5 text-white" />
                </div>
                <div>
                  <span className={`text-xs font-semibold ${sectionStyles.assessment.textColor}`}>
                    {sectionStyles.assessment.title}
                  </span>
                  <h3 className="font-medium text-gray-900">{dayInfo?.title}</h3>
                  <p className="text-sm text-gray-500">{assessmentQuestions.length} questions</p>
                </div>
              </div>
            </div>
          </div>

          <button
            onClick={handleContinueToAssessment}
            className={`w-full py-3 px-6 bg-gradient-to-r ${sectionStyles.assessment.gradient} text-white font-semibold rounded-xl hover:opacity-90 transition-opacity`}
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
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-green-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-2xl shadow-lg p-8 text-center">
          {/* Success Animation */}
          <div className="w-24 h-24 mx-auto mb-6 relative">
            <div className="absolute inset-0 bg-green-100 rounded-full animate-ping opacity-50"></div>
            <div className="relative w-24 h-24 bg-gradient-to-br from-green-400 to-emerald-500 rounded-full flex items-center justify-center">
              <Sparkles className="w-12 h-12 text-white" />
            </div>
          </div>

          <h2 className="text-2xl font-bold text-gray-900 mb-2">Day {currentDay} Complete!</h2>
          <p className="text-gray-600 mb-6">Excellent work on your sleep journey</p>

          {/* Summary Cards */}
          <div className="grid grid-cols-2 gap-3 mb-6">
            <div className={`${sectionStyles.sleepLog.bgLight} rounded-xl p-4`}>
              <Moon className={`w-6 h-6 ${sectionStyles.sleepLog.textColor} mx-auto mb-2`} />
              <p className="text-sm font-medium text-gray-900">Sleep Log</p>
              <p className="text-xs text-gray-500">{sleepLogQuestions.length} questions</p>
            </div>
            <div className={`${sectionStyles.assessment.bgLight} rounded-xl p-4`}>
              <ClipboardList className={`w-6 h-6 ${sectionStyles.assessment.textColor} mx-auto mb-2`} />
              <p className="text-sm font-medium text-gray-900">Assessment</p>
              <p className="text-xs text-gray-500">{assessmentQuestions.length} questions</p>
            </div>
          </div>

          {currentDay < 15 ? (
            <button
              onClick={handleDayComplete}
              className="w-full py-3 px-6 bg-gradient-to-r from-green-500 to-emerald-500 text-white font-semibold rounded-xl hover:opacity-90 transition-opacity"
            >
              Continue to Day {currentDay + 1}
            </button>
          ) : (
            <button
              onClick={handleDayComplete}
              className="w-full py-3 px-6 bg-gradient-to-r from-purple-500 to-pink-500 text-white font-semibold rounded-xl hover:opacity-90 transition-opacity"
            >
              Complete Journey
            </button>
          )}
        </div>
      </div>
    );
  }

  // Loading State
  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading your assessment...</p>
        </div>
      </div>
    );
  }

  // Error State
  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-red-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-2xl shadow-lg p-8 text-center">
          <div className="w-16 h-16 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
            <X className="w-8 h-8 text-red-500" />
          </div>
          <h2 className="text-xl font-bold text-gray-900 mb-2">Error Loading Assessment</h2>
          <p className="text-gray-600 mb-6">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Section Header */}
      <header className={`bg-gradient-to-r ${sectionStyle.gradient} text-white`}>
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between mb-3">
            <Link href="/dashboard" className="p-2 hover:bg-white/10 rounded-lg transition-colors">
              <Home className="w-5 h-5" />
            </Link>
            <div className="flex items-center gap-2">
              <SectionIcon className="w-5 h-5" />
              <span className="font-semibold">{sectionStyle.title}</span>
            </div>
            <span className="text-sm opacity-80">
              {currentQuestionIndex + 1}/{currentQuestions.length}
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
      <div className="max-w-2xl mx-auto px-4 py-3 border-b border-gray-100 bg-white/50">
        <div className="flex items-center justify-between">
          <div>
            <span className="text-sm text-gray-500">Day {currentDay} of 15</span>
            {currentSection === 'assessment' && dayInfo && (
              <h2 className="font-medium text-gray-900">{dayInfo.title}</h2>
            )}
          </div>
          {/* Progress Dots */}
          <div className="flex gap-1">
            {currentQuestions.map((_, idx) => (
              <div
                key={idx}
                className={`w-2 h-2 rounded-full transition-all ${
                  idx < currentQuestionIndex
                    ? 'bg-green-500'
                    : idx === currentQuestionIndex
                    ? sectionStyle.bgColor
                    : 'bg-gray-200'
                }`}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Question Content */}
      <main className="max-w-2xl mx-auto px-4 py-8">
        {currentQuestion && (
          <div className={`bg-white rounded-2xl shadow-sm border ${sectionStyle.borderColor} p-6`}>
            <QuestionRenderer
              question={currentQuestion}
              value={currentResponse ?? null}
              onChange={(value) => handleResponseChange(currentQuestion.question_id, value)}
              previousResponses={currentResponses}
            />
          </div>
        )}
      </main>

      {/* Navigation Footer */}
      <footer className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 p-4">
        <div className="max-w-2xl mx-auto flex items-center justify-between gap-4">
          <button
            onClick={handlePrevious}
            disabled={currentQuestionIndex === 0}
            className="flex items-center gap-2 px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
            <span>Back</span>
          </button>

          <button
            onClick={handleNext}
            disabled={!isResponseValid}
            className={`flex items-center gap-2 px-6 py-2 bg-gradient-to-r ${sectionStyle.gradient} text-white font-semibold rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all hover:opacity-90`}
          >
            <span>
              {currentQuestionIndex === currentQuestions.length - 1
                ? currentSection === 'sleepLog'
                  ? 'Complete Sleep Log'
                  : 'Complete Day'
                : 'Next'}
            </span>
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </footer>
    </div>
  );
}
