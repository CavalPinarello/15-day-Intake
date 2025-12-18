"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { LogOut } from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

interface PhysicianAuthGuardProps {
  children: React.ReactNode;
}

export default function PhysicianAuthGuard({ children }: PhysicianAuthGuardProps) {
  const router = useRouter();
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [isClient, setIsClient] = useState(false);

  // Only run on client side
  useEffect(() => {
    setIsClient(true);
    const token = localStorage.getItem("physician_session");
    setSessionToken(token);
  }, []);

  // Validate session with Convex
  const validateResult = useQuery(
    api.physicianAuth.validatePhysicianSession,
    sessionToken ? { sessionToken } : "skip"
  );

  const logout = useMutation(api.physicianAuth.logout);

  // Redirect to login if no session or invalid session
  useEffect(() => {
    if (!isClient) return;

    // No token - redirect to login
    if (!sessionToken) {
      router.push("/physician-login");
      return;
    }

    // Session validation returned invalid
    if (validateResult && !validateResult.valid) {
      localStorage.removeItem("physician_session");
      router.push("/physician-login");
    }
  }, [isClient, sessionToken, validateResult, router]);

  const handleLogout = async () => {
    if (sessionToken) {
      await logout({ sessionToken });
      localStorage.removeItem("physician_session");
      router.push("/physician-login");
    }
  };

  // Show loading while checking auth
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

  // Invalid session - will redirect
  if (!validateResult.valid) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500">Redirecting to login...</p>
        </div>
      </div>
    );
  }

  // Valid session - render children with logout option available via context or prop
  return (
    <>
      {/* Inject logout button into physician dashboard header */}
      <PhysicianLogoutContext.Provider value={{ handleLogout }}>
        {children}
      </PhysicianLogoutContext.Provider>
    </>
  );
}

// Context for logout function
import { createContext, useContext } from "react";

interface PhysicianLogoutContextType {
  handleLogout: () => void;
}

const PhysicianLogoutContext = createContext<PhysicianLogoutContextType>({
  handleLogout: () => {},
});

export function usePhysicianLogout() {
  return useContext(PhysicianLogoutContext);
}

// Standalone logout button component
export function PhysicianLogoutButton() {
  const { handleLogout } = usePhysicianLogout();

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
