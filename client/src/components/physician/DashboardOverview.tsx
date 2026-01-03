"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useMemo } from "react";
import {
  Users,
  Clock,
  CheckCircle,
  AlertCircle,
  TrendingUp,
  TrendingDown,
  Activity,
  Calendar,
  Brain,
  Pill,
  Moon,
  Sun,
} from "lucide-react";

interface PatientData {
  _id: string;
  username: string;
  name?: string;
  current_day: number;
  started_at: number;
  last_accessed: number;
  progress_percentage: number;
  review_status?: string;
}

interface DashboardOverviewProps {
  patients: PatientData[];
}

export function DashboardOverview({ patients }: DashboardOverviewProps) {
  const stats = useMemo(() => {
    if (!patients || patients.length === 0) {
      return {
        totalPatients: 0,
        activeToday: 0,
        needingReview: 0,
        completionRate: 0,
        avgProgress: 0,
        newThisWeek: 0,
        avgDaysActive: 0,
        statusBreakdown: {},
      };
    }

    const now = Date.now();
    const oneDayAgo = now - 24 * 60 * 60 * 1000;
    const oneWeekAgo = now - 7 * 24 * 60 * 60 * 1000;

    const activeToday = patients.filter((p) => p.last_accessed > oneDayAgo).length;
    const newThisWeek = patients.filter((p) => p.started_at > oneWeekAgo).length;
    const needingReview = patients.filter(
      (p) => p.review_status === "pending_review"
    ).length;
    const completed = patients.filter((p) => p.current_day >= 15).length;
    const completionRate = patients.length > 0 ? Math.round((completed / patients.length) * 100) : 0;
    const avgProgress = Math.round(
      patients.reduce((acc, p) => acc + p.progress_percentage, 0) / patients.length
    );

    const avgDaysActive = Math.round(
      patients.reduce((acc, p) => {
        const days = Math.ceil((now - p.started_at) / (24 * 60 * 60 * 1000));
        return acc + Math.min(days, p.current_day);
      }, 0) / patients.length
    );

    const statusBreakdown = patients.reduce((acc, p) => {
      const status = p.review_status || "intake_in_progress";
      acc[status] = (acc[status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      totalPatients: patients.length,
      activeToday,
      needingReview,
      completionRate,
      avgProgress,
      newThisWeek,
      avgDaysActive,
      statusBreakdown,
    };
  }, [patients]);

  // Get patients needing attention
  const urgentPatients = useMemo(() => {
    return patients
      .filter((p) => {
        const daysSinceActive = Math.ceil(
          (Date.now() - p.last_accessed) / (24 * 60 * 60 * 1000)
        );
        return (
          p.review_status === "pending_review" ||
          daysSinceActive > 3 ||
          (p.current_day >= 10 && p.review_status !== "interventions_active")
        );
      })
      .slice(0, 5);
  }, [patients]);

  // Get recently active patients
  const recentlyActive = useMemo(() => {
    return [...patients]
      .sort((a, b) => b.last_accessed - a.last_accessed)
      .slice(0, 5);
  }, [patients]);

  const formatTimeAgo = (timestamp: number) => {
    const diff = Date.now() - timestamp;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return "Just now";
  };

  return (
    <div className="space-y-6">
      {/* Key Metrics */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <MetricCard
          icon={<Users className="w-5 h-5" />}
          label="Total Patients"
          value={stats.totalPatients}
          trend={stats.newThisWeek > 0 ? `+${stats.newThisWeek} this week` : undefined}
          trendUp={true}
          color="blue"
        />
        <MetricCard
          icon={<Activity className="w-5 h-5" />}
          label="Active Today"
          value={stats.activeToday}
          subtitle={`${Math.round((stats.activeToday / Math.max(stats.totalPatients, 1)) * 100)}% of total`}
          color="green"
        />
        <MetricCard
          icon={<AlertCircle className="w-5 h-5" />}
          label="Needs Review"
          value={stats.needingReview}
          urgent={stats.needingReview > 0}
          color="amber"
        />
        <MetricCard
          icon={<TrendingUp className="w-5 h-5" />}
          label="Avg Progress"
          value={`${stats.avgProgress}%`}
          subtitle={`Day ${stats.avgDaysActive} avg`}
          color="purple"
        />
      </div>

      {/* Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Needs Attention */}
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-4 py-3 border-b border-gray-100 flex items-center justify-between">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-amber-500" />
              Needs Attention
            </h3>
            <span className="text-xs text-gray-400">
              {urgentPatients.length} patients
            </span>
          </div>
          <div className="divide-y divide-gray-100">
            {urgentPatients.length === 0 ? (
              <div className="p-6 text-center text-gray-500">
                <CheckCircle className="w-8 h-8 mx-auto mb-2 text-green-400" />
                <p className="text-sm">All caught up!</p>
              </div>
            ) : (
              urgentPatients.map((patient) => (
                <PatientRow
                  key={patient._id}
                  patient={patient}
                  formatTimeAgo={formatTimeAgo}
                  showStatus
                />
              ))
            )}
          </div>
        </div>

        {/* Recently Active */}
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-4 py-3 border-b border-gray-100 flex items-center justify-between">
            <h3 className="font-semibold text-gray-900 flex items-center gap-2">
              <Clock className="w-4 h-4 text-blue-500" />
              Recently Active
            </h3>
            <span className="text-xs text-gray-400">Last 24h</span>
          </div>
          <div className="divide-y divide-gray-100">
            {recentlyActive.length === 0 ? (
              <div className="p-6 text-center text-gray-500">
                <Moon className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                <p className="text-sm">No recent activity</p>
              </div>
            ) : (
              recentlyActive.map((patient) => (
                <PatientRow
                  key={patient._id}
                  patient={patient}
                  formatTimeAgo={formatTimeAgo}
                  showProgress
                />
              ))
            )}
          </div>
        </div>
      </div>

      {/* Quick Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <QuickStat
          icon={<Pill className="w-4 h-4" />}
          label="Active Treatments"
          value={stats.statusBreakdown.interventions_active || 0}
          color="green"
        />
        <QuickStat
          icon={<Brain className="w-4 h-4" />}
          label="Pending Analysis"
          value={stats.statusBreakdown.pending_review || 0}
          color="amber"
        />
        <QuickStat
          icon={<Calendar className="w-4 h-4" />}
          label="In Progress"
          value={stats.statusBreakdown.intake_in_progress || 0}
          color="blue"
        />
        <QuickStat
          icon={<CheckCircle className="w-4 h-4" />}
          label="Completion Rate"
          value={`${stats.completionRate}%`}
          color="purple"
        />
      </div>
    </div>
  );
}

// Metric Card Component
function MetricCard({
  icon,
  label,
  value,
  subtitle,
  trend,
  trendUp,
  urgent,
  color,
}: {
  icon: React.ReactNode;
  label: string;
  value: string | number;
  subtitle?: string;
  trend?: string;
  trendUp?: boolean;
  urgent?: boolean;
  color: "blue" | "green" | "amber" | "purple";
}) {
  const colorClasses = {
    blue: "from-blue-500/10 to-blue-600/5 border-blue-200",
    green: "from-green-500/10 to-green-600/5 border-green-200",
    amber: "from-amber-500/10 to-amber-600/5 border-amber-200",
    purple: "from-purple-500/10 to-purple-600/5 border-purple-200",
  };

  const iconColors = {
    blue: "text-blue-500",
    green: "text-green-500",
    amber: "text-amber-500",
    purple: "text-purple-500",
  };

  return (
    <div
      className={`p-4 rounded-xl border bg-gradient-to-br ${colorClasses[color]} ${
        urgent ? "ring-2 ring-amber-400 ring-offset-2" : ""
      }`}
    >
      <div className={`mb-2 ${iconColors[color]}`}>{icon}</div>
      <p className="text-2xl font-bold text-gray-900">{value}</p>
      <p className="text-sm text-gray-600">{label}</p>
      {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
      {trend && (
        <div
          className={`flex items-center gap-1 mt-2 text-xs ${
            trendUp ? "text-green-600" : "text-red-600"
          }`}
        >
          {trendUp ? (
            <TrendingUp className="w-3 h-3" />
          ) : (
            <TrendingDown className="w-3 h-3" />
          )}
          {trend}
        </div>
      )}
    </div>
  );
}

// Quick Stat Component
function QuickStat({
  icon,
  label,
  value,
  color,
}: {
  icon: React.ReactNode;
  label: string;
  value: string | number;
  color: "blue" | "green" | "amber" | "purple";
}) {
  const bgColors = {
    blue: "bg-blue-50",
    green: "bg-green-50",
    amber: "bg-amber-50",
    purple: "bg-purple-50",
  };

  const textColors = {
    blue: "text-blue-600",
    green: "text-green-600",
    amber: "text-amber-600",
    purple: "text-purple-600",
  };

  return (
    <div className={`p-3 rounded-xl ${bgColors[color]}`}>
      <div className="flex items-center justify-between">
        <div className={textColors[color]}>{icon}</div>
        <span className={`text-lg font-bold ${textColors[color]}`}>{value}</span>
      </div>
      <p className="text-xs text-gray-600 mt-1">{label}</p>
    </div>
  );
}

// Patient Row Component
function PatientRow({
  patient,
  formatTimeAgo,
  showStatus,
  showProgress,
}: {
  patient: PatientData;
  formatTimeAgo: (timestamp: number) => string;
  showStatus?: boolean;
  showProgress?: boolean;
}) {
  const statusConfig: Record<string, { label: string; color: string }> = {
    intake_in_progress: { label: "In Progress", color: "bg-blue-100 text-blue-700" },
    pending_review: { label: "Needs Review", color: "bg-amber-100 text-amber-700" },
    under_review: { label: "Under Review", color: "bg-purple-100 text-purple-700" },
    interventions_prepared: { label: "Ready", color: "bg-teal-100 text-teal-700" },
    interventions_active: { label: "Active", color: "bg-green-100 text-green-700" },
  };

  const status = statusConfig[patient.review_status || "intake_in_progress"];

  return (
    <a
      href={`/physician-dashboard/patient/${patient._id}`}
      className="flex items-center gap-3 p-3 hover:bg-gray-50 transition-colors"
    >
      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-semibold">
        {(patient.name || patient.username)?.[0]?.toUpperCase() || "?"}
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-medium text-gray-900 truncate">
          {patient.name ? (
            <>
              {patient.name}
              <span className="text-gray-400 font-normal ml-1">
                ({patient.username})
              </span>
            </>
          ) : (
            patient.username
          )}
        </p>
        <p className="text-xs text-gray-500">
          Day {patient.current_day} • {formatTimeAgo(patient.last_accessed)}
        </p>
      </div>
      {showStatus && (
        <span className={`px-2 py-0.5 rounded text-xs font-medium ${status.color}`}>
          {status.label}
        </span>
      )}
      {showProgress && (
        <div className="w-16">
          <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-teal-500 to-blue-500 rounded-full"
              style={{ width: `${patient.progress_percentage}%` }}
            />
          </div>
          <p className="text-[10px] text-gray-400 text-center mt-0.5">
            {patient.progress_percentage}%
          </p>
        </div>
      )}
    </a>
  );
}
