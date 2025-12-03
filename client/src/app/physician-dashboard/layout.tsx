"use client";

import PhysicianAuthGuard from "@/components/PhysicianAuthGuard";

export default function PhysicianDashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <PhysicianAuthGuard>{children}</PhysicianAuthGuard>;
}
