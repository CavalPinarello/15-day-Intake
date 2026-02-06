"use client";

interface ModelOption {
  id: string;
  name: string;
  provider: string;
}

import Link from "next/link";
import { useState, useEffect } from "react";
import { useMutation, useQuery, useAction } from "convex/react";
import { api } from "@/convex/_generated/api";
import { PhysicianLogoutButton } from "@/components/PhysicianAuthGuard";
import {
  Users,
  ClipboardList,
  Settings,
  User,
  Bell,
  Shield,
  Palette,
  Lock,
  CheckCircle,
  AlertCircle,
  Bot,
  Key,
  RefreshCw,
  Eye,
  EyeOff,
} from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";
import { ProfilePictureUpload } from "@/components/ui/ProfilePictureUpload";

// SHA256 hash function for browser
async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default function PhysicianSettingsPage() {
  // Password change state
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [passwordMessage, setPasswordMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  // AI Configuration state
  const [anthropicKey, setAnthropicKey] = useState("");
  const [openaiKey, setOpenaiKey] = useState("");
  const [showAnthropicKey, setShowAnthropicKey] = useState(false);
  const [showOpenaiKey, setShowOpenaiKey] = useState(false);
  const [isTestingAnthropic, setIsTestingAnthropic] = useState(false);
  const [isTestingOpenai, setIsTestingOpenai] = useState(false);
  const [isSavingAnthropic, setIsSavingAnthropic] = useState(false);
  const [isSavingOpenai, setIsSavingOpenai] = useState(false);
  const [aiMessage, setAiMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  // Get session token from localStorage (client-side only)
  const [sessionToken, setSessionToken] = useState<string | null>(null);

  // Initialize session token on mount
  useEffect(() => {
    if (typeof window !== "undefined") {
      setSessionToken(localStorage.getItem("physician_session"));
    }
  }, []);

  // Queries and mutations
  const currentPhysician = useQuery(
    api.physicianAuth.getCurrentPhysician,
    sessionToken ? { sessionToken } : "skip"
  );
  const changeMasterPassword = useMutation(api.physicianAuth.changeMasterPassword);
  const llmSettings = useQuery(api.systemSettings.getLLMSettings);
  const modelOptions = useQuery(api.systemSettings.getModelOptions);
  const setPrimaryModel = useMutation(api.systemSettings.setPrimaryModel);
  const setFallbackModel = useMutation(api.systemSettings.setFallbackModel);
  const setAnthropicKeyMutation = useMutation(api.systemSettings.setAnthropicKey);
  const setOpenAIKeyMutation = useMutation(api.systemSettings.setOpenAIKey);
  const toggleFallback = useMutation(api.systemSettings.toggleFallback);
  const testAnthropicKey = useAction(api.systemSettings.testAnthropicKey);
  const testOpenAIKey = useAction(api.systemSettings.testOpenAIKey);

  // Handle API key save
  const handleSaveAnthropicKey = async () => {
    if (!anthropicKey.trim()) return;
    setIsSavingAnthropic(true);
    setAiMessage(null);
    try {
      await setAnthropicKeyMutation({ apiKey: anthropicKey });
      setAiMessage({ type: "success", text: "Anthropic API key saved successfully" });
      setAnthropicKey("");
    } catch {
      setAiMessage({ type: "error", text: "Failed to save Anthropic API key" });
    } finally {
      setIsSavingAnthropic(false);
    }
  };

  const handleSaveOpenAIKey = async () => {
    if (!openaiKey.trim()) return;
    setIsSavingOpenai(true);
    setAiMessage(null);
    try {
      await setOpenAIKeyMutation({ apiKey: openaiKey });
      setAiMessage({ type: "success", text: "OpenAI API key saved successfully" });
      setOpenaiKey("");
    } catch {
      setAiMessage({ type: "error", text: "Failed to save OpenAI API key" });
    } finally {
      setIsSavingOpenai(false);
    }
  };

  // Handle API key test
  const handleTestAnthropicKey = async () => {
    const keyToTest = anthropicKey.trim() || llmSettings?.settings?.llm_anthropic_key;
    if (!keyToTest) {
      setAiMessage({ type: "error", text: "No Anthropic API key to test" });
      return;
    }
    setIsTestingAnthropic(true);
    setAiMessage(null);
    try {
      // Use the new key if entered, otherwise we can't test the stored one (it's masked)
      if (!anthropicKey.trim()) {
        setAiMessage({ type: "error", text: "Enter a new key to test, or the stored key is masked" });
        return;
      }
      const result = await testAnthropicKey({ apiKey: anthropicKey });
      setAiMessage({
        type: result.success ? "success" : "error",
        text: result.message,
      });
    } catch {
      setAiMessage({ type: "error", text: "Failed to test API key" });
    } finally {
      setIsTestingAnthropic(false);
    }
  };

  const handleTestOpenAIKey = async () => {
    if (!openaiKey.trim()) {
      setAiMessage({ type: "error", text: "Enter a key to test" });
      return;
    }
    setIsTestingOpenai(true);
    setAiMessage(null);
    try {
      const result = await testOpenAIKey({ apiKey: openaiKey });
      setAiMessage({
        type: result.success ? "success" : "error",
        text: result.message,
      });
    } catch {
      setAiMessage({ type: "error", text: "Failed to test API key" });
    } finally {
      setIsTestingOpenai(false);
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordMessage(null);

    if (newPassword.length < 8) {
      setPasswordMessage({
        type: "error",
        text: "New password must be at least 8 characters long",
      });
      return;
    }

    if (newPassword !== confirmNewPassword) {
      setPasswordMessage({
        type: "error",
        text: "New passwords do not match",
      });
      return;
    }

    setIsChangingPassword(true);

    try {
      const currentHash = await sha256(currentPassword);
      const newHash = await sha256(newPassword);

      const result = await changeMasterPassword({
        currentPasswordHash: currentHash,
        newPasswordHash: newHash,
      });

      if (result.success) {
        setPasswordMessage({
          type: "success",
          text: "Password changed successfully. You will need to login again.",
        });
        setCurrentPassword("");
        setNewPassword("");
        setConfirmNewPassword("");
        // Clear session and redirect to login after a short delay
        setTimeout(() => {
          localStorage.removeItem("physician_session");
          window.location.href = "/physician-login";
        }, 2000);
      } else {
        setPasswordMessage({
          type: "error",
          text: result.error || "Failed to change password",
        });
      }
    } catch (err) {
      console.error("Password change error:", err);
      setPasswordMessage({
        type: "error",
        text: "An unexpected error occurred",
      });
    } finally {
      setIsChangingPassword(false);
    }
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
                className="flex items-center gap-2 text-teal-600 font-medium"
              >
                <Settings className="w-5 h-5" />
                Settings
              </Link>
              <PhysicianLogoutButton />
            </nav>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-gray-900">Settings</h2>
          <p className="text-gray-600 mt-1">
            Manage your account and preferences
          </p>
        </div>

        {/* Profile Section */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
          <div className="flex items-center gap-2 mb-6">
            <User className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">Profile</h3>
          </div>

          <div className="flex items-center gap-6">
            {currentPhysician ? (
              <>
                <ProfilePictureUpload
                  currentImageUrl={currentPhysician.avatarUrl}
                  name={currentPhysician.fullName}
                  size="xl"
                  entityType="physician"
                  entityId={currentPhysician.id}
                />
                <div>
                  <h4 className="text-xl font-semibold text-gray-900">
                    {currentPhysician.fullName}
                  </h4>
                  <p className="text-gray-500">{currentPhysician.email}</p>
                  <div className="flex items-center gap-2 mt-2">
                    <span className="px-3 py-1 bg-teal-100 text-teal-700 rounded-full text-sm font-medium">
                      {currentPhysician.permissionLevel === "admin" ? "Admin" :
                       currentPhysician.permissionLevel === "clinician" ? "Clinician" : "Viewer"}
                    </span>
                    {currentPhysician.specialization && (
                      <span className="text-sm text-gray-500">
                        {currentPhysician.specialization}
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-gray-400 mt-2">
                    Click photo to update profile picture
                  </p>
                </div>
              </>
            ) : (
              <>
                <div className="w-20 h-20 rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-bold text-2xl">
                  P
                </div>
                <div>
                  <h4 className="text-xl font-semibold text-gray-900">
                    Physician Access
                  </h4>
                  <p className="text-gray-500">Shared master password authentication</p>
                  <span className="inline-block mt-2 px-3 py-1 bg-teal-100 text-teal-700 rounded-full text-sm font-medium">
                    Physician
                  </span>
                </div>
              </>
            )}
          </div>
        </div>

        {/* Notifications Section */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
          <div className="flex items-center gap-2 mb-6">
            <Bell className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">Notifications</h3>
          </div>

          <div className="space-y-4">
            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="font-medium text-gray-900">New Patient Alerts</p>
                <p className="text-sm text-gray-500">
                  Get notified when a new patient completes their intake
                </p>
              </div>
              <input
                type="checkbox"
                defaultChecked
                className="w-5 h-5 text-teal-600 rounded focus:ring-teal-500"
              />
            </label>

            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="font-medium text-gray-900">Review Reminders</p>
                <p className="text-sm text-gray-500">
                  Receive reminders for patients pending review
                </p>
              </div>
              <input
                type="checkbox"
                defaultChecked
                className="w-5 h-5 text-teal-600 rounded focus:ring-teal-500"
              />
            </label>

            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="font-medium text-gray-900">Email Summaries</p>
                <p className="text-sm text-gray-500">
                  Receive weekly email summaries of patient activity
                </p>
              </div>
              <input
                type="checkbox"
                className="w-5 h-5 text-teal-600 rounded focus:ring-teal-500"
              />
            </label>
          </div>
        </div>

        {/* Appearance Section */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
          <div className="flex items-center gap-2 mb-6">
            <Palette className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">Appearance</h3>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Theme
              </label>
              <select className="w-full md:w-64 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500">
                <option value="light">Light</option>
                <option value="dark">Dark</option>
                <option value="system">System</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Default View
              </label>
              <select className="w-full md:w-64 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500">
                <option value="patients">Patient List</option>
                <option value="pending">Pending Review</option>
                <option value="questions">Question Manager</option>
              </select>
            </div>
          </div>
        </div>

        {/* AI Configuration Section */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
          <div className="flex items-center gap-2 mb-6">
            <Bot className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">AI Analysis Configuration</h3>
          </div>

          <div className="space-y-6">
            {/* Model Selection */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Primary Model
                </label>
                <select
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                  value={llmSettings?.primaryModel || "claude-sonnet-4-20250514"}
                  onChange={(e) => setPrimaryModel({ modelId: e.target.value })}
                >
                  <optgroup label="Anthropic (Claude)">
                    {modelOptions?.anthropic.map((model: ModelOption) => (
                      <option key={model.id} value={model.id}>
                        {model.name}
                      </option>
                    ))}
                  </optgroup>
                  <optgroup label="OpenAI (GPT)">
                    {modelOptions?.openai.map((model: ModelOption) => (
                      <option key={model.id} value={model.id}>
                        {model.name}
                      </option>
                    ))}
                  </optgroup>
                </select>
                <p className="text-xs text-gray-500 mt-1">Used for patient analysis</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Fallback Model
                </label>
                <select
                  className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                  value={llmSettings?.fallbackModel || "gpt-4o"}
                  onChange={(e) => setFallbackModel({ modelId: e.target.value })}
                >
                  <optgroup label="OpenAI (GPT)">
                    {modelOptions?.openai.map((model: ModelOption) => (
                      <option key={model.id} value={model.id}>
                        {model.name}
                      </option>
                    ))}
                  </optgroup>
                  <optgroup label="Anthropic (Claude)">
                    {modelOptions?.anthropic.map((model: ModelOption) => (
                      <option key={model.id} value={model.id}>
                        {model.name}
                      </option>
                    ))}
                  </optgroup>
                </select>
                <p className="text-xs text-gray-500 mt-1">Used if primary fails</p>
              </div>
            </div>

            {/* Fallback Toggle */}
            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="font-medium text-gray-900">Enable Fallback</p>
                <p className="text-sm text-gray-500">
                  Automatically try fallback model if primary fails
                </p>
              </div>
              <input
                type="checkbox"
                checked={llmSettings?.enableFallback ?? true}
                onChange={(e) => toggleFallback({ enabled: e.target.checked })}
                className="w-5 h-5 text-teal-600 rounded focus:ring-teal-500"
              />
            </label>

            {/* API Keys Section */}
            <div className="border-t border-gray-200 pt-6">
              <div className="flex items-center gap-2 mb-4">
                <Key className="w-4 h-4 text-gray-500" />
                <h4 className="font-medium text-gray-900">API Keys</h4>
              </div>
              <p className="text-sm text-gray-500 mb-4">
                Enter your API keys. Keys are stored encrypted and override environment variables.
              </p>

              {/* Status indicators */}
              <div className="flex gap-4 mb-4">
                <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-sm ${
                  llmSettings?.hasAnthropicKey
                    ? "bg-green-100 text-green-700"
                    : "bg-gray-100 text-gray-500"
                }`}>
                  {llmSettings?.hasAnthropicKey ? (
                    <CheckCircle className="w-4 h-4" />
                  ) : (
                    <AlertCircle className="w-4 h-4" />
                  )}
                  Anthropic: {llmSettings?.hasAnthropicKey ? "Configured" : "Not set"}
                </div>
                <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-sm ${
                  llmSettings?.hasOpenAIKey
                    ? "bg-green-100 text-green-700"
                    : "bg-gray-100 text-gray-500"
                }`}>
                  {llmSettings?.hasOpenAIKey ? (
                    <CheckCircle className="w-4 h-4" />
                  ) : (
                    <AlertCircle className="w-4 h-4" />
                  )}
                  OpenAI: {llmSettings?.hasOpenAIKey ? "Configured" : "Not set"}
                </div>
              </div>

              {/* Anthropic API Key */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Anthropic API Key
                </label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <input
                      type={showAnthropicKey ? "text" : "password"}
                      value={anthropicKey}
                      onChange={(e) => setAnthropicKey(e.target.value)}
                      placeholder={llmSettings?.hasAnthropicKey ? "••••••••••••" : "sk-ant-..."}
                      className="w-full px-4 py-2 pr-10 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowAnthropicKey(!showAnthropicKey)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showAnthropicKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                  <button
                    onClick={handleTestAnthropicKey}
                    disabled={isTestingAnthropic || !anthropicKey.trim()}
                    className="px-3 py-2 border border-gray-200 rounded-lg text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  >
                    {isTestingAnthropic ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      "Test"
                    )}
                  </button>
                  <button
                    onClick={handleSaveAnthropicKey}
                    disabled={isSavingAnthropic || !anthropicKey.trim()}
                    className="px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isSavingAnthropic ? "Saving..." : "Save"}
                  </button>
                </div>
              </div>

              {/* OpenAI API Key */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  OpenAI API Key
                </label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <input
                      type={showOpenaiKey ? "text" : "password"}
                      value={openaiKey}
                      onChange={(e) => setOpenaiKey(e.target.value)}
                      placeholder={llmSettings?.hasOpenAIKey ? "••••••••••••" : "sk-..."}
                      className="w-full px-4 py-2 pr-10 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowOpenaiKey(!showOpenaiKey)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showOpenaiKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                  <button
                    onClick={handleTestOpenAIKey}
                    disabled={isTestingOpenai || !openaiKey.trim()}
                    className="px-3 py-2 border border-gray-200 rounded-lg text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  >
                    {isTestingOpenai ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      "Test"
                    )}
                  </button>
                  <button
                    onClick={handleSaveOpenAIKey}
                    disabled={isSavingOpenai || !openaiKey.trim()}
                    className="px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isSavingOpenai ? "Saving..." : "Save"}
                  </button>
                </div>
              </div>

              {/* Message display */}
              {aiMessage && (
                <div
                  className={`p-3 rounded-lg flex items-center gap-2 ${
                    aiMessage.type === "success"
                      ? "bg-green-50 text-green-700 border border-green-200"
                      : "bg-red-50 text-red-700 border border-red-200"
                  }`}
                >
                  {aiMessage.type === "success" ? (
                    <CheckCircle className="w-4 h-4" />
                  ) : (
                    <AlertCircle className="w-4 h-4" />
                  )}
                  {aiMessage.text}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Security Section - Master Password Change */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6">
          <div className="flex items-center gap-2 mb-6">
            <Shield className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">Security</h3>
          </div>

          <div className="space-y-6">
            {/* Change Master Password */}
            <div>
              <div className="flex items-center gap-2 mb-4">
                <Lock className="w-4 h-4 text-gray-500" />
                <h4 className="font-medium text-gray-900">Change Master Password</h4>
              </div>
              <p className="text-sm text-gray-500 mb-4">
                This will change the master password for all physicians. All active sessions will be invalidated.
              </p>

              <form onSubmit={handleChangePassword} className="space-y-4 max-w-md">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Current Password
                  </label>
                  <input
                    type="password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    New Password
                  </label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                    minLength={8}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Confirm New Password
                  </label>
                  <input
                    type="password"
                    value={confirmNewPassword}
                    onChange={(e) => setConfirmNewPassword(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
                    required
                  />
                </div>

                {passwordMessage && (
                  <div
                    className={`p-3 rounded-lg flex items-center gap-2 ${
                      passwordMessage.type === "success"
                        ? "bg-green-50 text-green-700 border border-green-200"
                        : "bg-red-50 text-red-700 border border-red-200"
                    }`}
                  >
                    {passwordMessage.type === "success" ? (
                      <CheckCircle className="w-4 h-4" />
                    ) : (
                      <AlertCircle className="w-4 h-4" />
                    )}
                    {passwordMessage.text}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isChangingPassword}
                  className="px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isChangingPassword ? "Changing..." : "Change Password"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
