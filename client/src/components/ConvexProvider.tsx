"use client";

import { ConvexProvider as ConvexReactProvider } from "convex/react";
import { ConvexReactClient } from "convex/react";

// Only create Convex client if URL is configured
const convexUrl = process.env.NEXT_PUBLIC_CONVEX_URL;
const convex = convexUrl ? new ConvexReactClient(convexUrl) : null;

export function ConvexProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  // If Convex is not configured, just render children without provider
  if (!convex) {
    return <>{children}</>;
  }

  return (
    <ConvexReactProvider client={convex}>
      {children}
    </ConvexReactProvider>
  );
}