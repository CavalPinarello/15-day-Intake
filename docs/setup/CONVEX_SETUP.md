# Convex Database Setup Guide

## ✅ Schema Created!

I've created a complete Convex schema at `convex/schema.ts` with all 30+ tables for your ZOE Sleep Platform.

## Quick Setup

### Step 1: Initialize Convex

```bash
cd "/Users/martinkawalski/Documents/1. Projects/15-Day Test"
npx convex dev
```

This will:
1. Prompt you to login/create Convex account
2. Create a new Convex project
3. Deploy the schema automatically
4. Generate a `convex.json` config file

### Step 2: Verify Schema Deployment

After running `npx convex dev`, check:
1. Convex dashboard: https://dashboard.convex.dev
2. Go to your project → Schema tab
3. You should see all 30+ tables listed

### Step 3: Use Convex MCP Tools

Once initialized, I can use the Convex MCP tools to:
- View tables and schema
- Read data
- Run queries
- Set environment variables

## Schema Overview

The schema includes all tables for:

### Component 1: 14-Day Onboarding Journey
- `users` - User accounts
- `days` - 14 day structure
- `questions` - 84 questions
- `responses` - User responses
- `user_progress` - Progress tracking
- `onboarding_insights` - 42 insights

### Component 2: Daily App Use
- `daily_checkins` - Morning/evening check-ins
- `checkin_responses` - Check-in responses
- `user_preferences` - User settings

### Component 3: Full Sleep Report
- `sleep_reports` - Generated reports
- `report_sections` - 8 sections per report
- `report_roadmap` - Milestones and tasks

### Component 4: Coach Dashboard
- `coaches` - Coach accounts
- `customer_coach_assignments` - User-coach links
- `alerts` - System alerts
- `messages` - Coach-user messaging

### Component 5: Supporting Systems
- `refresh_tokens` - JWT refresh tokens
- `user_sleep_data` - Sleep metrics
- `user_sleep_stages` - Sleep stages
- `user_heart_rate` - Heart rate data
- `user_activity` - Activity data
- `user_workouts` - Workouts
- `user_baselines` - 30-day averages
- `interventions` - Intervention library
- `user_interventions` - Assigned interventions
- `intervention_compliance` - Compliance tracking
- `intervention_user_notes` - User notes
- `intervention_coach_notes` - Coach notes
- `intervention_schedule` - Scheduling
- `user_metrics_summary` - Aggregated metrics

## Key Features

✅ **Type-Safe**: Full TypeScript support  
✅ **Indexed**: All tables have proper indexes  
✅ **Relationships**: Foreign keys via v.id()  
✅ **Unique Constraints**: Via index definitions  
✅ **Ready to Use**: Schema matches SQLite structure

## Next Steps

1. **Initialize Convex**:
   ```bash
   npx convex dev
   ```

2. **Verify Schema**:
   - Check Convex dashboard
   - All tables should be visible

3. **Create Functions**:
   - Queries for reading data
   - Mutations for writing data
   - Actions for complex operations

4. **Update API**:
   - Replace SQLite queries with Convex calls
   - Use Convex client in your Express routes

## Convex vs SQLite

| Feature | SQLite (Dev) | Convex (Prod) |
|---------|--------------|---------------|
| Type | File-based | Cloud database |
| Schema | SQL | TypeScript |
| Queries | SQL | TypeScript functions |
| Real-time | No | Yes (built-in) |
| Scaling | Single server | Auto-scaling |
| Location | Local file | Cloud |

## Migration Strategy

You can use both databases:
- **Development**: SQLite (local)
- **Production**: Convex (cloud)

Or migrate fully to Convex:
1. Export SQLite data
2. Transform to Convex format
3. Import using Convex mutations

## Files Created

- `convex/schema.ts` - Complete schema definition
- `convex/README.md` - Convex documentation

## Ready!

Once you run `npx convex dev`, the schema will be deployed and I can help you:
- View the tables
- Create seed data
- Build Convex functions
- Migrate from SQLite

**Run `npx convex dev` to get started!** 🚀



