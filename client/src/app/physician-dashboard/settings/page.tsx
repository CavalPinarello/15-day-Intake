"use client";

import Link from "next/link";
import { UserButton, useUser } from "@clerk/nextjs";
import {
  Moon,
  Users,
  ClipboardList,
  Settings,
  User,
  Bell,
  Shield,
  Palette,
  Mail,
} from "lucide-react";

export default function PhysicianSettingsPage() {
  const { user } = useUser();

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-teal-500 to-blue-600 flex items-center justify-center">
                <Moon className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zoe Sleep</h1>
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
                href="/physician-dashboard/settings"
                className="flex items-center gap-2 text-teal-600 font-medium"
              >
                <Settings className="w-5 h-5" />
                Settings
              </Link>
              <UserButton
                appearance={{
                  elements: {
                    avatarBox: "w-9 h-9",
                  },
                }}
              />
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
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-bold text-2xl">
              {user?.firstName?.[0] || user?.username?.[0] || "?"}
            </div>
            <div>
              <h4 className="text-xl font-semibold text-gray-900">
                {user?.fullName || user?.username || "Physician"}
              </h4>
              <p className="text-gray-500">{user?.primaryEmailAddress?.emailAddress}</p>
              <span className="inline-block mt-2 px-3 py-1 bg-teal-100 text-teal-700 rounded-full text-sm font-medium">
                Physician
              </span>
            </div>
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

        {/* Security Section */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6">
          <div className="flex items-center gap-2 mb-6">
            <Shield className="w-5 h-5 text-gray-400" />
            <h3 className="text-lg font-semibold text-gray-900">Security</h3>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-gray-900">Two-Factor Authentication</p>
                <p className="text-sm text-gray-500">
                  Add an extra layer of security to your account
                </p>
              </div>
              <button className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                Enable
              </button>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-gray-900">Session Management</p>
                <p className="text-sm text-gray-500">
                  Manage your active sessions and devices
                </p>
              </div>
              <button className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                View Sessions
              </button>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div className="mt-8 flex justify-end">
          <button className="px-6 py-3 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors font-medium">
            Save Changes
          </button>
        </div>
      </main>
    </div>
  );
}
