# Convex Database Setup

## Overview

This directory contains the Convex database schema and functions for the ZOE Sleep Platform.

## Schema

The `schema.ts` file defines all 30+ tables for the complete system:
- Component 1: 14-Day Onboarding Journey
- Component 2: Daily App Use
- Component 3: Full Sleep Report
- Component 4: Coach Dashboard
- Component 5: Supporting Systems

## Setup Instructions

### 1. Initialize Convex

```bash
# Install Convex CLI (if not already installed)
npm install -g convex

# Initialize Convex in the project
npx convex dev
```

This will:
- Create a Convex account (if needed)
- Link your project to Convex
- Deploy the schema
- Start the development server

### 2. Deploy Schema

The schema will automatically deploy when you run `npx convex dev`.

### 3. Verify Schema

Check the Convex dashboard to verify all tables are created:
- Go to https://dashboard.convex.dev
- Select your project
- View the "Schema" tab

## Schema Features

- ✅ All 30+ tables defined
- ✅ Proper indexes for performance
- ✅ Foreign key relationships (via v.id() references)
- ✅ Unique constraints (via index definitions)
- ✅ Type-safe with TypeScript

## Migration from SQLite

The Convex schema matches the SQLite schema structure. To migrate data:

1. Export data from SQLite
2. Transform to Convex format
3. Import using Convex mutations

## Next Steps

1. Create Convex functions (queries, mutations, actions)
2. Update API routes to use Convex
3. Deploy to production



