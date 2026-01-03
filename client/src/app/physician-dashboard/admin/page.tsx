"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import Link from "next/link";
import { useState } from "react";
import { PhysicianLogoutButton } from "@/components/PhysicianAuthGuard";
import { Id } from "@/convex/_generated/dataModel";
import {
  Users,
  ClipboardList,
  Settings,
  Shield,
  Trash2,
  Key,
  AlertTriangle,
  CheckCircle,
  X,
  Search,
  Code,
  UserX,
  RotateCcw,
  Edit,
  ChevronDown,
  ChevronUp,
  Activity,
  Database,
  Loader2,
  Watch,
  FileQuestion,
  CheckCircle2,
  XCircle,
  AlertCircle,
  HardDrive,
} from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

// SHA-256 hash function for password
async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

interface UserData {
  _id: Id<"users">;
  username: string;
  email?: string;
  role?: string;
  current_day: number;
  created_at: number;
  last_accessed: number;
  developer_mode?: boolean;
  completedDays: number;
  responseCount: number;
  phase: string;
  interventionCount: number;
  isTestUser: boolean;
  full_name?: string;
}

export default function AdminToolsPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedUsers, setSelectedUsers] = useState<Set<string>>(new Set());
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);
  const [showBulkDeleteConfirm, setShowBulkDeleteConfirm] = useState(false);
  const [showPurgeTestConfirm, setShowPurgeTestConfirm] = useState(false);
  const [showPurgeGeneratedConfirm, setShowPurgeGeneratedConfirm] = useState(false);
  const [showPurgeAllConfirm, setShowPurgeAllConfirm] = useState(false);
  const [showResetPasswordModal, setShowResetPasswordModal] = useState<string | null>(null);
  const [showResetProgressConfirm, setShowResetProgressConfirm] = useState<string | null>(null);
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [operationResult, setOperationResult] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [expandedUser, setExpandedUser] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [filterRole, setFilterRole] = useState<string>("all");
  const [filterTestUsers, setFilterTestUsers] = useState<"all" | "test" | "real">("all");

  // Data Verification state
  const [verificationUserId, setVerificationUserId] = useState<string | null>(null);
  const [verificationData, setVerificationData] = useState<any>(null);
  const [wearableDataCounts, setWearableDataCounts] = useState<any>(null);
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [verifyingUserId, setVerifyingUserId] = useState<string | null>(null);

  // Reset options state
  const [resetIncludeWearables, setResetIncludeWearables] = useState(false);
  const [showCompleteResetConfirm, setShowCompleteResetConfirm] = useState<string | null>(null);

  // Mock Data Simulation state
  const [mockDataUserId, setMockDataUserId] = useState<string | null>(null);
  const [mockDataPattern, setMockDataPattern] = useState<string>("normal");
  const [mockDataDays, setMockDataDays] = useState<number>(10);
  const [isGeneratingMock, setIsGeneratingMock] = useState(false);

  // Queries
  const users = useQuery(api.admin.getAllUsersAdmin);
  const systemStats = useQuery(api.admin.getSystemStats);

  // Mutations
  const deleteUser = useMutation(api.admin.deleteUser);
  const deleteMultipleUsers = useMutation(api.admin.deleteMultipleUsers);
  const purgeTestUsers = useMutation(api.admin.purgeTestUsers);
  const purgeGeneratedTestUsers = useMutation(api.admin.purgeGeneratedTestUsers);
  const purgeAllTestUsers = useMutation(api.admin.purgeAllTestUsers);
  const resetUserPassword = useMutation(api.admin.resetUserPassword);
  const resetUserProgress = useMutation(api.admin.resetUserProgress);
  const resetUserComplete = useMutation(api.admin.resetUserComplete);
  const clearWearableData = useMutation(api.admin.clearWearableData);
  const updateUserField = useMutation(api.admin.updateUserField);
  const setUserRole = useMutation(api.admin.setUserRole);

  // Verification queries (using useQuery with skip)
  const selectedVerificationUser = users?.find((u: UserData) => u._id === verificationUserId);
  const verificationQuery = useQuery(
    api.healthkit.verifyDataSources,
    verificationUserId ? { userId: verificationUserId as Id<"users"> } : "skip"
  );
  const wearableCountsQuery = useQuery(
    api.healthkit.getWearableDataCounts,
    verificationUserId ? { userId: verificationUserId as Id<"users"> } : "skip"
  );

  // Mock data queries
  const mockPatterns = useQuery(api.mockData.getAvailableMockPatterns);
  const mockDataStatus = useQuery(
    api.mockData.getMockDataStatus,
    mockDataUserId ? { userId: mockDataUserId as Id<"users"> } : "skip"
  );

  // Mock data mutations
  const generateMockData = useMutation(api.mockData.generateMockSleepLogData);
  const clearMockData = useMutation(api.mockData.clearMockData);

  // Filter users
  const filteredUsers = users?.filter((user: UserData) => {
    const matchesSearch =
      user.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.full_name?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesRole =
      filterRole === "all" || (user.role || "patient") === filterRole;

    const matchesTestFilter =
      filterTestUsers === "all" ||
      (filterTestUsers === "test" && user.isTestUser) ||
      (filterTestUsers === "real" && !user.isTestUser);

    return matchesSearch && matchesRole && matchesTestFilter;
  });

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const handleDeleteUser = async (userId: Id<"users">) => {
    setIsLoading(true);
    try {
      const result = await deleteUser({ userId });
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Deleted user "${result.deletedUser}" and ${result.deletedRecords} related records`,
        });
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to delete user" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
    setShowDeleteConfirm(null);
  };

  const handleBulkDelete = async () => {
    setIsLoading(true);
    try {
      const userIds = Array.from(selectedUsers) as Id<"users">[];
      const result = await deleteMultipleUsers({ userIds });
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Deleted ${result.results.filter((r: { success: boolean }) => r.success).length} users and ${result.totalDeleted} total records`,
        });
        setSelectedUsers(new Set());
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
    setShowBulkDeleteConfirm(false);
  };

  const handlePurgeTestUsers = async () => {
    setIsLoading(true);
    try {
      const result = await purgeTestUsers();
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Purged ${result.purgedCount} test users and ${result.totalRecordsDeleted} total records`,
        });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
    setShowPurgeTestConfirm(false);
  };

  const handlePurgeGeneratedTestUsers = async () => {
    setIsLoading(true);
    try {
      const result = await purgeGeneratedTestUsers();
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Purged ${result.purgedCount} generated test users (test_*) and ${result.totalRecordsDeleted} total records`,
        });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
    setShowPurgeGeneratedConfirm(false);
  };

  const handlePurgeAllTestUsers = async () => {
    setIsLoading(true);
    try {
      const result = await purgeAllTestUsers();
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Purged ${result.purgedCount} test users (user1-10 + test_*) and ${result.totalRecordsDeleted} total records`,
        });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
    setShowPurgeAllConfirm(false);
  };

  const handleResetPassword = async (userId: Id<"users">) => {
    if (newPassword !== confirmPassword) {
      setOperationResult({ type: "error", message: "Passwords do not match" });
      return;
    }
    if (newPassword.length < 1) {
      setOperationResult({ type: "error", message: "Password cannot be empty" });
      return;
    }

    setIsLoading(true);
    try {
      const hash = await hashPassword(newPassword);
      const result = await resetUserPassword({ userId, newPasswordHash: hash });
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Password reset for "${result.username}". ${result.sessionsInvalidated} sessions invalidated.`,
        });
        setShowResetPasswordModal(null);
        setNewPassword("");
        setConfirmPassword("");
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to reset password" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
  };

  const handleResetProgress = async (userId: Id<"users">, includeWearables: boolean = false) => {
    setIsLoading(true);
    try {
      const result = await resetUserProgress({ userId, clearWearableData: includeWearables });
      if (result.success) {
        const wearableMsg = result.wearableDataCleared
          ? " (including wearable data)"
          : " (wearable data preserved)";
        setOperationResult({
          type: "success",
          message: `Reset progress for "${result.username}". ${result.deletedRecords} records deleted${wearableMsg}, reset to Day ${result.resetToDay}.`,
        });
        setShowResetProgressConfirm(null);
        setResetIncludeWearables(false);
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to reset progress" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
  };

  const handleCompleteReset = async (userId: Id<"users">) => {
    setIsLoading(true);
    try {
      const result = await resetUserComplete({ userId });
      if (result.success) {
        // Build a summary of deleted tables
        const tableSummary = Object.entries(result.deletedTables || {})
          .map(([table, count]) => `${table}: ${count}`)
          .join(", ");

        setOperationResult({
          type: "success",
          message: `Complete reset for "${result.username}". ${result.deletedRecords} total records deleted across all tables. User reset to Day ${result.resetToDay}.`,
        });
        setShowCompleteResetConfirm(null);
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to complete reset" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
  };

  const handleClearWearableData = async (userId: Id<"users">) => {
    setIsLoading(true);
    try {
      const result = await clearWearableData({ userId });
      if (result.success) {
        const tableSummary = Object.entries(result.deletedTables || {})
          .map(([table, count]) => `${table}: ${count}`)
          .join(", ");

        setOperationResult({
          type: "success",
          message: `Cleared wearable data for "${result.username}". ${result.deletedRecords} records deleted. Tables: ${tableSummary || "none"}`,
        });
        // Reset verification state if viewing this user
        if (verificationUserId === userId) {
          setVerificationUserId(null);
        }
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to clear wearable data" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
  };

  const handleOpenVerification = (userId: string) => {
    setVerificationUserId(userId);
    setShowVerificationModal(true);
  };

  const handleGenerateMockData = async () => {
    if (!mockDataUserId) return;

    setIsGeneratingMock(true);
    try {
      const result = await generateMockData({
        userId: mockDataUserId as Id<"users">,
        days: mockDataDays,
        pattern: mockDataPattern as "normal" | "insomnia" | "delayed_phase" | "irregular" | "short_sleeper",
      });

      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Generated ${result.createdRecords} mock ${result.pattern} sleep records (${result.dateRange?.start} to ${result.dateRange?.end})`,
        });
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to generate mock data" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsGeneratingMock(false);
  };

  const handleClearMockData = async (batchId?: string) => {
    if (!mockDataUserId) return;

    setIsGeneratingMock(true);
    try {
      const result = await clearMockData({
        userId: mockDataUserId as Id<"users">,
        batchId,
      });

      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Cleared ${result.deletedCount} mock data records`,
        });
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to clear mock data" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsGeneratingMock(false);
  };

  const handleToggleDevMode = async (userId: Id<"users">, currentValue: boolean) => {
    try {
      await updateUserField({ userId, field: "developer_mode", value: !currentValue });
      setOperationResult({
        type: "success",
        message: `Developer mode ${!currentValue ? "enabled" : "disabled"}`,
      });
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
  };

  const handleSetRole = async (userId: Id<"users">, role: "patient" | "physician" | "admin") => {
    try {
      const result = await setUserRole({ userId, role });
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Changed role for "${result.username}" from ${result.oldRole} to ${result.newRole}`,
        });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
  };

  const toggleUserSelection = (userId: string) => {
    const newSelected = new Set(selectedUsers);
    if (newSelected.has(userId)) {
      newSelected.delete(userId);
    } else {
      newSelected.add(userId);
    }
    setSelectedUsers(newSelected);
  };

  const selectAllFiltered = () => {
    if (filteredUsers) {
      const allIds = new Set<string>(filteredUsers.map((u: UserData) => u._id as string));
      setSelectedUsers(allIds);
    }
  };

  const clearSelection = () => {
    setSelectedUsers(new Set());
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
                <p className="text-xs text-gray-500">Admin Tools</p>
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
                className="flex items-center gap-2 text-red-600 font-medium"
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
        {/* Operation Result Toast */}
        {operationResult && (
          <div
            className={`fixed top-20 right-4 z-50 max-w-md p-4 rounded-xl shadow-lg border ${
              operationResult.type === "success"
                ? "bg-green-50 border-green-200 text-green-800"
                : "bg-red-50 border-red-200 text-red-800"
            }`}
          >
            <div className="flex items-start gap-3">
              {operationResult.type === "success" ? (
                <CheckCircle className="w-5 h-5 mt-0.5" />
              ) : (
                <AlertTriangle className="w-5 h-5 mt-0.5" />
              )}
              <p className="flex-1">{operationResult.message}</p>
              <button onClick={() => setOperationResult(null)}>
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* System Stats */}
        {systemStats && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-center gap-2 text-gray-500 mb-2">
                <Users className="w-4 h-4" />
                <span className="text-sm">Total Users</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">{systemStats.totalUsers}</p>
              <p className="text-xs text-gray-500 mt-1">
                {systemStats.testUsers} test / {systemStats.realUsers} real
              </p>
            </div>

            <div className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-center gap-2 text-gray-500 mb-2">
                <Activity className="w-4 h-4" />
                <span className="text-sm">Active (7 days)</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">{systemStats.activeUsersLast7Days}</p>
            </div>

            <div className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-center gap-2 text-gray-500 mb-2">
                <Database className="w-4 h-4" />
                <span className="text-sm">Total Responses</span>
              </div>
              <p className="text-2xl font-bold text-gray-900">{systemStats.totalResponses}</p>
            </div>

            <div className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-center gap-2 text-gray-500 mb-2">
                <Shield className="w-4 h-4" />
                <span className="text-sm">By Role</span>
              </div>
              <p className="text-sm text-gray-700">
                {systemStats.roleDistribution.patient} patients · {systemStats.roleDistribution.physician} physicians · {systemStats.roleDistribution.admin} admins
              </p>
            </div>
          </div>
        )}

        {/* Quick Actions */}
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
          <div className="flex flex-wrap gap-4">
            <button
              onClick={() => setShowPurgeTestConfirm(true)}
              className="flex items-center gap-2 px-4 py-2 bg-orange-100 text-orange-700 rounded-lg hover:bg-orange-200 transition-colors"
            >
              <UserX className="w-4 h-4" />
              Purge user1-user10
            </button>

            <button
              onClick={() => setShowPurgeGeneratedConfirm(true)}
              className="flex items-center gap-2 px-4 py-2 bg-purple-100 text-purple-700 rounded-lg hover:bg-purple-200 transition-colors"
            >
              <UserX className="w-4 h-4" />
              Purge test_* Users
            </button>

            <button
              onClick={() => setShowPurgeAllConfirm(true)}
              className="flex items-center gap-2 px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
            >
              <UserX className="w-4 h-4" />
              Purge ALL Test Users
            </button>

            {selectedUsers.size > 0 && (
              <>
                <button
                  onClick={() => setShowBulkDeleteConfirm(true)}
                  className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                  Delete Selected ({selectedUsers.size})
                </button>
                <button
                  onClick={clearSelection}
                  className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                >
                  <X className="w-4 h-4" />
                  Clear Selection
                </button>
              </>
            )}
          </div>
        </div>

        {/* Data Source Verification Tools */}
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-8">
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-cyan-100 rounded-lg">
              <HardDrive className="w-5 h-5 text-cyan-700" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Data Source Verification</h2>
              <p className="text-sm text-gray-500">Verify wearable data authenticity and identify data quality issues</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* User Selection for Verification */}
            <div className="space-y-3">
              <label className="block text-sm font-medium text-gray-700">Select User to Verify</label>
              <select
                value={verificationUserId || ""}
                onChange={(e) => setVerificationUserId(e.target.value || null)}
                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:border-cyan-500 focus:ring-2 focus:ring-cyan-500/20 outline-none bg-white"
              >
                <option value="">-- Select a user --</option>
                {users?.map((user: UserData) => (
                  <option key={user._id} value={user._id}>
                    {user.username} {user.email ? `(${user.email})` : ""} {user.isTestUser ? "[TEST]" : ""}
                  </option>
                ))}
              </select>
            </div>

            {/* Quick Status */}
            {verificationUserId && (
              <div className="flex items-center gap-4">
                {verificationQuery ? (
                  <div className={`flex-1 p-4 rounded-lg border ${
                    verificationQuery.authenticityStatus === "verified"
                      ? "bg-green-50 border-green-200"
                      : verificationQuery.authenticityStatus === "questionnaire_only"
                      ? "bg-yellow-50 border-yellow-200"
                      : verificationQuery.authenticityStatus === "mixed"
                      ? "bg-orange-50 border-orange-200"
                      : "bg-gray-50 border-gray-200"
                  }`}>
                    <div className="flex items-center gap-2 mb-1">
                      {verificationQuery.authenticityStatus === "verified" ? (
                        <CheckCircle2 className="w-5 h-5 text-green-600" />
                      ) : verificationQuery.authenticityStatus === "questionnaire_only" ? (
                        <FileQuestion className="w-5 h-5 text-yellow-600" />
                      ) : verificationQuery.authenticityStatus === "mixed" ? (
                        <AlertCircle className="w-5 h-5 text-orange-600" />
                      ) : (
                        <XCircle className="w-5 h-5 text-gray-600" />
                      )}
                      <span className="font-semibold text-sm">
                        {verificationQuery.authenticityStatus?.toUpperCase().replace("_", " ")}
                      </span>
                    </div>
                    <p className="text-sm text-gray-600">{verificationQuery.authenticityMessage}</p>
                  </div>
                ) : (
                  <div className="flex-1 p-4 rounded-lg bg-gray-50 border border-gray-200">
                    <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Detailed Verification Results */}
          {verificationUserId && verificationQuery && (
            <div className="mt-6 space-y-4">
              {/* Summary Stats */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-2 text-gray-500 text-xs mb-1">
                    <Database className="w-3 h-3" />
                    Total Sleep Records
                  </div>
                  <p className="text-xl font-bold text-gray-900">{verificationQuery.summary?.totalSleepRecords || 0}</p>
                </div>
                <div className="p-3 bg-green-50 rounded-lg">
                  <div className="flex items-center gap-2 text-green-700 text-xs mb-1">
                    <Watch className="w-3 h-3" />
                    Wearable Records
                  </div>
                  <p className="text-xl font-bold text-green-700">{verificationQuery.summary?.wearableRecords || 0}</p>
                </div>
                <div className="p-3 bg-yellow-50 rounded-lg">
                  <div className="flex items-center gap-2 text-yellow-700 text-xs mb-1">
                    <FileQuestion className="w-3 h-3" />
                    Questionnaire Records
                  </div>
                  <p className="text-xl font-bold text-yellow-700">{verificationQuery.summary?.questionnaireRecords || 0}</p>
                </div>
                <div className="p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-2 text-blue-700 text-xs mb-1">
                    <Activity className="w-3 h-3" />
                    Heart Rate Records
                  </div>
                  <p className="text-xl font-bold text-blue-700">{verificationQuery.summary?.heartRateRecords || 0}</p>
                </div>
              </div>

              {/* Source Breakdown */}
              {verificationQuery.sourceBreakdown && Object.keys(verificationQuery.sourceBreakdown).length > 0 && (
                <div className="p-4 bg-gray-50 rounded-lg">
                  <h4 className="font-medium text-gray-900 mb-3">Data Sources</h4>
                  <div className="space-y-2">
                    {Object.entries(verificationQuery.sourceBreakdown).map(([source, data]: [string, any]) => (
                      <div key={source} className="flex items-center justify-between p-2 bg-white rounded border border-gray-200">
                        <div className="flex items-center gap-2">
                          {source === "Questionnaire" ? (
                            <FileQuestion className="w-4 h-4 text-yellow-600" />
                          ) : (
                            <Watch className="w-4 h-4 text-green-600" />
                          )}
                          <span className="font-medium">{source}</span>
                          <span className="text-xs text-gray-500">({data.count} records)</span>
                        </div>
                        <div className="flex items-center gap-4 text-xs text-gray-500">
                          {data.dateRange && (
                            <span>{data.dateRange.first} - {data.dateRange.last}</span>
                          )}
                          {data.hasDeepSleep && (
                            <span className="px-2 py-0.5 bg-purple-100 text-purple-700 rounded">Deep Sleep</span>
                          )}
                          {data.hasRemSleep && (
                            <span className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded">REM</span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Data Quality Issues */}
              {verificationQuery.issues && verificationQuery.issues.length > 0 && (
                <div className="p-4 bg-red-50 rounded-lg border border-red-200">
                  <div className="flex items-center gap-2 text-red-700 mb-3">
                    <AlertTriangle className="w-5 h-5" />
                    <h4 className="font-medium">Data Quality Issues ({verificationQuery.issues.length})</h4>
                  </div>
                  <div className="space-y-2">
                    {verificationQuery.issues.map((issue: any, idx: number) => (
                      <div
                        key={idx}
                        className={`p-3 rounded border ${
                          issue.severity === "error"
                            ? "bg-red-100 border-red-300"
                            : issue.severity === "warning"
                            ? "bg-yellow-100 border-yellow-300"
                            : "bg-blue-100 border-blue-300"
                        }`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          {issue.severity === "error" ? (
                            <XCircle className="w-4 h-4 text-red-600" />
                          ) : issue.severity === "warning" ? (
                            <AlertCircle className="w-4 h-4 text-yellow-600" />
                          ) : (
                            <AlertCircle className="w-4 h-4 text-blue-600" />
                          )}
                          <span className="font-medium text-sm">{issue.type.replace(/_/g, " ").toUpperCase()}</span>
                        </div>
                        <p className="text-sm text-gray-700">{issue.message}</p>
                        {issue.dates && issue.dates.length > 0 && (
                          <p className="text-xs text-gray-500 mt-1">
                            Dates: {issue.dates.join(", ")}
                          </p>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Wearable Table Counts */}
              {wearableCountsQuery && (
                <div className="p-4 bg-cyan-50 rounded-lg border border-cyan-200">
                  <h4 className="font-medium text-cyan-800 mb-3">Wearable Data Tables</h4>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                    {Object.entries(wearableCountsQuery.tables || {}).map(([table, count]) => (
                      <div key={table} className="p-2 bg-white rounded border border-cyan-200">
                        <p className="text-xs text-gray-500 truncate">{table.replace("user_", "")}</p>
                        <p className="text-lg font-bold text-cyan-700">{String(count)}</p>
                      </div>
                    ))}
                  </div>
                  <div className="mt-3 flex items-center justify-between">
                    <p className="text-sm text-cyan-700">
                      Total: <strong>{wearableCountsQuery.totalRecords}</strong> records
                    </p>
                    {wearableCountsQuery.totalRecords > 0 && (
                      <button
                        onClick={() => handleClearWearableData(verificationUserId as Id<"users">)}
                        disabled={isLoading}
                        className="px-3 py-1.5 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors text-sm flex items-center gap-1"
                      >
                        {isLoading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Trash2 className="w-3 h-3" />}
                        Clear All Wearable Data
                      </button>
                    )}
                  </div>
                </div>
              )}

              {/* Recommendations */}
              {verificationQuery.recommendations && verificationQuery.recommendations.length > 0 && (
                <div className="p-4 bg-blue-50 rounded-lg border border-blue-200">
                  <h4 className="font-medium text-blue-800 mb-2">Recommendations</h4>
                  <ul className="space-y-1">
                    {verificationQuery.recommendations.map((rec: string, idx: number) => (
                      <li key={idx} className="text-sm text-blue-700 flex items-start gap-2">
                        <span className="mt-1">•</span>
                        <span>{rec}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Mock Sleep Log Simulation */}
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-purple-100 rounded-lg">
              <FileQuestion className="w-5 h-5 text-purple-700" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Mock Sleep Log Simulation</h2>
              <p className="text-sm text-gray-500">Generate simulated questionnaire sleep data for testing</p>
            </div>
          </div>

          {/* Warning Banner */}
          <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg mb-6 flex items-start gap-2">
            <AlertTriangle className="w-5 h-5 text-amber-600 mt-0.5 flex-shrink-0" />
            <div>
              <p className="text-sm text-amber-800 font-medium">Mock Data Notice</p>
              <p className="text-sm text-amber-700">
                Generated data is clearly marked as <span className="font-mono bg-amber-100 px-1 rounded">MOCK DATA</span> and represents <strong>perceived/subjective</strong> sleep only.
                Mock data will NOT contaminate wearable measurements.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Configuration */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Select User</label>
                <select
                  value={mockDataUserId || ""}
                  onChange={(e) => setMockDataUserId(e.target.value || null)}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 outline-none bg-white"
                >
                  <option value="">-- Select a user --</option>
                  {users?.map((user: UserData) => (
                    <option key={user._id} value={user._id}>
                      {user.username} {user.email ? `(${user.email})` : ""} {user.isTestUser ? "[TEST]" : ""}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Sleep Pattern</label>
                <select
                  value={mockDataPattern}
                  onChange={(e) => setMockDataPattern(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 outline-none bg-white"
                >
                  {mockPatterns?.map((pattern: { id: string; name: string; description: string }) => (
                    <option key={pattern.id} value={pattern.id}>
                      {pattern.name}
                    </option>
                  )) || (
                    <>
                      <option value="normal">Normal Sleeper</option>
                      <option value="insomnia">Insomnia Pattern</option>
                      <option value="delayed_phase">Delayed Sleep Phase</option>
                      <option value="irregular">Irregular Sleep</option>
                      <option value="short_sleeper">Short Sleeper</option>
                    </>
                  )}
                </select>
                {mockPatterns && (
                  <p className="text-xs text-gray-500 mt-1">
                    {mockPatterns.find((p: { id: string; description: string }) => p.id === mockDataPattern)?.description}
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Number of Days</label>
                <div className="flex items-center gap-4">
                  <input
                    type="range"
                    min="1"
                    max="30"
                    value={mockDataDays}
                    onChange={(e) => setMockDataDays(Number(e.target.value))}
                    className="flex-1"
                  />
                  <span className="text-lg font-bold text-purple-700 w-12 text-right">{mockDataDays}</span>
                </div>
              </div>

              <button
                onClick={handleGenerateMockData}
                disabled={!mockDataUserId || isGeneratingMock}
                className={`w-full px-4 py-3 rounded-lg font-medium transition-colors flex items-center justify-center gap-2 ${
                  !mockDataUserId || isGeneratingMock
                    ? "bg-gray-200 text-gray-500 cursor-not-allowed"
                    : "bg-purple-600 text-white hover:bg-purple-700"
                }`}
              >
                {isGeneratingMock ? (
                  <Loader2 className="w-5 h-5 animate-spin" />
                ) : (
                  <FileQuestion className="w-5 h-5" />
                )}
                Generate Mock Sleep Data
              </button>
            </div>

            {/* Current Status */}
            <div className="space-y-4">
              {mockDataUserId && mockDataStatus ? (
                <>
                  <div className={`p-4 rounded-lg border ${
                    mockDataStatus.hasMockData
                      ? "bg-purple-50 border-purple-200"
                      : "bg-gray-50 border-gray-200"
                  }`}>
                    <div className="flex items-center justify-between mb-2">
                      <span className="font-medium text-gray-900">Mock Data Status</span>
                      {mockDataStatus.hasMockData && (
                        <span className="px-2 py-1 bg-purple-600 text-white text-xs font-bold rounded">
                          MOCK DATA ACTIVE
                        </span>
                      )}
                    </div>
                    <p className="text-2xl font-bold text-purple-700">{mockDataStatus.mockRecordCount} records</p>
                    {!mockDataStatus.hasMockData && (
                      <p className="text-sm text-gray-500 mt-1">No mock data for this user</p>
                    )}
                  </div>

                  {mockDataStatus.hasMockData && mockDataStatus.batches && (
                    <div className="space-y-2">
                      <h4 className="font-medium text-gray-700">Mock Data Batches</h4>
                      {mockDataStatus.batches.map((batch: any) => (
                        <div
                          key={batch.batchId}
                          className="flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-200"
                        >
                          <div>
                            <p className="font-mono text-xs text-gray-500">{batch.batchId.substring(0, 20)}...</p>
                            <p className="text-sm text-gray-700">
                              {batch.recordCount} records · {batch.dateRange.start} to {batch.dateRange.end}
                            </p>
                          </div>
                          <button
                            onClick={() => handleClearMockData(batch.batchId)}
                            disabled={isGeneratingMock}
                            className="px-3 py-1 bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors text-sm"
                          >
                            Clear
                          </button>
                        </div>
                      ))}

                      <button
                        onClick={() => handleClearMockData()}
                        disabled={isGeneratingMock}
                        className="w-full px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                      >
                        {isGeneratingMock ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <Trash2 className="w-4 h-4" />
                        )}
                        Clear ALL Mock Data
                      </button>
                    </div>
                  )}
                </>
              ) : mockDataUserId ? (
                <div className="p-4 bg-gray-50 rounded-lg flex items-center justify-center">
                  <Loader2 className="w-6 h-6 animate-spin text-gray-400" />
                </div>
              ) : (
                <div className="p-4 bg-gray-50 rounded-lg border border-gray-200 text-center">
                  <FileQuestion className="w-12 h-12 text-gray-300 mx-auto mb-2" />
                  <p className="text-gray-500">Select a user to view mock data status</p>
                </div>
              )}

              {/* Pattern Description */}
              <div className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                <h4 className="font-medium text-gray-900 mb-2">Pattern Preview</h4>
                <div className="text-sm text-gray-600 space-y-1">
                  {mockDataPattern === "normal" && (
                    <>
                      <p><strong>Bed Time:</strong> 10:00 PM - 11:30 PM</p>
                      <p><strong>Wake Time:</strong> 6:00 AM - 7:30 AM</p>
                      <p><strong>Quality:</strong> 7-9/10</p>
                      <p><strong>Efficiency:</strong> 85-95%</p>
                    </>
                  )}
                  {mockDataPattern === "insomnia" && (
                    <>
                      <p><strong>Bed Time:</strong> 10:00 PM - 1:00 AM (variable)</p>
                      <p><strong>Wake Time:</strong> 5:00 AM - 8:00 AM</p>
                      <p><strong>Quality:</strong> 3-5/10</p>
                      <p><strong>Efficiency:</strong> 60-75%</p>
                      <p className="text-amber-600"><strong>Long sleep latency (30-90 min)</strong></p>
                    </>
                  )}
                  {mockDataPattern === "delayed_phase" && (
                    <>
                      <p><strong>Bed Time:</strong> 2:00 AM - 4:00 AM</p>
                      <p><strong>Wake Time:</strong> 10:00 AM - 12:00 PM</p>
                      <p><strong>Quality:</strong> 6-8/10</p>
                      <p><strong>Efficiency:</strong> 80-90%</p>
                    </>
                  )}
                  {mockDataPattern === "irregular" && (
                    <>
                      <p><strong>Bed Time:</strong> Highly variable (9 PM - 3 AM)</p>
                      <p><strong>Wake Time:</strong> Highly variable (5 AM - 11 AM)</p>
                      <p><strong>Quality:</strong> 2-8/10</p>
                      <p><strong>Efficiency:</strong> 50-95%</p>
                    </>
                  )}
                  {mockDataPattern === "short_sleeper" && (
                    <>
                      <p><strong>Bed Time:</strong> 12:00 AM - 1:00 AM</p>
                      <p><strong>Wake Time:</strong> 5:00 AM - 6:00 AM</p>
                      <p><strong>Quality:</strong> 6-8/10</p>
                      <p><strong>Efficiency:</strong> 85-95%</p>
                      <p className="text-amber-600"><strong>Consistently &lt;6 hours sleep</strong></p>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Filters */}
        <div className="flex flex-col sm:flex-row gap-4 mb-6">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by username, email, or name..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-3 rounded-xl border border-gray-200 focus:border-red-500 focus:ring-2 focus:ring-red-500/20 outline-none"
            />
          </div>

          <select
            value={filterRole}
            onChange={(e) => setFilterRole(e.target.value)}
            className="px-4 py-3 rounded-xl border border-gray-200 focus:border-red-500 focus:ring-2 focus:ring-red-500/20 outline-none bg-white"
          >
            <option value="all">All Roles</option>
            <option value="patient">Patients</option>
            <option value="physician">Physicians</option>
            <option value="admin">Admins</option>
          </select>

          <select
            value={filterTestUsers}
            onChange={(e) => setFilterTestUsers(e.target.value as "all" | "test" | "real")}
            className="px-4 py-3 rounded-xl border border-gray-200 focus:border-red-500 focus:ring-2 focus:ring-red-500/20 outline-none bg-white"
          >
            <option value="all">All Users</option>
            <option value="test">Test Users Only</option>
            <option value="real">Real Users Only</option>
          </select>

          <button
            onClick={selectAllFiltered}
            className="px-4 py-3 bg-gray-100 text-gray-700 rounded-xl hover:bg-gray-200 transition-colors whitespace-nowrap"
          >
            Select All ({filteredUsers?.length || 0})
          </button>
        </div>

        {/* User Table */}
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">
              User Management
              {filteredUsers && (
                <span className="ml-2 text-gray-400 font-normal">
                  ({filteredUsers.length})
                </span>
              )}
            </h2>
          </div>

          {!users ? (
            <div className="p-12 text-center">
              <div className="animate-spin w-8 h-8 border-2 border-red-500 border-t-transparent rounded-full mx-auto mb-4" />
              <p className="text-gray-500">Loading users...</p>
            </div>
          ) : filteredUsers?.length === 0 ? (
            <div className="p-12 text-center">
              <Users className="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">No users found</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-100">
              {filteredUsers?.map((user: UserData) => (
                <div key={user._id} className="hover:bg-gray-50">
                  <div className="flex items-center gap-4 p-4">
                    {/* Checkbox */}
                    <input
                      type="checkbox"
                      checked={selectedUsers.has(user._id)}
                      onChange={() => toggleUserSelection(user._id)}
                      className="w-4 h-4 text-red-600 border-gray-300 rounded focus:ring-red-500"
                    />

                    {/* Avatar */}
                    <div
                      className={`w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold ${
                        user.isTestUser
                          ? "bg-gradient-to-br from-purple-400 to-purple-600"
                          : "bg-gradient-to-br from-teal-400 to-blue-500"
                      }`}
                    >
                      {user.username[0].toUpperCase()}
                    </div>

                    {/* User Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-gray-900 truncate">
                          {user.username}
                        </span>
                        {user.isTestUser && (
                          <span className="px-1.5 py-0.5 bg-purple-100 text-purple-700 rounded text-xs font-medium">
                            TEST
                          </span>
                        )}
                        {user.developer_mode && (
                          <span className="px-1.5 py-0.5 bg-amber-100 text-amber-700 rounded text-xs font-medium flex items-center gap-1">
                            <Code className="w-3 h-3" />
                            DEV
                          </span>
                        )}
                        <span
                          className={`px-1.5 py-0.5 rounded text-xs font-medium ${
                            user.role === "admin"
                              ? "bg-red-100 text-red-700"
                              : user.role === "physician"
                              ? "bg-blue-100 text-blue-700"
                              : "bg-gray-100 text-gray-700"
                          }`}
                        >
                          {user.role || "patient"}
                        </span>
                      </div>
                      <p className="text-sm text-gray-500 truncate">
                        {user.email || "No email"} · Day {user.current_day}/10 · {user.responseCount} responses
                      </p>
                    </div>

                    {/* Quick Actions */}
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setShowResetPasswordModal(user._id)}
                        className="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="Reset Password"
                      >
                        <Key className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setShowResetProgressConfirm(user._id)}
                        className="p-2 text-gray-400 hover:text-amber-600 hover:bg-amber-50 rounded-lg transition-colors"
                        title="Reset Progress"
                      >
                        <RotateCcw className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => {
                          setExpandedUser(expandedUser === user._id ? null : user._id);
                        }}
                        className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                        title="More Options"
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setShowDeleteConfirm(user._id)}
                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Delete User"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setExpandedUser(expandedUser === user._id ? null : user._id)}
                        className="p-2 text-gray-400 hover:text-gray-600 transition-colors"
                      >
                        {expandedUser === user._id ? (
                          <ChevronUp className="w-4 h-4" />
                        ) : (
                          <ChevronDown className="w-4 h-4" />
                        )}
                      </button>
                    </div>
                  </div>

                  {/* Expanded Details */}
                  {expandedUser === user._id && (
                    <div className="px-4 pb-4 pl-14">
                      <div className="bg-gray-50 rounded-xl p-4 space-y-4">
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                          <div>
                            <span className="text-gray-500">Created</span>
                            <p className="font-medium">{formatDate(user.created_at)}</p>
                          </div>
                          <div>
                            <span className="text-gray-500">Last Active</span>
                            <p className="font-medium">{formatDate(user.last_accessed)}</p>
                          </div>
                          <div>
                            <span className="text-gray-500">Completed Days</span>
                            <p className="font-medium">{user.completedDays}</p>
                          </div>
                          <div>
                            <span className="text-gray-500">Interventions</span>
                            <p className="font-medium">{user.interventionCount}</p>
                          </div>
                        </div>

                        <div className="flex flex-wrap gap-2 pt-2 border-t border-gray-200">
                          <span className="text-sm text-gray-500 mr-2">Change Role:</span>
                          {(["patient", "physician", "admin"] as const).map((role) => (
                            <button
                              key={role}
                              onClick={() => handleSetRole(user._id, role)}
                              disabled={(user.role || "patient") === role}
                              className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                                (user.role || "patient") === role
                                  ? "bg-gray-300 text-gray-500 cursor-not-allowed"
                                  : role === "admin"
                                  ? "bg-red-100 text-red-700 hover:bg-red-200"
                                  : role === "physician"
                                  ? "bg-blue-100 text-blue-700 hover:bg-blue-200"
                                  : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                              }`}
                            >
                              {role}
                            </button>
                          ))}

                          <span className="text-sm text-gray-500 ml-4 mr-2">Dev Mode:</span>
                          <button
                            onClick={() => handleToggleDevMode(user._id, user.developer_mode || false)}
                            className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                              user.developer_mode
                                ? "bg-amber-100 text-amber-700 hover:bg-amber-200"
                                : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                            }`}
                          >
                            {user.developer_mode ? "Disable" : "Enable"}
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Delete Single User Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-red-600 mb-4">
              <AlertTriangle className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Delete User</h3>
            </div>
            <p className="text-gray-600 mb-6">
              Are you sure you want to permanently delete this user and ALL their data? This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowDeleteConfirm(null)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={() => showDeleteConfirm && handleDeleteUser(showDeleteConfirm as Id<"users">)}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                Delete Forever
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bulk Delete Confirmation Modal */}
      {showBulkDeleteConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-red-600 mb-4">
              <AlertTriangle className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Delete {selectedUsers.size} Users</h3>
            </div>
            <p className="text-gray-600 mb-6">
              Are you sure you want to permanently delete {selectedUsers.size} users and ALL their data? This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowBulkDeleteConfirm(false)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={handleBulkDelete}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                Delete All
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Purge Test Users (user1-10) Confirmation Modal */}
      {showPurgeTestConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-orange-600 mb-4">
              <UserX className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Purge user1-user10</h3>
            </div>
            <p className="text-gray-600 mb-2">
              This will permanently delete all users matching the pattern <code className="bg-gray-100 px-1 rounded">user1</code> through <code className="bg-gray-100 px-1 rounded">user10</code> (and similar variations like <code className="bg-gray-100 px-1 rounded">user123</code>).
            </p>
            <p className="text-gray-600 mb-6">
              All associated data will be permanently removed. This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowPurgeTestConfirm(false)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={handlePurgeTestUsers}
                className="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserX className="w-4 h-4" />}
                Purge user1-10
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Purge Generated Test Users (test_*) Confirmation Modal */}
      {showPurgeGeneratedConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-purple-600 mb-4">
              <UserX className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Purge Generated Test Users</h3>
            </div>
            <p className="text-gray-600 mb-2">
              This will permanently delete all users with usernames starting with <code className="bg-gray-100 px-1 rounded">test_</code> (e.g., <code className="bg-gray-100 px-1 rounded">test_short_sleeper_mild_022</code>).
            </p>
            <p className="text-gray-600 mb-6">
              All associated data will be permanently removed. This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowPurgeGeneratedConfirm(false)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={handlePurgeGeneratedTestUsers}
                className="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserX className="w-4 h-4" />}
                Purge test_* Users
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Purge ALL Test Users Confirmation Modal */}
      {showPurgeAllConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-red-600 mb-4">
              <UserX className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Purge ALL Test Users</h3>
            </div>
            <p className="text-gray-600 mb-2">
              This will permanently delete ALL test users including:
            </p>
            <ul className="text-gray-600 mb-4 list-disc list-inside">
              <li><code className="bg-gray-100 px-1 rounded">user1</code> through <code className="bg-gray-100 px-1 rounded">user10</code> (and variations)</li>
              <li>All <code className="bg-gray-100 px-1 rounded">test_*</code> generated mock users</li>
            </ul>
            <p className="text-gray-600 mb-6 font-medium text-red-600">
              This action cannot be undone!
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowPurgeAllConfirm(false)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={handlePurgeAllTestUsers}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserX className="w-4 h-4" />}
                Purge ALL Test Users
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reset Password Modal */}
      {showResetPasswordModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-blue-600 mb-4">
              <Key className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Reset Password</h3>
            </div>
            <div className="space-y-4 mb-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">New Password</label>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none"
                  placeholder="Enter new password"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none"
                  placeholder="Confirm new password"
                />
              </div>
              {newPassword && confirmPassword && newPassword !== confirmPassword && (
                <p className="text-sm text-red-600">Passwords do not match</p>
              )}
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowResetPasswordModal(null);
                  setNewPassword("");
                  setConfirmPassword("");
                }}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={() => handleResetPassword(showResetPasswordModal as Id<"users">)}
                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading || newPassword !== confirmPassword || !newPassword}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Key className="w-4 h-4" />}
                Reset Password
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reset Progress Confirmation Modal */}
      {showResetProgressConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-amber-600 mb-4">
              <RotateCcw className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Reset User Progress</h3>
            </div>
            <p className="text-gray-600 mb-4">
              This will delete all questionnaire responses, insights, and progress for this user. The user account will remain intact but reset to Day 1.
            </p>

            {/* Wearable Data Toggle */}
            <div className="p-4 bg-gray-50 rounded-lg border border-gray-200 mb-6">
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={resetIncludeWearables}
                  onChange={(e) => setResetIncludeWearables(e.target.checked)}
                  className="w-5 h-5 mt-0.5 text-red-600 border-gray-300 rounded focus:ring-red-500"
                />
                <div>
                  <span className="font-medium text-gray-900 flex items-center gap-2">
                    <Watch className="w-4 h-4" />
                    Also clear wearable data
                  </span>
                  <p className="text-sm text-gray-500 mt-1">
                    Include HealthKit/Apple Watch data (sleep stages, heart rate, activity, etc.)
                  </p>
                </div>
              </label>

              {resetIncludeWearables && (
                <div className="mt-3 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-700">
                  <strong>Warning:</strong> This will permanently delete all synced wearable data including sleep stages, heart rate, activity metrics, and circadian data.
                </div>
              )}
            </div>

            <p className="text-sm text-gray-500 mb-4">
              This action cannot be undone.
            </p>

            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowResetProgressConfirm(null);
                  setResetIncludeWearables(false);
                }}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={() => handleResetProgress(showResetProgressConfirm as Id<"users">, resetIncludeWearables)}
                className={`flex-1 px-4 py-2 text-white rounded-lg transition-colors flex items-center justify-center gap-2 ${
                  resetIncludeWearables
                    ? "bg-red-600 hover:bg-red-700"
                    : "bg-amber-600 hover:bg-amber-700"
                }`}
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <RotateCcw className="w-4 h-4" />}
                Reset {resetIncludeWearables ? "All Data" : "Progress"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Complete Reset Confirmation Modal */}
      {showCompleteResetConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 text-red-600 mb-4">
              <AlertTriangle className="w-6 h-6" />
              <h3 className="text-lg font-semibold">Complete User Reset</h3>
            </div>
            <p className="text-gray-600 mb-4">
              This will perform a <strong className="text-red-600">COMPLETE RESET</strong> of all user data:
            </p>
            <ul className="text-sm text-gray-600 mb-4 list-disc list-inside space-y-1">
              <li>All questionnaire responses and assessment data</li>
              <li>All wearable/HealthKit data (sleep, HR, activity)</li>
              <li>All insights, scores, and analytics</li>
              <li>All interventions and progress tracking</li>
              <li>All gamification data (XP, badges, streaks)</li>
            </ul>
            <p className="text-red-600 font-medium mb-6">
              This action is IRREVERSIBLE. The user will be reset to a completely fresh state.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowCompleteResetConfirm(null)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={() => handleCompleteReset(showCompleteResetConfirm as Id<"users">)}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                Complete Reset
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
