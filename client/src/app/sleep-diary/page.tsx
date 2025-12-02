"use client";

import { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  ArrowLeft, Moon, Sun, Clock, TrendingUp, TrendingDown,
  Calendar, ChevronDown, ChevronUp, Bed, AlarmClock
} from 'lucide-react';

interface SleepLogEntry {
  date: string;
  bedtime: string;
  wakeTime: string;
  asleepTime: string;
  awakenings: number;
  sleepQuality: number;
  totalSleep?: string;
  sleepEfficiency?: number;
}

// Calculate sleep duration
function calculateSleepDuration(asleepTime: string, wakeTime: string): string {
  if (!asleepTime || !wakeTime) return '--';

  try {
    const [asleepHour, asleepMin] = asleepTime.split(':').map(Number);
    const [wakeHour, wakeMin] = wakeTime.split(':').map(Number);

    let asleepMinutes = asleepHour * 60 + asleepMin;
    let wakeMinutes = wakeHour * 60 + wakeMin;

    // Handle crossing midnight
    if (wakeMinutes < asleepMinutes) {
      wakeMinutes += 24 * 60;
    }

    const durationMinutes = wakeMinutes - asleepMinutes;
    const hours = Math.floor(durationMinutes / 60);
    const minutes = durationMinutes % 60;

    return `${hours}h ${minutes}m`;
  } catch {
    return '--';
  }
}

// Calculate sleep efficiency (time asleep / time in bed)
function calculateSleepEfficiency(bedtime: string, asleepTime: string, wakeTime: string): number {
  if (!bedtime || !asleepTime || !wakeTime) return 0;

  try {
    const [bedHour, bedMin] = bedtime.split(':').map(Number);
    const [asleepHour, asleepMin] = asleepTime.split(':').map(Number);
    const [wakeHour, wakeMin] = wakeTime.split(':').map(Number);

    let bedMinutes = bedHour * 60 + bedMin;
    let asleepMinutes = asleepHour * 60 + asleepMin;
    let wakeMinutes = wakeHour * 60 + wakeMin;

    // Handle crossing midnight
    if (asleepMinutes < bedMinutes) asleepMinutes += 24 * 60;
    if (wakeMinutes < bedMinutes) wakeMinutes += 24 * 60;

    const timeInBed = wakeMinutes - bedMinutes;
    const timeAsleep = wakeMinutes - asleepMinutes;

    if (timeInBed <= 0) return 0;
    return Math.round((timeAsleep / timeInBed) * 100);
  } catch {
    return 0;
  }
}

// Get quality color
function getQualityColor(quality: number): string {
  if (quality >= 8) return 'text-green-600 bg-green-100';
  if (quality >= 6) return 'text-blue-600 bg-blue-100';
  if (quality >= 4) return 'text-amber-600 bg-amber-100';
  return 'text-red-600 bg-red-100';
}

// Get efficiency color
function getEfficiencyColor(efficiency: number): string {
  if (efficiency >= 85) return 'text-green-600';
  if (efficiency >= 75) return 'text-blue-600';
  if (efficiency >= 65) return 'text-amber-600';
  return 'text-red-600';
}

export default function SleepDiaryPage() {
  const [sleepLogs, setSleepLogs] = useState<SleepLogEntry[]>([]);
  const [expandedEntry, setExpandedEntry] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadSleepLogs();
  }, []);

  const loadSleepLogs = () => {
    setIsLoading(true);
    try {
      const savedLogs = localStorage.getItem('sleepLogs');
      if (savedLogs) {
        const logs: SleepLogEntry[] = JSON.parse(savedLogs).map((log: any) => ({
          ...log,
          totalSleep: calculateSleepDuration(log.asleepTime, log.wakeTime),
          sleepEfficiency: calculateSleepEfficiency(log.bedtime, log.asleepTime, log.wakeTime),
        }));
        setSleepLogs(logs);
      }
    } catch (error) {
      console.error('Error loading sleep logs:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Calculate averages
  const averages = sleepLogs.length > 0 ? {
    quality: Math.round(sleepLogs.reduce((sum, log) => sum + (log.sleepQuality || 0), 0) / sleepLogs.length * 10) / 10,
    awakenings: Math.round(sleepLogs.reduce((sum, log) => sum + (log.awakenings || 0), 0) / sleepLogs.length * 10) / 10,
    efficiency: Math.round(sleepLogs.reduce((sum, log) => sum + (log.sleepEfficiency || 0), 0) / sleepLogs.length),
  } : null;

  // Get trend (comparing last 7 to previous 7)
  const getTrend = (metric: 'sleepQuality' | 'awakenings'): 'up' | 'down' | 'stable' => {
    if (sleepLogs.length < 7) return 'stable';
    const recent = sleepLogs.slice(0, 7);
    const previous = sleepLogs.slice(7, 14);
    if (previous.length === 0) return 'stable';

    const recentAvg = recent.reduce((sum, log) => sum + (log[metric] || 0), 0) / recent.length;
    const previousAvg = previous.reduce((sum, log) => sum + (log[metric] || 0), 0) / previous.length;

    const diff = recentAvg - previousAvg;
    if (Math.abs(diff) < 0.5) return 'stable';
    return diff > 0 ? 'up' : 'down';
  };

  const qualityTrend = getTrend('sleepQuality');

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-cyan-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-cyan-50">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm border-b border-gray-100 sticky top-0 z-50">
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/dashboard" className="p-2 hover:bg-gray-100 rounded-full">
              <ArrowLeft className="w-5 h-5 text-gray-600" />
            </Link>
            <div>
              <h1 className="text-xl font-bold text-gray-900">Sleep Diary</h1>
              <p className="text-sm text-gray-500">{sleepLogs.length} entries</p>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 py-6 space-y-6">
        {/* Summary Stats */}
        {averages && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4">
              Your Averages
            </h2>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <div className="flex items-center justify-center gap-1 mb-1">
                  <span className="text-2xl font-bold text-gray-900">{averages.quality}</span>
                  {qualityTrend === 'up' && <TrendingUp className="w-4 h-4 text-green-500" />}
                  {qualityTrend === 'down' && <TrendingDown className="w-4 h-4 text-red-500" />}
                </div>
                <p className="text-xs text-gray-500">Sleep Quality</p>
                <p className="text-xs text-gray-400">/10</p>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-gray-900">{averages.awakenings}</div>
                <p className="text-xs text-gray-500">Awakenings</p>
                <p className="text-xs text-gray-400">per night</p>
              </div>
              <div className="text-center">
                <div className={`text-2xl font-bold ${getEfficiencyColor(averages.efficiency)}`}>
                  {averages.efficiency}%
                </div>
                <p className="text-xs text-gray-500">Sleep Efficiency</p>
                <p className="text-xs text-gray-400">time asleep</p>
              </div>
            </div>
          </section>
        )}

        {/* 7-Day Chart */}
        {sleepLogs.length > 0 && (
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4">
              Last 7 Days
            </h2>
            <div className="flex items-end justify-between h-32 gap-2">
              {sleepLogs.slice(0, 7).reverse().map((log, index) => {
                const height = (log.sleepQuality / 10) * 100;
                return (
                  <div key={index} className="flex-1 flex flex-col items-center gap-1">
                    <span className="text-xs font-medium text-gray-900">{log.sleepQuality}</span>
                    <div
                      className={`w-full rounded-t-lg transition-all ${
                        log.sleepQuality >= 7 ? 'bg-green-400' :
                        log.sleepQuality >= 5 ? 'bg-blue-400' :
                        log.sleepQuality >= 3 ? 'bg-amber-400' : 'bg-red-400'
                      }`}
                      style={{ height: `${height}%` }}
                    />
                    <span className="text-xs text-gray-500">
                      {new Date(log.date).toLocaleDateString('en-US', { weekday: 'short' }).charAt(0)}
                    </span>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* Sleep Log Entries */}
        <section className="space-y-3">
          <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide px-1">
            All Entries
          </h2>

          {sleepLogs.length === 0 ? (
            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 text-center">
              <Moon className="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <h3 className="font-medium text-gray-900 mb-2">No sleep logs yet</h3>
              <p className="text-sm text-gray-500 mb-4">
                Complete your daily sleep log to see your history here
              </p>
              <Link
                href="/journey?section=sleeplog"
                className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                <Moon className="w-4 h-4" />
                Start Sleep Log
              </Link>
            </div>
          ) : (
            sleepLogs.map((log, index) => (
              <div
                key={index}
                className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden"
              >
                {/* Entry Header */}
                <button
                  onClick={() => setExpandedEntry(expandedEntry === index ? null : index)}
                  className="w-full p-4 flex items-center justify-between hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center ${getQualityColor(log.sleepQuality)}`}>
                      <span className="font-bold">{log.sleepQuality}</span>
                    </div>
                    <div className="text-left">
                      <p className="font-medium text-gray-900">{log.date}</p>
                      <p className="text-sm text-gray-500">
                        {log.totalSleep || '--'} sleep • {log.awakenings || 0} awakenings
                      </p>
                    </div>
                  </div>
                  {expandedEntry === index ? (
                    <ChevronUp className="w-5 h-5 text-gray-400" />
                  ) : (
                    <ChevronDown className="w-5 h-5 text-gray-400" />
                  )}
                </button>

                {/* Expanded Details */}
                {expandedEntry === index && (
                  <div className="px-4 pb-4 border-t border-gray-100 pt-4 space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-indigo-100 flex items-center justify-center">
                          <Bed className="w-4 h-4 text-indigo-600" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Bedtime</p>
                          <p className="font-medium text-gray-900">{log.bedtime || '--'}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center">
                          <Moon className="w-4 h-4 text-purple-600" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Fell Asleep</p>
                          <p className="font-medium text-gray-900">{log.asleepTime || '--'}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-amber-100 flex items-center justify-center">
                          <AlarmClock className="w-4 h-4 text-amber-600" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Wake Time</p>
                          <p className="font-medium text-gray-900">{log.wakeTime || '--'}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-cyan-100 flex items-center justify-center">
                          <Clock className="w-4 h-4 text-cyan-600" />
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Total Sleep</p>
                          <p className="font-medium text-gray-900">{log.totalSleep || '--'}</p>
                        </div>
                      </div>
                    </div>

                    {/* Sleep Efficiency Bar */}
                    {log.sleepEfficiency !== undefined && (
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <p className="text-sm text-gray-500">Sleep Efficiency</p>
                          <p className={`text-sm font-medium ${getEfficiencyColor(log.sleepEfficiency)}`}>
                            {log.sleepEfficiency}%
                          </p>
                        </div>
                        <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all ${
                              log.sleepEfficiency >= 85 ? 'bg-green-500' :
                              log.sleepEfficiency >= 75 ? 'bg-blue-500' :
                              log.sleepEfficiency >= 65 ? 'bg-amber-500' : 'bg-red-500'
                            }`}
                            style={{ width: `${log.sleepEfficiency}%` }}
                          />
                        </div>
                        <p className="text-xs text-gray-400 mt-1">
                          {log.sleepEfficiency >= 85 ? 'Excellent' :
                           log.sleepEfficiency >= 75 ? 'Good' :
                           log.sleepEfficiency >= 65 ? 'Fair' : 'Needs improvement'}
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))
          )}
        </section>
      </main>
    </div>
  );
}
