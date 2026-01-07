"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { useState } from "react";
import { Users, Mail, Shield, UserX, Edit2, RefreshCw, X, AlertCircle } from "lucide-react";
import { Id } from "@/convex/_generated/dataModel";

export default function CollaboratorsPanel() {
  const sessionToken = typeof window !== "undefined"
    ? localStorage.getItem("physician_session")
    : null;

  const physicians = useQuery(
    api.collaborators.getAllPhysicians,
    sessionToken ? { sessionToken } : "skip"
  );

  const pendingInvitations = useQuery(
    api.collaborators.getPendingInvitations,
    sessionToken ? { sessionToken } : "skip"
  );

  const [showInviteModal, setShowInviteModal] = useState(false);
  const [editingPhysician, setEditingPhysician] = useState<any>(null);

  return (
    <div className="bg-white rounded-lg shadow p-6 mb-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Users className="w-5 h-5 text-teal-600" />
          <h2 className="text-xl font-semibold">Collaborators</h2>
        </div>
        <button
          onClick={() => setShowInviteModal(true)}
          className="flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
        >
          <Mail className="w-4 h-4" />
          Invite Physician
        </button>
      </div>

      {/* Active Physicians */}
      <div className="space-y-3">
        <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">
          Active Physicians
        </h3>
        {physicians && physicians.length > 0 ? (
          physicians.map((physician) => (
            <PhysicianCard
              key={physician._id}
              physician={physician}
              onEdit={() => setEditingPhysician(physician)}
            />
          ))
        ) : (
          <p className="text-sm text-gray-500 py-4">No physicians yet. Invite someone to get started!</p>
        )}
      </div>

      {/* Pending Invitations */}
      {pendingInvitations && pendingInvitations.length > 0 && (
        <div className="mt-6 space-y-3">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">
            Pending Invitations
          </h3>
          {pendingInvitations.map((invitation) => (
            <InvitationCard key={invitation._id} invitation={invitation} />
          ))}
        </div>
      )}

      {/* Invite Modal */}
      {showInviteModal && (
        <InvitePhysicianModal onClose={() => setShowInviteModal(false)} />
      )}

      {/* Edit Modal */}
      {editingPhysician && (
        <EditPhysicianModal
          physician={editingPhysician}
          onClose={() => setEditingPhysician(null)}
        />
      )}
    </div>
  );
}

function PhysicianCard({ physician, onEdit }: { physician: any; onEdit: () => void }) {
  const sessionToken = typeof window !== "undefined"
    ? localStorage.getItem("physician_session")
    : null;

  const deactivatePhysician = useMutation(api.collaborators.deactivatePhysician);
  const [isDeactivating, setIsDeactivating] = useState(false);

  const permissionLabels: Record<string, string> = {
    viewer: "Read-only Viewer",
    clinician: "Clinician",
    admin: "Administrator"
  };

  const permissionIcons: Record<string, string> = {
    viewer: "👁️",
    clinician: "🩺",
    admin: "⚡"
  };

  const handleDeactivate = async () => {
    if (!confirm(`Deactivate ${physician.full_name}? They will immediately lose access to the dashboard.`)) {
      return;
    }

    setIsDeactivating(true);
    try {
      await deactivatePhysician({
        sessionToken: sessionToken!,
        physicianId: physician._id,
      });
    } catch (error: any) {
      alert(error.message);
    } finally {
      setIsDeactivating(false);
    }
  };

  return (
    <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
      <div className="flex items-center gap-3">
        {physician.avatar_url ? (
          <img
            src={physician.avatar_url}
            alt={physician.full_name}
            className="w-10 h-10 rounded-full"
          />
        ) : (
          <div className="w-10 h-10 rounded-full bg-teal-100 flex items-center justify-center text-teal-700 font-semibold">
            {physician.full_name.charAt(0)}
          </div>
        )}
        <div>
          <p className="font-medium">{physician.full_name}</p>
          <p className="text-sm text-gray-500">{physician.email}</p>
          <div className="flex items-center gap-2 mt-1">
            <span className="text-xs">
              {permissionIcons[physician.permission_level]} {permissionLabels[physician.permission_level]}
            </span>
            <span className="text-xs text-gray-400">•</span>
            <span className="text-xs text-gray-500">
              {physician.patientCount || 0} patients
            </span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={onEdit}
          className="p-2 text-gray-500 hover:text-gray-700 rounded hover:bg-gray-200 transition-colors"
          title="Edit permissions"
        >
          <Edit2 className="w-4 h-4" />
        </button>
        <button
          onClick={handleDeactivate}
          disabled={isDeactivating}
          className="p-2 text-red-500 hover:text-red-700 rounded hover:bg-red-50 transition-colors disabled:opacity-50"
          title="Deactivate physician"
        >
          {isDeactivating ? (
            <div className="w-4 h-4 border-2 border-red-500 border-t-transparent rounded-full animate-spin" />
          ) : (
            <UserX className="w-4 h-4" />
          )}
        </button>
      </div>
    </div>
  );
}

function InvitationCard({ invitation }: { invitation: any }) {
  const sessionToken = typeof window !== "undefined"
    ? localStorage.getItem("physician_session")
    : null;

  const resendInvitation = useMutation(api.collaborators.resendInvitation);
  const revokeInvitation = useMutation(api.collaborators.revokeInvitation);

  const [isResending, setIsResending] = useState(false);
  const [isRevoking, setIsRevoking] = useState(false);
  const [copiedUrl, setCopiedUrl] = useState(false);

  const expiresIn = Math.ceil((invitation.expires_at - Date.now()) / (1000 * 60 * 60 * 24));

  const handleResend = async () => {
    setIsResending(true);
    try {
      const result = await resendInvitation({
        sessionToken: sessionToken!,
        invitationId: invitation._id,
      });
      alert(`Invitation resent successfully! New expiry: ${new Date(result.newExpiresAt).toLocaleDateString()}`);
    } catch (error: any) {
      alert(error.message);
    } finally {
      setIsResending(false);
    }
  };

  const handleRevoke = async () => {
    if (!confirm(`Revoke invitation to ${invitation.email}?`)) {
      return;
    }

    setIsRevoking(true);
    try {
      await revokeInvitation({
        sessionToken: sessionToken!,
        invitationId: invitation._id,
      });
    } catch (error: any) {
      alert(error.message);
    } finally {
      setIsRevoking(false);
    }
  };

  const handleCopyInviteUrl = () => {
    const url = `${window.location.origin}/physician-dashboard/accept-invite?token=${invitation.invitation_token}`;
    navigator.clipboard.writeText(url);
    setCopiedUrl(true);
    setTimeout(() => setCopiedUrl(false), 2000);
  };

  return (
    <div className="flex items-center justify-between p-4 bg-amber-50 rounded-lg border border-amber-200">
      <div>
        <p className="font-medium text-amber-900">{invitation.email}</p>
        <p className="text-sm text-amber-700">
          {invitation.permission_level} • Expires in {expiresIn} {expiresIn === 1 ? 'day' : 'days'}
        </p>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={handleCopyInviteUrl}
          className="flex items-center gap-2 px-3 py-1 text-amber-700 hover:text-amber-900 hover:bg-amber-100 rounded transition-colors"
          title="Copy invitation link"
        >
          {copiedUrl ? '✓ Copied' : 'Copy Link'}
        </button>
        <button
          onClick={handleResend}
          disabled={isResending}
          className="flex items-center gap-2 px-3 py-1 text-amber-700 hover:text-amber-900 hover:bg-amber-100 rounded transition-colors disabled:opacity-50"
          title="Resend invitation email"
        >
          {isResending ? (
            <div className="w-4 h-4 border-2 border-amber-700 border-t-transparent rounded-full animate-spin" />
          ) : (
            <RefreshCw className="w-4 h-4" />
          )}
          Resend
        </button>
        <button
          onClick={handleRevoke}
          disabled={isRevoking}
          className="p-2 text-red-500 hover:text-red-700 rounded hover:bg-red-50 transition-colors disabled:opacity-50"
          title="Revoke invitation"
        >
          {isRevoking ? (
            <div className="w-4 h-4 border-2 border-red-500 border-t-transparent rounded-full animate-spin" />
          ) : (
            <X className="w-4 h-4" />
          )}
        </button>
      </div>
    </div>
  );
}

function InvitePhysicianModal({ onClose }: { onClose: () => void }) {
  const [email, setEmail] = useState("");
  const [permission, setPermission] = useState<"viewer" | "clinician" | "admin">("clinician");
  const [message, setMessage] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [inviteUrl, setInviteUrl] = useState("");

  const invitePhysician = useMutation(api.collaborators.invitePhysician);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const sessionToken = localStorage.getItem("physician_session");

    if (!sessionToken) {
      alert("No session token found. Please log in again.");
      return;
    }

    setIsSubmitting(true);
    try {
      const result = await invitePhysician({
        sessionToken,
        email,
        permissionLevel: permission,
        personalMessage: message || undefined,
      });

      // Show success with invite URL
      const fullUrl = `${window.location.origin}${result.inviteUrl}`;
      setInviteUrl(fullUrl);

    } catch (error: any) {
      alert(error.message);
      setIsSubmitting(false);
    }
  };

  const handleCopyAndClose = () => {
    navigator.clipboard.writeText(inviteUrl);
    alert("Invitation link copied to clipboard!");
    onClose();
  };

  if (inviteUrl) {
    // Success state - show invite URL
    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
          <div className="flex items-center gap-3 mb-4 text-green-600">
            <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold text-gray-900">Invitation Sent!</h3>
          </div>

          <p className="text-sm text-gray-600 mb-4">
            An invitation has been created for <strong>{email}</strong>. Share this link with them:
          </p>

          <div className="bg-gray-50 p-3 rounded border border-gray-200 mb-4 break-all text-sm">
            {inviteUrl}
          </div>

          <div className="flex gap-2">
            <button
              onClick={handleCopyAndClose}
              className="flex-1 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors"
            >
              Copy Link & Close
            </button>
            <button
              onClick={onClose}
              className="px-4 py-2 border rounded-lg hover:bg-gray-50 transition-colors"
            >
              Close
            </button>
          </div>

          <p className="text-xs text-amber-600 mt-3 flex items-center gap-1">
            <AlertCircle className="w-3 h-3" />
            Invitation expires in 7 days
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-semibold">Invite Physician</h3>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email Address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
              placeholder="doctor@example.com"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Permission Level</label>
            <select
              value={permission}
              onChange={(e) => setPermission(e.target.value as any)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
            >
              <option value="viewer">👁️ Read-only Viewer</option>
              <option value="clinician">🩺 Clinician (Read + Write)</option>
              <option value="admin">⚡ Administrator (Full Access)</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              {permission === "viewer" && "Can view patient data but cannot make changes"}
              {permission === "clinician" && "Can view patients, write notes, and assign interventions"}
              {permission === "admin" && "Can invite other physicians and delete patients"}
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              Personal Message (Optional)
            </label>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
              rows={3}
              placeholder="Welcome to the team! Looking forward to working with you."
            />
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border rounded-lg hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50"
            >
              {isSubmitting ? (
                <div className="flex items-center justify-center gap-2">
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  Sending...
                </div>
              ) : (
                "Send Invitation"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function EditPhysicianModal({ physician, onClose }: { physician: any; onClose: () => void }) {
  const [permission, setPermission] = useState(physician.permission_level);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const updatePermissions = useMutation(api.collaborators.updatePhysicianPermissions);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const sessionToken = localStorage.getItem("physician_session");

    if (!sessionToken) {
      alert("No session token found. Please log in again.");
      return;
    }

    setIsSubmitting(true);
    try {
      await updatePermissions({
        sessionToken,
        physicianId: physician._id,
        permissionLevel: permission,
      });
      alert("Permissions updated successfully!");
      onClose();
    } catch (error: any) {
      alert(error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-semibold">Edit Permissions</h3>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="mb-4">
          <p className="text-sm text-gray-600">
            <strong>{physician.full_name}</strong>
          </p>
          <p className="text-sm text-gray-500">{physician.email}</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Permission Level</label>
            <select
              value={permission}
              onChange={(e) => setPermission(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
            >
              <option value="viewer">👁️ Read-only Viewer</option>
              <option value="clinician">🩺 Clinician (Read + Write)</option>
              <option value="admin">⚡ Administrator (Full Access)</option>
            </select>
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border rounded-lg hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || permission === physician.permission_level}
              className="flex-1 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50"
            >
              {isSubmitting ? "Updating..." : "Update Permissions"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
