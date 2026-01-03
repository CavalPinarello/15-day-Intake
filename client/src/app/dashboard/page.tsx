"use client";

import { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  Moon, CheckCircle, ChevronRight,
  TrendingUp, BookOpen, Settings, RefreshCw, Sparkles,
  ClipboardList, AlertCircle
} from 'lucide-react';

// Types matching iOS models
interface JourneyProgress {
  currentDay: number;
  completedDays: number[];
  totalDays: number;
  phase: 'core' | 'expansion';
  triggeredGateways: string[];
}

interface TodaysTasks {
  sleepLog: {
    completed: boolean;
    questionsCount: number;
    estimatedMinutes: number;
  };
  assessment: {
    completed: boolean;
    questionsCount: number;
    estimatedMinutes: number;
    title: string;
    description: string;
  };
}

interface SleepLogEntry {
  date: string;
  bedtime: string;
  wakeTime: string;
  sleepQuality: number;
  totalSleep: string;
}

// Time-aware greeting like iOS
function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return "Good morning";
  if (hour >= 12 && hour < 17) return "Good afternoon";
  if (hour >= 17 && hour < 21) return "Good evening";
  return "Good night";
}

// Day configuration matching iOS QuestionnaireManager
const dayConfigurations: Record<number, { title: string; description: string; estimatedMinutes: number }> = {
  1: { title: "Demographics & Sleep Quality", description: "Tell us about yourself and your sleep habits", estimatedMinutes: 12 },
  2: { title: "PSQI & Sleep Patterns", description: "Detailed sleep quality assessment", estimatedMinutes: 11 },
  3: { title: "Sleep Timing & Mental Health", description: "Understand your sleep schedule", estimatedMinutes: 8 },
  4: { title: "Physical & Metabolic Health", description: "Health factors affecting sleep", estimatedMinutes: 9 },
  5: { title: "Nutritional & Social Factors", description: "Lifestyle influences on sleep", estimatedMinutes: 7 },
  6: { title: "Personalized Assessment", description: "Based on your responses", estimatedMinutes: 15 },
  7: { title: "Mental Health & Arousal", description: "Depression, anxiety, and pre-sleep arousal", estimatedMinutes: 9 },
  8: { title: "Breathing & Energy", description: "Sleep apnea screening and daytime sleepiness", estimatedMinutes: 7 },
  9: { title: "Function & Behavior", description: "Sleep habits, pain, and functional outcomes", estimatedMinutes: 9 },
  10: { title: "Lifestyle & Rhythm", description: "Cognitive function, diet, and chronotype", estimatedMinutes: 11 },
};

// Gateway display names
const gatewayNames: Record<string, string> = {
  insomnia: "Insomnia Assessment (ISI)",
  depression: "Depression Screening (PHQ-9)",
  anxiety: "Anxiety Assessment (GAD-7)",
  excessiveSleepiness: "Sleepiness Scale (ESS)",
  cognitive: "Cognitive Function (PROMIS)",
  osa: "Sleep Apnea Risk (STOP-BANG)",
  pain: "Pain Assessment (BPI)",
  sleepTiming: "Chronotype (MEQ)",
  dietImpact: "Diet Assessment (MEDAS)",
  poorSleepQuality: "Sleep Hygiene Review",
};

export default function DashboardPage() {
  const [journeyProgress, setJourneyProgress] = useState<JourneyProgress>({
    currentDay: 1,
    completedDays: [],
    totalDays: 10,
    phase: 'core',
    triggeredGateways: [],
  });

  const [todaysTasks, setTodaysTasks] = useState<TodaysTasks>({
    sleepLog: { completed: false, questionsCount: 5, estimatedMinutes: 2 },
    assessment: {
      completed: false,
      questionsCount: 10,
      estimatedMinutes: 12,
      title: dayConfigurations[1].title,
      description: dayConfigurations[1].description
    },
  });

  const [recentSleepLogs, setRecentSleepLogs] = useState<SleepLogEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [lastSync, setLastSync] = useState<Date>(new Date());

  // Load data on mount
  useEffect(() => {
    loadDashboardData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const loadDashboardData = async () => {
    setIsLoading(true);
    try {
      // Load journey progress from localStorage or API
      const savedProgress = localStorage.getItem('journeyProgress');
      if (savedProgress) {
        const progress = JSON.parse(savedProgress);
        setJourneyProgress(progress);
        updateTodaysTasks(progress.currentDay, progress.sleepLogCompleted, progress.assessmentCompleted);
      }

      // Load recent sleep logs
      const savedLogs = localStorage.getItem('sleepLogs');
      if (savedLogs) {
        setRecentSleepLogs(JSON.parse(savedLogs).slice(0, 7));
      }

      setLastSync(new Date());
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const updateTodaysTasks = (day: number, sleepLogCompleted?: boolean, assessmentCompleted?: boolean) => {
    const config = dayConfigurations[day] || dayConfigurations[1];
    setTodaysTasks({
      sleepLog: {
        completed: sleepLogCompleted || false,
        questionsCount: 5,
        estimatedMinutes: 2,
      },
      assessment: {
        completed: assessmentCompleted || false,
        questionsCount: 10,
        estimatedMinutes: config.estimatedMinutes,
        title: config.title,
        description: config.description,
      }
    });
  };

  const handleRefresh = () => {
    loadDashboardData();
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading your dashboard...</p>
        </div>
      </div>
    );
  }

  const progressPercentage = Math.round((journeyProgress.currentDay / journeyProgress.totalDays) * 100);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Zoe Sleep</h1>
              <p className="text-sm text-gray-500">{getGreeting()}</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={handleRefresh}
                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                title="Refresh"
              >
                <RefreshCw className="w-5 h-5 text-gray-600" />
              </button>
              <Link
                href="/settings"
                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
              >
                <Settings className="w-5 h-5 text-gray-600" />
              </Link>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 py-6 space-y-6">
        {/* Journey Progress Card */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">10-Day Sleep Journey</h2>
            <span className="text-sm text-gray-500">
              Day {journeyProgress.currentDay} of {journeyProgress.totalDays}
            </span>
          </div>

          {/* Progress Circle and Days */}
          <div className="flex items-center gap-6 mb-4">
            {/* Circular Progress */}
            <div className="relative w-16 h-16">
              <svg className="w-16 h-16 transform -rotate-90">
                <circle
                  cx="32"
                  cy="32"
                  r="28"
                  stroke="#E5E7EB"
                  strokeWidth="6"
                  fill="none"
                />
                <circle
                  cx="32"
                  cy="32"
                  r="28"
                  stroke="#3B82F6"
                  strokeWidth="6"
                  fill="none"
                  strokeDasharray={`${2 * Math.PI * 28}`}
                  strokeDashoffset={`${2 * Math.PI * 28 * (1 - progressPercentage / 100)}`}
                  strokeLinecap="round"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-sm font-bold text-gray-900">{progressPercentage}%</span>
              </div>
            </div>

            {/* Day Dots */}
            <div className="flex-1">
              <div className="flex flex-wrap gap-1.5">
                {Array.from({ length: 10 }, (_, i) => i + 1).map((day) => (
                  <div
                    key={day}
                    className={`w-5 h-5 rounded-full flex items-center justify-center text-xs font-medium transition-all ${
                      journeyProgress.completedDays.includes(day)
                        ? 'bg-green-500 text-white'
                        : day === journeyProgress.currentDay
                        ? 'bg-blue-500 text-white ring-2 ring-blue-200'
                        : 'bg-gray-200 text-gray-500'
                    }`}
                  >
                    {journeyProgress.completedDays.includes(day) ? '✓' : day}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Phase Indicator */}
          <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium ${
            journeyProgress.phase === 'core'
              ? 'bg-amber-100 text-amber-800'
              : 'bg-green-100 text-green-800'
          }`}>
            <span className="w-2 h-2 rounded-full bg-current"></span>
            {journeyProgress.phase === 'core'
              ? 'Core Assessment Phase (Days 1-5)'
              : 'Personalized Expansion Phase'}
          </div>
        </section>

        {/* Today's Tasks Card */}
        <section className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="p-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">Today&apos;s Tasks</h2>
          </div>

          {/* Sleep Log Task */}
          <Link href="/journey?section=sleeplog" className="block">
            <div className="p-4 border-b border-gray-50 hover:bg-blue-50/50 transition-colors">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-blue-500 flex items-center justify-center">
                  <Moon className="w-6 h-6 text-white" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-semibold rounded">
                      SLEEP LOG
                    </span>
                    {todaysTasks.sleepLog.completed && (
                      <CheckCircle className="w-4 h-4 text-green-500" />
                    )}
                  </div>
                  <h3 className="font-medium text-gray-900">Stanford Sleep Diary</h3>
                  <p className="text-sm text-gray-500">
                    {todaysTasks.sleepLog.questionsCount} questions • ~{todaysTasks.sleepLog.estimatedMinutes} min
                  </p>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-400" />
              </div>
            </div>
          </Link>

          {/* Assessment Task */}
          <Link href="/journey?section=assessment" className="block">
            <div className="p-4 hover:bg-purple-50/50 transition-colors">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-purple-500 flex items-center justify-center">
                  <ClipboardList className="w-6 h-6 text-white" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs font-semibold rounded">
                      ASSESSMENT
                    </span>
                    {todaysTasks.assessment.completed && (
                      <CheckCircle className="w-4 h-4 text-green-500" />
                    )}
                  </div>
                  <h3 className="font-medium text-gray-900">{todaysTasks.assessment.title}</h3>
                  <p className="text-sm text-gray-500">
                    {todaysTasks.assessment.description}
                  </p>
                  <p className="text-xs text-gray-400 mt-1">
                    ~{todaysTasks.assessment.estimatedMinutes} min
                  </p>
                </div>
                <ChevronRight className="w-5 h-5 text-gray-400" />
              </div>
            </div>
          </Link>
        </section>

        {/* Gateway Status Card - Only show if gateways triggered */}
        {journeyProgress.triggeredGateways.length > 0 && (
          <section className="bg-amber-50 rounded-2xl border border-amber-200 p-4">
            <div className="flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-amber-600 mt-0.5" />
              <div>
                <h3 className="font-semibold text-amber-900">Personalized Assessments Triggered</h3>
                <p className="text-sm text-amber-700 mt-1">
                  Based on your responses, we&apos;ve added these assessments:
                </p>
                <div className="flex flex-wrap gap-2 mt-3">
                  {journeyProgress.triggeredGateways.map((gateway) => (
                    <span
                      key={gateway}
                      className="px-2 py-1 bg-amber-200 text-amber-800 text-xs font-medium rounded-full"
                    >
                      {gatewayNames[gateway] || gateway}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Quick Actions */}
        <section className="grid grid-cols-3 gap-3">
          <Link
            href="/sleep-diary"
            className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 text-center hover:shadow-md transition-shadow"
          >
            <div className="w-10 h-10 rounded-full bg-cyan-100 flex items-center justify-center mx-auto mb-2">
              <BookOpen className="w-5 h-5 text-cyan-600" />
            </div>
            <span className="text-sm font-medium text-gray-900">Sleep Diary</span>
          </Link>

          <Link
            href="/insights"
            className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 text-center hover:shadow-md transition-shadow"
          >
            <div className="w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center mx-auto mb-2">
              <TrendingUp className="w-5 h-5 text-indigo-600" />
            </div>
            <span className="text-sm font-medium text-gray-900">Insights</span>
          </Link>

          <Link
            href="/treatment"
            className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 text-center hover:shadow-md transition-shadow"
          >
            <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center mx-auto mb-2">
              <Sparkles className="w-5 h-5 text-emerald-600" />
            </div>
            <span className="text-sm font-medium text-gray-900">Treatment</span>
          </Link>
        </section>

        {/* Recent Sleep Log History */}
        {recentSleepLogs.length > 0 && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Recent Sleep Logs</h2>
              <Link href="/sleep-diary" className="text-sm text-blue-600 font-medium">
                View All
              </Link>
            </div>
            <div className="space-y-3">
              {recentSleepLogs.slice(0, 3).map((log, index) => (
                <div key={index} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                  <div>
                    <p className="font-medium text-gray-900">{log.date}</p>
                    <p className="text-sm text-gray-500">
                      {log.bedtime} → {log.wakeTime} • {log.totalSleep}
                    </p>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-lg font-semibold text-gray-900">{log.sleepQuality}</span>
                    <span className="text-xs text-gray-400">/10</span>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Journey Overview Link */}
        <Link
          href="/journey/overview"
          className="block bg-gradient-to-r from-blue-500 to-purple-500 rounded-2xl p-4 text-white"
        >
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-semibold">View Full Journey</h3>
              <p className="text-sm text-white/80">See all 10 days and your progress</p>
            </div>
            <ChevronRight className="w-6 h-6" />
          </div>
        </Link>

        {/* Last Sync */}
        <p className="text-center text-xs text-gray-400">
          Last synced: {lastSync.toLocaleTimeString()}
        </p>
      </main>
    </div>
  );
}
