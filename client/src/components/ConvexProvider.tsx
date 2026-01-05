"use client";

import { ConvexProvider as ConvexReactProvider } from "convex/react";
import { ConvexReactClient } from "convex/react";
import { useMemo } from "react";

export function ConvexProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  // Create Convex client on the client side
  const convex = useMemo(() => {
    const convexUrl = process.env.NEXT_PUBLIC_CONVEX_URL;
    if (!convexUrl) {
      console.error("NEXT_PUBLIC_CONVEX_URL is not configured");
      return null;
    }
    return new ConvexReactClient(convexUrl);
  }, []);

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