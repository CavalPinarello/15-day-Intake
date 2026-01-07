"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useUser } from "@clerk/nextjs";
import { useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { SignIn } from "@clerk/nextjs";
import { ZoeLogo } from "@/components/ZoeLogo";
import ZoeLogoFull from "@/components/ZoeLogoFull";

function AcceptInviteContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const { user, isSignedIn } = useUser();
  const [step, setStep] = useState<"signin" | "accepting" | "success" | "error">("signin");
  const [error, setError] = useState("");

  const token = searchParams.get("token");
  const acceptInvitation = useMutation(api.collaborators.acceptInvitation);
  const createSession = useMutation(api.physicianAuth.createClerkPhysicianSession);

  useEffect(() => {
    if (!token) {
      setError("Invalid invitation link. No token provided.");
      setStep("error");
      return;
    }

    if (isSignedIn && user) {
      handleAcceptInvitation();
    }
  }, [isSignedIn, user, token]);

  const handleAcceptInvitation = async () => {
    if (!token || !user) return;

    setStep("accepting");

    try {
      // Accept invitation and create physician record
      const result = await acceptInvitation({
        invitationToken: token,
        clerkUserId: user.id,
        clerkEmail: user.primaryEmailAddress?.emailAddress || "",
        fullName: user.fullName || user.firstName || "Physician",
        avatarUrl: user.imageUrl,
      });

      // Create Convex session
      const session = await createSession({
        clerkUserId: user.id,
        clerkSessionId: user.id, // Use Clerk user ID as session ID
      });

      // Store session token
      localStorage.setItem("physician_session", session.sessionToken);

      setStep("success");

      // Redirect to dashboard after 2 seconds
      setTimeout(() => {
        router.push("/physician-dashboard");
      }, 2000);

    } catch (err: any) {
      setError(err.message);
      setStep("error");
    }
  };

  if (step === "signin") {
    return (
      <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center p-4">
        <div className="max-w-md w-full">
          <div className="text-center mb-6">
            <div className="inline-flex items-center justify-center px-6 py-3 bg-white rounded-xl shadow-sm mb-4">
              <ZoeLogoFull height={40} />
            </div>
            <h1 className="text-2xl font-bold text-gray-900 mb-2">
              Accept Physician Invitation
            </h1>
            <p className="text-gray-600">
              Sign in or create an account to join the Zoé Sleep physician dashboard
            </p>
          </div>

          <div className="bg-white rounded-lg shadow-lg p-6">
            <SignIn
              routing="hash"
              afterSignInUrl={`/physician-dashboard/accept-invite?token=${token}`}
              appearance={{
                elements: {
                  rootBox: "w-full",
                  card: "shadow-none",
                },
              }}
            />
          </div>

          <p className="text-center text-sm text-gray-500 mt-4">
            By accepting this invitation, you agree to the terms of use and privacy policy.
          </p>
        </div>
      </div>
    );
  }

  if (step === "accepting") {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-xl mb-4">
            <ZoeLogo size={64} />
          </div>
          <div className="animate-spin w-12 h-12 border-4 border-teal-500 border-t-transparent rounded-full mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Setting up your account...</h2>
          <p className="text-gray-600">This will only take a moment</p>
        </div>
      </div>
    );
  }

  if (step === "success") {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Welcome to Zoé Sleep!</h2>
          <p className="text-gray-600 mb-4">
            Your physician account has been activated successfully.
          </p>
          <div className="inline-flex items-center gap-2 text-sm text-gray-500">
            <div className="w-4 h-4 border-2 border-teal-500 border-t-transparent rounded-full animate-spin" />
            Redirecting to dashboard...
          </div>
        </div>
      </div>
    );
  }

  // Error state
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg className="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Unable to Accept Invitation</h2>
        <p className="text-gray-600 mb-6">{error}</p>
        <div className="flex flex-col gap-2">
          <a
            href="/physician-login"
            className="inline-block px-6 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
          >
            Go to Login
          </a>
          <a
            href="/physician-dashboard"
            className="inline-block px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Back to Dashboard
          </a>
        </div>
      </div>
    </div>
  );
}

export default function AcceptInvitePage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-xl mb-4">
            <ZoeLogo size={64} />
          </div>
          <div className="animate-spin w-12 h-12 border-4 border-teal-500 border-t-transparent rounded-full mx-auto" />
          <p className="text-gray-600 mt-4">Loading...</p>
        </div>
      </div>
    }>
      <AcceptInviteContent />
    </Suspense>
  );
}
