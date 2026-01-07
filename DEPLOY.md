# Deployment Guide - Physician Dashboard

## Quick Deploy to Vercel

### Prerequisites
- GitHub account connected to Vercel
- This repository: https://github.com/CavalPinarello/15-day-Intake.git

### Option 1: Web UI (Recommended)

1. Go to https://vercel.com and sign in with GitHub
2. Click "Add New Project"
3. Import repository: `CavalPinarello/15-day-Intake`
4. Configure:
   - **Root Directory**: `client`
   - **Framework**: Next.js (auto-detected)
   - **Build Command**: `npm run build`
5. Add Environment Variables:
   ```
   NEXT_PUBLIC_CONVEX_URL=https://enchanted-terrier-633.convex.cloud
   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_a25vd2luZy1pbnNlY3QtMTAuY2xlcmsuYWNjb3VudHMuZGV2JA
   CLERK_SECRET_KEY=sk_test_VEG1gwRSH77qTIBcoo65BDJXpqmDspZrFLChOWdczy
   ```
6. Click "Deploy"

### Option 2: CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Navigate to client directory
cd client

# Deploy
vercel

# Follow prompts:
# - Set up and deploy? Yes
# - Which scope? Your account
# - Link to existing project? No
# - Project name? zoe-physician-dashboard (or your choice)
# - Directory? ./ (already in client folder)
# - Override settings? No

# Add environment variables (one-time setup)
vercel env add NEXT_PUBLIC_CONVEX_URL
# Paste: https://enchanted-terrier-633.convex.cloud
# Select: Production, Preview, Development

vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
# Paste: pk_test_a25vd2luZy1pbnNlY3QtMTAuY2xlcmsuYWNjb3VudHMuZGV2JA

vercel env add CLERK_SECRET_KEY
# Paste: sk_test_VEG1gwRSH77qTIBcoo65BDJXpqmDspZrFLChOWdczy

# Deploy to production
vercel --prod
```

## Post-Deployment

1. **Custom Domain** (optional): Add your own domain in Vercel dashboard → Settings → Domains
2. **Auto-Deploy**: Every push to `main` branch will auto-deploy
3. **Preview Deployments**: Pull requests get automatic preview URLs

## Convex Backend Configuration

### ⚠️ CRITICAL: Two Convex Instances Exist

There are **TWO** Convex deployments. **You must use the correct one.**

| Instance | URL | Status | Use Case |
|----------|-----|--------|----------|
| **Dev** (USE THIS) | `https://enchanted-terrier-633.convex.cloud` | ✅ Active | Contains all patient data, used by iOS app and dashboard |
| **Prod** (DO NOT USE) | `https://necessary-gnat-882.convex.cloud` | ⚠️ Empty | Empty database, not in use |

### Why Two Instances?

The "dev" instance (`enchanted-terrier-633`) is actually the production database containing:
- All patient records
- Historical sleep data
- Check-in responses
- Clinical questionnaire data

The "prod" instance (`necessary-gnat-882`) was created but never populated with data.

### Verifying Correct Configuration

**Check Vercel Environment Variables:**
```bash
cd client
npx vercel env ls production
```

You should see `NEXT_PUBLIC_CONVEX_URL` pointing to `enchanted-terrier-633`.

**Check Local Environment:**
```bash
cat client/.env.local | grep CONVEX
```

Should show: `CONVEX_DEPLOYMENT=dev:enchanted-terrier-633`

**Check iOS App:**
The iOS app (`ZoeSleep/ZoeSleep/ConvexManager.swift`) should use:
```swift
let deploymentUrl = "https://enchanted-terrier-633.convex.cloud"
```

### Updating Convex URL in Vercel

If you ever need to change the Convex URL:

```bash
cd client

# Remove old variable
npx vercel env rm NEXT_PUBLIC_CONVEX_URL production

# Add new variable
npx vercel env add NEXT_PUBLIC_CONVEX_URL production <<EOF
https://enchanted-terrier-633.convex.cloud
EOF

# Force rebuild (skip cache)
npx vercel --prod --force
```

## Monitoring

- **Vercel Dashboard**: View logs, analytics, and deployment status
- **Convex Dashboard**: https://dashboard.convex.dev
  - Select `enchanted-terrier-633` deployment
  - View database tables, logs, and API metrics
  - Monitor function calls and performance

## Common Issues & Solutions

### Issue 1: "Zero patients" in dashboard

**Symptom**: Dashboard loads but shows "All Patients (0)"

**Cause**: Vercel is using wrong Convex URL (prod instead of dev)

**Solution**:
```bash
cd client
npx vercel env ls production | grep CONVEX  # Verify current setting
# If wrong, update to enchanted-terrier-633 (see "Updating Convex URL" above)
```

### Issue 2: "Could not find public function for 'physician:getCheckInHistory'"

**Symptom**: Error when clicking on patient details

**Cause**: Wrong API import path in code

**Root Cause**: The function exists in `api.checkIn.getCheckInHistory`, not `api.physician.getCheckInHistory`

**Prevention**: Always check Convex function locations:
```bash
# List all functions by namespace
ls convex/*.ts
# Check function definitions
grep -n "export const getCheckInHistory" convex/*.ts
```

**API Path Reference**:
- Sleep data: `api.healthkit.*`
- Check-ins: `api.checkIn.*` ← Use this for check-in history
- Physician operations: `api.physician.*`
- Clinical scores: `api.physician.calculatePatientScores`
- Pillar stats: `api.physician.getPillarStats`

### Issue 3: "Invalid session token"

**Symptom**: Dashboard crashes with "Invalid session token" after clicking patient

**Cause**: Stale `physician_session` in browser localStorage

**Solution** (user must do this):
1. Open browser dev console (Safari: Cmd+Option+C, Chrome: Cmd+Option+J)
2. Run: `localStorage.removeItem("physician_session")`
3. Refresh page
4. Log in again with master password

**Why This Happens**:
- Session tokens are tied to specific Convex instances
- Switching Convex URLs invalidates old sessions
- Sessions also expire after 24 hours

### Issue 4: Vercel serving old cached build

**Symptom**: Code changes deployed but errors persist

**Cause**: Vercel's build cache serving stale JavaScript bundles

**Solution**:
```bash
cd client
npx vercel --prod --force  # --force flag skips cache
```

**User must also**:
1. Hard refresh browser: Cmd+Shift+R (Chrome) or Cmd+Option+E then Cmd+R (Safari)
2. Clear localStorage (see Issue 3)

### Issue 5: Build fails with TypeScript errors

**Symptom**: Vercel deployment fails during `npm run build`

**Common Causes**:
- Missing type imports
- Unused variables in production build (set to error)
- Type mismatches in component props

**Solution**:
```bash
# Test build locally first
cd client
npm run build

# Check for type errors
npm run typecheck  # If script exists
# or
npx tsc --noEmit
```

### Issue 6: Clerk authentication not working

**Symptom**: Can't access `/physician-dashboard/admin`

**Cause**: Clerk dashboard not configured with Vercel URL

**Solution**:
1. Go to https://dashboard.clerk.com
2. Select your application
3. Navigate to **Domains** → **Frontend API**
4. Add your Vercel URL: `client-6etqrserv-cavalapps-gmailcoms-projects.vercel.app`
5. Save changes

## Deployment Verification Checklist

After deploying to Vercel, verify everything works:

### 1. Check Environment Variables
```bash
cd client
npx vercel env ls production
```
✅ Confirm: `NEXT_PUBLIC_CONVEX_URL` = `https://enchanted-terrier-633.convex.cloud`

### 2. Test Master Password Screen
- Navigate to: `https://[your-vercel-url]/physician-dashboard/admin`
- Should see master password prompt (not Clerk login)
- Enter master password
- Should reach patient list

### 3. Verify Patient Data Loads
- Patient list should show > 0 patients
- If zero patients → wrong Convex URL (see Issue 1)

### 4. Test Patient Detail View
- Click on any patient
- Should load dashboard tabs without errors
- Check browser console (F12) for errors
- Common error: `physician:getCheckInHistory` → see Issue 2

### 5. Test Data Visualization
- Main Dashboard tab should show:
  - Sleep Quality Trends chart with device breakdown
  - Health Pillars grid (11 pillars)
  - Circadian metrics
  - HealthKit data (if patient has wearable)
- Verify wellness overlay toggles work (energy/mood/focus)

### 6. Test Pillar Detail Modal
- Click any health pillar
- Modal should open showing:
  - Pillar score and progress
  - Clinical severity indicators
  - **Data Sources** section listing questionnaires
  - Answered/pending questions
- Verify questionnaire mapping is correct:
  - Sleep Quality → PSQI
  - Mental Health → PHQ-9, GAD-7
  - Sleep Log → ISI, ESS
  - etc.

### 7. Clear Browser State (If Issues)
```javascript
// Run in browser console
localStorage.removeItem("physician_session")
location.reload()
```

## Emergency Rollback

If deployment breaks production:

```bash
cd client

# List recent deployments
npx vercel ls

# Rollback to previous deployment
npx vercel rollback [previous-deployment-url]

# Or promote a specific deployment to production
npx vercel promote [deployment-url]
```

## Development vs Production

| Environment | Convex URL | Usage |
|-------------|-----------|-------|
| Local dev | `http://localhost:3000` | Use `npx convex dev` |
| Vercel prod | `https://enchanted-terrier-633.convex.cloud` | Always use dev instance |

**Important**: There is no separate "staging" environment. All deployments use the same Convex dev instance with real patient data.

## API Naming Convention Reference

To avoid path errors like `physician:getCheckInHistory`, use this reference:

```typescript
// ✅ CORRECT API paths (from /convex/ directory)
api.checkIn.getCheckInHistory              // convex/checkIn.ts
api.checkIn.getNapPatterns                  // convex/checkIn.ts
api.healthkit.getPatientHealthSummary       // convex/healthkit.ts
api.healthkit.getMultiSourceSleepData       // convex/healthkit.ts
api.physician.getPillarStats                // convex/physician.ts
api.physician.getQuestionnaireScores        // convex/physician.ts
api.physician.getSubjectiveSleepQuality     // convex/physician.ts
api.circadian.getCircadianDataForPhysician  // convex/circadian.ts
api.collaborators.getAllPhysicians          // convex/collaborators.ts

// ❌ WRONG - These don't exist
api.physician.getCheckInHistory             // NO - it's in checkIn.ts
api.healthkit.getCheckInHistory             // NO - wrong namespace
```

**Rule**: The namespace in `api.[namespace].[function]` must match the filename in `/convex/[namespace].ts`
