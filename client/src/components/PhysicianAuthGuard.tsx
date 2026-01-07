"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { useRouter } from "next/navigation";
import { useEffect, useState, createContext, useContext } from "react";
import { useUser } from "@clerk/nextjs";
import { LogOut } from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

interface PhysicianAuthGuardProps {
  children: React.ReactNode;
}

export default function PhysicianAuthGuard({ children }: PhysicianAuthGuardProps) {
  const router = useRouter();
  const { user, isSignedIn } = useUser();
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [sessionType, setSessionType] = useState<"master" | "clerk" | null>(null);
  const [isClient, setIsClient] = useState(false);

  const createClerkSession = useMutation(api.physicianAuth.createClerkPhysicianSession);

  // Client-side only initialization
  useEffect(() => {
    setIsClient(true);
  }, []);

  // Check for existing session or create Clerk session
  useEffect(() => {
    if (!isClient) return;

    // 1. Check for master password session
    const masterToken = localStorage.getItem("physician_session");
    if (masterToken) {
      setSessionToken(masterToken);
      setSessionType("master");
      return;
    }

    // 2. Check Clerk session
    if (isSignedIn && user) {
      handleClerkSession();
    } else if (isSignedIn === false) {
      // User is not signed in with Clerk and no master password
      router.push("/physician-login");
    }
  }, [isClient, isSignedIn, user]);

  const handleClerkSession = async () => {
    if (!user) return;

    try {
      // Create or get existing Clerk physician session
      const session = await createClerkSession({
        clerkUserId: user.id,
        clerkSessionId: user.id,
      });

      localStorage.setItem("physician_session", session.sessionToken);
      setSessionToken(session.sessionToken);
      setSessionType("clerk");
    } catch (error) {
      console.error("Failed to create Clerk session:", error);
      // User might not have accepted invitation yet
      router.push("/physician-login");
    }
  };

  // Validate session with Convex
  const validateResult = useQuery(
    api.physicianAuth.validatePhysicianSession,
    sessionToken ? { sessionToken } : "skip"
  );

  const logout = useMutation(api.physicianAuth.logout);

  // Handle validation result
  useEffect(() => {
    if (!isClient || !sessionToken) return;

    if (validateResult && !validateResult.valid) {
      localStorage.removeItem("physician_session");
      router.push("/physician-login");
    }
  }, [validateResult, sessionToken, isClient, router]);

  const handleLogout = async () => {
    if (sessionToken) {
      await logout({ sessionToken });
      localStorage.removeItem("physician_session");
      router.push("/physician-login");
    }
  };

  // Loading state
  if (!isClient || !sessionToken || validateResult === undefined) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-xl mb-4">
            <ZoeLogo size={48} />
          </div>
          <div className="animate-spin w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full mx-auto" />
          <p className="text-gray-500 mt-4">Verifying access...</p>
        </div>
      </div>
    );
  }

  // Invalid session
  if (!validateResult.valid) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500">Redirecting to login...</p>
        </div>
      </div>
    );
  }

  // Valid session - render with context
  return (
    <PhysicianAuthContext.Provider value={{
      handleLogout,
      sessionType,
      isMasterSession: sessionType === "master",
    }}>
      {children}
    </PhysicianAuthContext.Provider>
  );
}

// Context
interface PhysicianAuthContextType {
  handleLogout: () => void;
  sessionType: "master" | "clerk" | null;
  isMasterSession: boolean;
}

const PhysicianAuthContext = createContext<PhysicianAuthContextType>({
  handleLogout: () => {},
  sessionType: null,
  isMasterSession: false,
});

export function usePhysicianAuth() {
  return useContext(PhysicianAuthContext);
}

// Legacy export for backward compatibility
export function usePhysicianLogout() {
  const { handleLogout } = usePhysicianAuth();
  return { handleLogout };
}

// Standalone logout button component
export function PhysicianLogoutButton() {
  const { handleLogout } = usePhysicianAuth();

  return (
    <button
      onClick={handleLogout}
      className="flex items-center gap-2 px-3 py-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
      title="Logout"
    >
      <LogOut className="w-5 h-5" />
      <span className="hidden sm:inline">Logout</span>
    </button>
  );
}
