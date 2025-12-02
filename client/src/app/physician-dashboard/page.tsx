"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import Link from "next/link";
import { useState } from "react";
import { UserButton } from "@clerk/nextjs";
import {
  Users,
  Search,
  Filter,
  Clock,
  CheckCircle,
  AlertCircle,
  ArrowRight,
  Activity,
  ClipboardList,
  Settings,
  Moon,
} from "lucide-react";

type ReviewStatus =
  | "all"
  | "intake_in_progress"
  | "pending_review"
  | "under_review"
  | "interventions_prepared"
  | "interventions_active";

const statusConfig: Record<
  string,
  { label: string; color: string; bgColor: string; icon: React.ReactNode }
> = {
  intake_in_progress: {
    label: "In Progress",
    color: "text-blue-700",
    bgColor: "bg-blue-100",
    icon: <Clock className="w-4 h-4" />,
  },
  pending_review: {
    label: "Pending Review",
    color: "text-amber-700",
    bgColor: "bg-amber-100",
    icon: <AlertCircle className="w-4 h-4" />,
  },
  under_review: {
    label: "Under Review",
    color: "text-purple-700",
    bgColor: "bg-purple-100",
    icon: <Activity className="w-4 h-4" />,
  },
  interventions_prepared: {
    label: "Interventions Ready",
    color: "text-teal-700",
    bgColor: "bg-teal-100",
    icon: <ClipboardList className="w-4 h-4" />,
  },
  interventions_active: {
    label: "Active Treatment",
    color: "text-green-700",
    bgColor: "bg-green-100",
    icon: <CheckCircle className="w-4 h-4" />,
  },
};

export default function PhysicianDashboard() {
  const [statusFilter, setStatusFilter] = useState<ReviewStatus>("all");
  const [searchTerm, setSearchTerm] = useState("");

  const patients = useQuery(api.physician.getAllPatientsWithProgress, {
    statusFilter: statusFilter === "all" ? undefined : statusFilter,
    searchTerm: searchTerm || undefined,
  });

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

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

  // Count patients by status
  const allPatients = useQuery(api.physician.getAllPatientsWithProgress, {});
  const statusCounts = allPatients?.reduce(
    (acc, p) => {
      const status = p.review_status || "intake_in_progress";
      acc[status] = (acc[status] || 0) + 1;
      return acc;
    },
    {} as Record<string, number>
  );

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
                className="flex items-center gap-2 text-teal-600 font-medium"
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
        {/* Stats Overview */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
          {[
            {
              key: "intake_in_progress",
              label: "In Progress",
              count: statusCounts?.intake_in_progress || 0,
            },
            {
              key: "pending_review",
              label: "Pending Review",
              count: statusCounts?.pending_review || 0,
            },
            {
              key: "under_review",
              label: "Under Review",
              count: statusCounts?.under_review || 0,
            },
            {
              key: "interventions_prepared",
              label: "Ready",
              count: statusCounts?.interventions_prepared || 0,
            },
            {
              key: "interventions_active",
              label: "Active",
              count: statusCounts?.interventions_active || 0,
            },
          ].map((stat) => {
            const config = statusConfig[stat.key];
            return (
              <button
                key={stat.key}
                onClick={() => setStatusFilter(stat.key as ReviewStatus)}
                className={`p-4 rounded-xl border transition-all ${
                  statusFilter === stat.key
                    ? `${config.bgColor} border-current ${config.color}`
                    : "bg-white border-gray-200 hover:border-gray-300"
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <span
                    className={
                      statusFilter === stat.key ? config.color : "text-gray-400"
                    }
                  >
                    {config.icon}
                  </span>
                  <span className="text-2xl font-bold text-gray-900">
                    {stat.count}
                  </span>
                </div>
                <p className="text-sm text-gray-600">{stat.label}</p>
              </button>
            );
          })}
        </div>

        {/* Search and Filter */}
        <div className="flex flex-col sm:flex-row gap-4 mb-6">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search patients by name..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-3 rounded-xl border border-gray-200 focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 outline-none"
            />
          </div>

          <div className="flex items-center gap-2">
            <Filter className="w-5 h-5 text-gray-400" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as ReviewStatus)}
              className="px-4 py-3 rounded-xl border border-gray-200 focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 outline-none bg-white"
            >
              <option value="all">All Patients</option>
              <option value="intake_in_progress">In Progress</option>
              <option value="pending_review">Pending Review</option>
              <option value="under_review">Under Review</option>
              <option value="interventions_prepared">Interventions Ready</option>
              <option value="interventions_active">Active Treatment</option>
            </select>
          </div>
        </div>

        {/* Patient List */}
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-900">
              {statusFilter === "all"
                ? "All Patients"
                : statusConfig[statusFilter]?.label || "Patients"}
              {patients && (
                <span className="ml-2 text-gray-400 font-normal">
                  ({patients.length})
                </span>
              )}
            </h2>
          </div>

          {!patients ? (
            <div className="p-12 text-center">
              <div className="animate-spin w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full mx-auto mb-4" />
              <p className="text-gray-500">Loading patients...</p>
            </div>
          ) : patients.length === 0 ? (
            <div className="p-12 text-center">
              <Users className="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">No patients found</p>
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm("")}
                  className="mt-2 text-teal-600 hover:text-teal-700"
                >
                  Clear search
                </button>
              )}
            </div>
          ) : (
            <div className="divide-y divide-gray-100">
              {patients.map((patient) => {
                const status =
                  statusConfig[patient.review_status || "intake_in_progress"];
                return (
                  <Link
                    key={patient._id}
                    href={`/physician-dashboard/patient/${patient._id}`}
                    className="flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
                  >
                    {/* Avatar */}
                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-semibold text-lg">
                      {(patient.name || patient.username)?.[0]?.toUpperCase() ||
                        "?"}
                    </div>

                    {/* Patient Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="font-semibold text-gray-900 truncate">
                          {patient.name || patient.username}
                        </h3>
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${status.bgColor} ${status.color}`}
                        >
                          {status.icon}
                          {status.label}
                        </span>
                      </div>
                      <p className="text-sm text-gray-500">
                        Day {patient.current_day} of 15 &bull; Started{" "}
                        {formatDate(patient.started_at)}
                      </p>
                    </div>

                    {/* Progress */}
                    <div className="hidden sm:block w-32">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-gray-500">Progress</span>
                        <span className="text-xs font-medium text-gray-700">
                          {patient.progress_percentage}%
                        </span>
                      </div>
                      <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-gradient-to-r from-teal-500 to-blue-500 rounded-full transition-all"
                          style={{ width: `${patient.progress_percentage}%` }}
                        />
                      </div>
                    </div>

                    {/* Last Active */}
                    <div className="hidden md:block text-right">
                      <p className="text-xs text-gray-500">Last Active</p>
                      <p className="text-sm font-medium text-gray-700">
                        {formatTimeAgo(patient.last_accessed)}
                      </p>
                    </div>

                    {/* Arrow */}
                    <ArrowRight className="w-5 h-5 text-gray-400" />
                  </Link>
                );
              })}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
