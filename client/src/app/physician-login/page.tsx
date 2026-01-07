"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Lock, Eye, EyeOff, Shield, AlertCircle } from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";
import ZoeLogoFull from "@/components/ZoeLogoFull";

// SHA256 hash function for browser
async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default function PhysicianLoginPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSetupMode, setIsSetupMode] = useState(false);

  // Queries
  const hasMasterPassword = useQuery(api.physicianAuth.hasMasterPassword);
  const validateSession = useQuery(
    api.physicianAuth.validatePhysicianSession,
    typeof window !== "undefined" && localStorage.getItem("physician_session")
      ? { sessionToken: localStorage.getItem("physician_session") || "" }
      : "skip"
  );

  // Mutations
  const setMasterPassword = useMutation(api.physicianAuth.setMasterPassword);
  const verifyMasterPassword = useMutation(api.physicianAuth.verifyMasterPassword);

  // Check for existing valid session
  useEffect(() => {
    if (validateSession?.valid) {
      router.push("/physician-dashboard");
    }
  }, [validateSession, router]);

  // Set setup mode based on whether password exists
  useEffect(() => {
    if (hasMasterPassword === false) {
      setIsSetupMode(true);
    }
  }, [hasMasterPassword]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      if (isSetupMode) {
        // Setting up new master password
        if (password.length < 8) {
          setError("Password must be at least 8 characters long");
          setIsLoading(false);
          return;
        }
        if (password !== confirmPassword) {
          setError("Passwords do not match");
          setIsLoading(false);
          return;
        }

        const passwordHash = await sha256(password);
        const result = await setMasterPassword({ passwordHash });

        if (!result.success) {
          setError(result.error || "Failed to set master password");
          setIsLoading(false);
          return;
        }

        // Now login with the new password
        const loginResult = await verifyMasterPassword({
          passwordHash,
          userAgent: navigator.userAgent,
        });

        if (loginResult.success && loginResult.sessionToken) {
          localStorage.setItem("physician_session", loginResult.sessionToken);
          router.push("/physician-dashboard");
        } else {
          setError(loginResult.error || "Failed to login after setup");
        }
      } else {
        // Regular login
        const passwordHash = await sha256(password);
        const result = await verifyMasterPassword({
          passwordHash,
          userAgent: navigator.userAgent,
        });

        if (result.success && result.sessionToken) {
          localStorage.setItem("physician_session", result.sessionToken);
          router.push("/physician-dashboard");
        } else {
          setError(result.error || "Invalid password");
        }
      }
    } catch (err) {
      console.error("Login error:", err);
      setError("An unexpected error occurred");
    } finally {
      setIsLoading(false);
    }
  };

  // Loading state while checking for existing password
  if (hasMasterPassword === undefined) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center px-6 py-4 rounded-2xl bg-white/95 backdrop-blur mb-4">
            <ZoeLogoFull height={48} />
          </div>
          <p className="text-slate-300 mt-3 text-sm">Physician Dashboard</p>
        </div>

        {/* Login Card */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-full bg-teal-100 flex items-center justify-center">
              <Shield className="w-5 h-5 text-teal-600" />
            </div>
            <div>
              <h2 className="text-xl font-semibold text-gray-900">
                {isSetupMode ? "Create Master Password" : "Physician Access"}
              </h2>
              <p className="text-sm text-gray-500">
                {isSetupMode
                  ? "Set up your secure master password"
                  : "Enter the master password to continue"}
              </p>
            </div>
          </div>

          {isSetupMode && (
            <div className="mb-6 p-4 bg-amber-50 border border-amber-200 rounded-xl">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-medium text-amber-800">First-Time Setup</p>
                  <p className="text-sm text-amber-700 mt-1">
                    This is the first time accessing the physician dashboard. Please create a
                    secure master password that will be used by all physicians to access patient data.
                  </p>
                </div>
              </div>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Password Field */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                {isSetupMode ? "Create Password" : "Master Password"}
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="block w-full pl-10 pr-10 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 outline-none"
                  placeholder={isSetupMode ? "Create a secure password" : "Enter master password"}
                  required
                  minLength={isSetupMode ? 8 : 1}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                >
                  {showPassword ? (
                    <EyeOff className="h-5 w-5" />
                  ) : (
                    <Eye className="h-5 w-5" />
                  )}
                </button>
              </div>
            </div>

            {/* Confirm Password Field (Setup Mode Only) */}
            {isSetupMode && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Confirm Password
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Lock className="h-5 w-5 text-gray-400" />
                  </div>
                  <input
                    type={showPassword ? "text" : "password"}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 outline-none"
                    placeholder="Confirm your password"
                    required
                  />
                </div>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-xl">
                <p className="text-sm text-red-600 flex items-center gap-2">
                  <AlertCircle className="w-4 h-4" />
                  {error}
                </p>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3 px-4 bg-gradient-to-r from-teal-600 to-blue-600 text-white font-medium rounded-xl hover:from-teal-700 hover:to-blue-700 focus:outline-none focus:ring-2 focus:ring-teal-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
              {isLoading ? (
                <div className="flex items-center justify-center gap-2">
                  <div className="animate-spin w-5 h-5 border-2 border-white border-t-transparent rounded-full" />
                  {isSetupMode ? "Setting up..." : "Verifying..."}
                </div>
              ) : isSetupMode ? (
                "Create Password & Continue"
              ) : (
                "Access Dashboard"
              )}
            </button>
          </form>

          {/* Footer */}
          <p className="mt-6 text-center text-xs text-gray-500">
            This dashboard provides access to patient health data.
            <br />
            Authorized personnel only.
          </p>
        </div>
      </div>
    </div>
  );
}
