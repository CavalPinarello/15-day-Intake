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
  RefreshCw,
  Key,
  Download,
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
  const updateUserField = useMutation(api.admin.updateUserField);
  const setUserRole = useMutation(api.admin.setUserRole);

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

  const handleResetProgress = async (userId: Id<"users">) => {
    setIsLoading(true);
    try {
      const result = await resetUserProgress({ userId });
      if (result.success) {
        setOperationResult({
          type: "success",
          message: `Reset progress for "${result.username}". ${result.deletedRecords} records deleted, reset to Day ${result.resetToDay}.`,
        });
        setShowResetProgressConfirm(null);
      } else {
        setOperationResult({ type: "error", message: result.error || "Failed to reset progress" });
      }
    } catch (error) {
      setOperationResult({ type: "error", message: String(error) });
    }
    setIsLoading(false);
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
                        {user.email || "No email"} · Day {user.current_day}/14 · {user.responseCount} responses
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
            <p className="text-gray-600 mb-6">
              This will delete all questionnaire responses, sleep data, insights, and progress for this user. The user account will remain intact but reset to Day 1. This action cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowResetProgressConfirm(null)}
                className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                disabled={isLoading}
              >
                Cancel
              </button>
              <button
                onClick={() => handleResetProgress(showResetProgressConfirm as Id<"users">)}
                className="flex-1 px-4 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors flex items-center justify-center gap-2"
                disabled={isLoading}
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <RotateCcw className="w-4 h-4" />}
                Reset Progress
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
