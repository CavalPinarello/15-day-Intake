"use client";

import { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  ArrowLeft, TrendingUp, TrendingDown, Moon, Sun, Brain,
  Heart, Activity, Utensils, Clock, AlertTriangle, CheckCircle,
  Info, ChevronRight, Lightbulb, Target, Zap
} from 'lucide-react';

interface SleepLogEntry {
  date: string;
  bedtime: string;
  wakeTime: string;
  asleepTime: string;
  awakenings: number;
  sleepQuality: number;
}

interface Insight {
  id: string;
  type: 'positive' | 'negative' | 'neutral' | 'tip';
  category: string;
  title: string;
  description: string;
  metric?: string;
  trend?: 'up' | 'down' | 'stable';
  icon: any;
  color: string;
}

interface JourneyProgress {
  currentDay: number;
  completedDays: number[];
  triggeredGateways: string[];
  phase: 'core' | 'expansion';
}

// Gateway descriptions for insights
const gatewayInsights: Record<string, { title: string; description: string; recommendations: string[] }> = {
  insomnia: {
    title: "Insomnia Indicators Detected",
    description: "Your responses suggest you may be experiencing insomnia symptoms. This is common and treatable.",
    recommendations: [
      "Maintain a consistent sleep schedule",
      "Avoid screens 1 hour before bed",
      "Create a relaxing bedtime routine",
      "Limit caffeine after 2 PM"
    ]
  },
  depression: {
    title: "Mood May Be Affecting Sleep",
    description: "There appears to be a connection between your mood and sleep patterns. Addressing both can help improve your overall well-being.",
    recommendations: [
      "Regular physical activity can improve both mood and sleep",
      "Exposure to natural light during the day",
      "Consider speaking with a healthcare provider",
      "Practice relaxation techniques"
    ]
  },
  anxiety: {
    title: "Anxiety May Be Impacting Sleep",
    description: "Anxiety can make it harder to fall asleep and stay asleep. Managing anxiety can significantly improve sleep quality.",
    recommendations: [
      "Try deep breathing exercises before bed",
      "Write down worries before sleep",
      "Progressive muscle relaxation",
      "Limit news and social media before bed"
    ]
  },
  excessiveSleepiness: {
    title: "Daytime Sleepiness Noted",
    description: "You're experiencing significant daytime sleepiness, which may indicate your sleep isn't as restorative as it should be.",
    recommendations: [
      "Aim for 7-9 hours of sleep",
      "Check for sleep disorders with a specialist",
      "Avoid heavy meals before bed",
      "Get regular exercise (but not close to bedtime)"
    ]
  },
  osa: {
    title: "Sleep Apnea Risk Factors Present",
    description: "Your responses indicate potential risk factors for sleep apnea. A sleep study may be beneficial.",
    recommendations: [
      "Consult with a sleep specialist",
      "Consider a home sleep test",
      "Sleep on your side instead of your back",
      "Maintain a healthy weight"
    ]
  },
  poorSleepQuality: {
    title: "Sleep Quality Can Be Improved",
    description: "Your overall sleep quality scores suggest room for improvement. Small changes can make a big difference.",
    recommendations: [
      "Keep your bedroom cool (65-68°F)",
      "Use blackout curtains",
      "Reserve bed for sleep only",
      "Limit alcohol consumption"
    ]
  }
};

export default function InsightsPage() {
  const [sleepLogs, setSleepLogs] = useState<SleepLogEntry[]>([]);
  const [journeyProgress, setJourneyProgress] = useState<JourneyProgress | null>(null);
  const [insights, setInsights] = useState<Insight[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = () => {
    setIsLoading(true);
    try {
      // Load sleep logs
      const savedLogs = localStorage.getItem('sleepLogs');
      if (savedLogs) {
        setSleepLogs(JSON.parse(savedLogs));
      }

      // Load journey progress
      const savedProgress = localStorage.getItem('journeyProgress');
      if (savedProgress) {
        setJourneyProgress(JSON.parse(savedProgress));
      }

      // Generate insights
      generateInsights(
        savedLogs ? JSON.parse(savedLogs) : [],
        savedProgress ? JSON.parse(savedProgress) : null
      );
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const generateInsights = (logs: SleepLogEntry[], progress: JourneyProgress | null) => {
    const newInsights: Insight[] = [];

    // Sleep quality insights
    if (logs.length >= 3) {
      const recentQuality = logs.slice(0, 7).reduce((sum, log) => sum + (log.sleepQuality || 0), 0) / Math.min(logs.length, 7);

      if (recentQuality >= 7) {
        newInsights.push({
          id: 'quality-good',
          type: 'positive',
          category: 'Sleep Quality',
          title: 'Great Sleep Quality!',
          description: `Your average sleep quality is ${recentQuality.toFixed(1)}/10. Keep up the good work!`,
          metric: `${recentQuality.toFixed(1)}/10`,
          trend: 'up',
          icon: Moon,
          color: 'green'
        });
      } else if (recentQuality < 5) {
        newInsights.push({
          id: 'quality-low',
          type: 'negative',
          category: 'Sleep Quality',
          title: 'Sleep Quality Needs Attention',
          description: `Your average sleep quality is ${recentQuality.toFixed(1)}/10. Let's work on improving this.`,
          metric: `${recentQuality.toFixed(1)}/10`,
          trend: 'down',
          icon: Moon,
          color: 'red'
        });
      }

      // Awakening insights
      const avgAwakenings = logs.slice(0, 7).reduce((sum, log) => sum + (log.awakenings || 0), 0) / Math.min(logs.length, 7);
      if (avgAwakenings > 3) {
        newInsights.push({
          id: 'awakenings-high',
          type: 'negative',
          category: 'Sleep Continuity',
          title: 'Frequent Night Awakenings',
          description: `You're waking up an average of ${avgAwakenings.toFixed(1)} times per night. This may be fragmenting your sleep.`,
          metric: `${avgAwakenings.toFixed(1)} times`,
          icon: Activity,
          color: 'amber'
        });
      } else if (avgAwakenings <= 1 && logs.length >= 5) {
        newInsights.push({
          id: 'awakenings-good',
          type: 'positive',
          category: 'Sleep Continuity',
          title: 'Excellent Sleep Continuity',
          description: 'You rarely wake up during the night. This helps ensure restorative sleep.',
          metric: `${avgAwakenings.toFixed(1)} times`,
          icon: CheckCircle,
          color: 'green'
        });
      }
    }

    // Journey progress insights
    if (progress) {
      const completionRate = (progress.completedDays.length / 15) * 100;

      if (completionRate >= 30 && completionRate < 100) {
        newInsights.push({
          id: 'journey-progress',
          type: 'neutral',
          category: 'Journey Progress',
          title: `${Math.round(completionRate)}% Complete`,
          description: `You've completed ${progress.completedDays.length} of 15 days. ${progress.phase === 'expansion' ? 'You\'re now in the personalized assessment phase!' : 'Keep going!'}`,
          metric: `Day ${progress.currentDay}`,
          icon: Target,
          color: 'blue'
        });
      }

      // Gateway-triggered insights
      if (progress.triggeredGateways && progress.triggeredGateways.length > 0) {
        progress.triggeredGateways.forEach(gateway => {
          const gatewayInfo = gatewayInsights[gateway];
          if (gatewayInfo) {
            newInsights.push({
              id: `gateway-${gateway}`,
              type: 'negative',
              category: 'Assessment Finding',
              title: gatewayInfo.title,
              description: gatewayInfo.description,
              icon: AlertTriangle,
              color: 'amber'
            });
          }
        });
      }
    }

    // Add general tips if we don't have many insights
    if (newInsights.length < 3) {
      newInsights.push({
        id: 'tip-consistency',
        type: 'tip',
        category: 'Sleep Tip',
        title: 'Consistency is Key',
        description: 'Going to bed and waking up at the same time every day—even on weekends—helps regulate your body\'s internal clock.',
        icon: Clock,
        color: 'indigo'
      });

      newInsights.push({
        id: 'tip-environment',
        type: 'tip',
        category: 'Sleep Tip',
        title: 'Optimize Your Environment',
        description: 'Keep your bedroom cool (65-68°F), dark, and quiet for optimal sleep conditions.',
        icon: Lightbulb,
        color: 'purple'
      });
    }

    setInsights(newInsights);
  };

  const getColorClasses = (color: string) => {
    const colors: Record<string, { bg: string; text: string; border: string }> = {
      green: { bg: 'bg-green-50', text: 'text-green-600', border: 'border-green-200' },
      red: { bg: 'bg-red-50', text: 'text-red-600', border: 'border-red-200' },
      amber: { bg: 'bg-amber-50', text: 'text-amber-600', border: 'border-amber-200' },
      blue: { bg: 'bg-blue-50', text: 'text-blue-600', border: 'border-blue-200' },
      indigo: { bg: 'bg-indigo-50', text: 'text-indigo-600', border: 'border-indigo-200' },
      purple: { bg: 'bg-purple-50', text: 'text-purple-600', border: 'border-purple-200' },
    };
    return colors[color] || colors.blue;
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-indigo-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-indigo-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/dashboard" className="p-2 hover:bg-gray-100 rounded-full">
              <ArrowLeft className="w-5 h-5 text-gray-600" />
            </Link>
            <div>
              <h1 className="text-xl font-bold text-gray-900">Sleep Insights</h1>
              <p className="text-sm text-gray-500">Personalized analysis</p>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 py-6 space-y-6">
        {/* Summary Card */}
        {sleepLogs.length > 0 && (
          <section className="bg-gradient-to-r from-indigo-500 to-purple-500 rounded-2xl p-6 text-white">
            <div className="flex items-center gap-3 mb-4">
              <Brain className="w-6 h-6" />
              <h2 className="text-lg font-semibold">Your Sleep Summary</h2>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <div className="text-3xl font-bold">{sleepLogs.length}</div>
                <p className="text-sm text-white/80">Nights Logged</p>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold">
                  {sleepLogs.length > 0
                    ? (sleepLogs.reduce((sum, log) => sum + (log.sleepQuality || 0), 0) / sleepLogs.length).toFixed(1)
                    : '--'}
                </div>
                <p className="text-sm text-white/80">Avg Quality</p>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold">
                  {journeyProgress ? `${Math.round((journeyProgress.completedDays.length / 15) * 100)}%` : '0%'}
                </div>
                <p className="text-sm text-white/80">Journey</p>
              </div>
            </div>
          </section>
        )}

        {/* Insights List */}
        <section className="space-y-4">
          <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide px-1">
            Your Insights
          </h2>

          {insights.length === 0 ? (
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 text-center">
              <Lightbulb className="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <h3 className="font-medium text-gray-900 mb-2">No insights yet</h3>
              <p className="text-sm text-gray-500 mb-4">
                Complete more days of your journey to unlock personalized insights
              </p>
              <Link
                href="/journey"
                className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
              >
                <Zap className="w-4 h-4" />
                Continue Journey
              </Link>
            </div>
          ) : (
            insights.map((insight) => {
              const colorClasses = getColorClasses(insight.color);
              const Icon = insight.icon;
              return (
                <div
                  key={insight.id}
                  className={`bg-white rounded-xl shadow-sm border ${colorClasses.border} overflow-hidden`}
                >
                  <div className="p-4">
                    <div className="flex items-start gap-4">
                      <div className={`w-10 h-10 rounded-lg ${colorClasses.bg} flex items-center justify-center flex-shrink-0`}>
                        <Icon className={`w-5 h-5 ${colorClasses.text}`} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className={`text-xs font-medium ${colorClasses.text} uppercase`}>
                            {insight.category}
                          </span>
                          {insight.trend === 'up' && <TrendingUp className="w-3 h-3 text-green-500" />}
                          {insight.trend === 'down' && <TrendingDown className="w-3 h-3 text-red-500" />}
                        </div>
                        <h3 className="font-semibold text-gray-900">{insight.title}</h3>
                        <p className="text-sm text-gray-600 mt-1">{insight.description}</p>
                        {insight.metric && (
                          <div className={`inline-flex items-center gap-1 mt-2 px-2 py-1 rounded-full ${colorClasses.bg}`}>
                            <span className={`text-sm font-medium ${colorClasses.text}`}>{insight.metric}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Show recommendations for gateway insights */}
                  {insight.id.startsWith('gateway-') && (
                    <div className={`px-4 pb-4 pt-2 border-t ${colorClasses.border}`}>
                      <p className="text-xs font-medium text-gray-500 uppercase mb-2">Recommendations</p>
                      <ul className="space-y-1">
                        {gatewayInsights[insight.id.replace('gateway-', '')]?.recommendations.slice(0, 3).map((rec, idx) => (
                          <li key={idx} className="flex items-start gap-2 text-sm text-gray-600">
                            <CheckCircle className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
                            {rec}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              );
            })
          )}
        </section>

        {/* Gateway Status */}
        {journeyProgress?.triggeredGateways && journeyProgress.triggeredGateways.length > 0 && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4">
              Triggered Assessments
            </h2>
            <div className="flex flex-wrap gap-2">
              {journeyProgress.triggeredGateways.map((gateway) => (
                <span
                  key={gateway}
                  className="px-3 py-1.5 bg-amber-100 text-amber-800 text-sm font-medium rounded-full"
                >
                  {gateway.charAt(0).toUpperCase() + gateway.slice(1).replace(/([A-Z])/g, ' $1')}
                </span>
              ))}
            </div>
            <p className="text-xs text-gray-500 mt-3">
              These additional assessments have been added to your journey based on your responses.
            </p>
          </section>
        )}

        {/* CTA to continue journey */}
        {journeyProgress && journeyProgress.currentDay <= 15 && (
          <Link
            href="/journey"
            className="block bg-gradient-to-r from-indigo-500 to-purple-500 rounded-2xl p-4 text-white hover:opacity-90 transition-opacity"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-semibold">Continue Your Journey</h3>
                <p className="text-sm text-white/80">
                  Day {journeyProgress.currentDay} awaits
                </p>
              </div>
              <ChevronRight className="w-6 h-6" />
            </div>
          </Link>
        )}
      </main>
    </div>
  );
}
