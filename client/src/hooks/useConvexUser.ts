"use client";

import { useUser } from "@clerk/nextjs";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useEffect, useState, useCallback } from "react";

/**
 * Hook to map Clerk user to Convex user
 * Automatically creates or links Convex user when Clerk user is authenticated
 */
export function useConvexUser() {
  const { user: clerkUser, isLoaded: clerkLoaded, isSignedIn } = useUser();
  const [convexUserId, setConvexUserId] = useState<Id<"users"> | null>(null);
  const [isInitializing, setIsInitializing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Mutation to create/link user
  const getOrCreateUser = useMutation(api.web.getOrCreateUserByClerk);

  // Query to get user data (will be reactive once we have the userId)
  const userData = useQuery(
    api.web.getUserByClerkId,
    clerkUser?.id ? { clerkUserId: clerkUser.id } : "skip"
  );

  // Effect to initialize Convex user from Clerk
  useEffect(() => {
    async function initializeUser() {
      if (!clerkLoaded || !isSignedIn || !clerkUser || isInitializing) {
        return;
      }

      // If we already have userData from query, use that
      if (userData) {
        setConvexUserId(userData._id);
        return;
      }

      // Otherwise, create/link the user
      setIsInitializing(true);
      setError(null);

      try {
        const result = await getOrCreateUser({
          clerkUserId: clerkUser.id,
          email: clerkUser.primaryEmailAddress?.emailAddress,
          username: clerkUser.username || undefined,
          fullName: clerkUser.fullName || clerkUser.firstName || undefined,
          profilePicture: clerkUser.imageUrl || undefined,
        });

        setConvexUserId(result.userId);
      } catch (err) {
        console.error("[useConvexUser] Failed to initialize user:", err);
        setError(err instanceof Error ? err.message : "Failed to initialize user");
      } finally {
        setIsInitializing(false);
      }
    }

    initializeUser();
  }, [clerkLoaded, isSignedIn, clerkUser, userData, getOrCreateUser, isInitializing]);

  // Determine loading state
  const isLoading = !clerkLoaded || (isSignedIn && !convexUserId && !error);

  return {
    // Convex user ID (null if not authenticated or not yet initialized)
    userId: convexUserId,

    // User data from Convex (reactive)
    userData,

    // Clerk user data (for display purposes)
    clerkUser,

    // Loading states
    isLoading,
    isInitializing,

    // Auth state
    isAuthenticated: isSignedIn && !!convexUserId,
    isSignedIn,

    // Error state
    error,
  };
}

/**
 * Hook to get journey state for the current user
 */
export function useJourneyState() {
  const { userId } = useConvexUser();

  const journeyState = useQuery(
    api.web.getWebJourneyState,
    userId ? { userId } : "skip"
  );

  return {
    journeyState,
    isLoading: userId !== null && journeyState === undefined,
    currentDay: journeyState?.currentDay ?? 1,
    totalDays: journeyState?.totalDays ?? 15,
    sleepLogCompleted: journeyState?.sleepLogCompleted ?? false,
    assessmentCompleted: journeyState?.assessmentCompleted ?? false,
    onboardingCompleted: journeyState?.onboardingCompleted ?? false,
  };
}
