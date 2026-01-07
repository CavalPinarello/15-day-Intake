# Incident Report: Convex Instance Confusion (2026-01-07)

## Summary

Physician dashboard deployment failed due to confusion between two Convex instances, resulting in:
- Empty patient list ("Zero patients")
- Invalid session token errors
- Multiple failed redeployments
- Lost development time

## Timeline

1. **Initial deployment**: Dashboard enhancements deployed successfully to Vercel
2. **Error discovered**: User reported `physician:getCheckInHistory` function not found
3. **Fix #1**: Corrected API path from `api.physician.getCheckInHistory` to `api.checkIn.getCheckInHistory`
4. **Error persisted**: Despite code fix, error continued appearing
5. **Cache issues**: Vercel serving cached old builds
6. **Session issues**: Stale localStorage tokens causing crashes
7. **Wrong database**: Assistant mistakenly switched Vercel to "prod" Convex instance (empty database)
8. **User frustration**: "but you connected it to some other database. i have zero patients!!!!"
9. **Resolution**: Switched back to "dev" Convex instance with patient data

## Root Causes

### 1. Confusing Instance Naming

**The Problem:**
- "Dev" instance (`enchanted-terrier-633`) contains production data
- "Prod" instance (`necessary-gnat-882`) is empty and unused

**Why This Is Confusing:**
- Naming suggests opposite of reality
- No clear documentation about which to use
- Easy to assume "prod" should be used for production deployments

**Impact:**
- Assistant made incorrect assumption that production Vercel should use production Convex
- 30+ minutes wasted debugging wrong database

### 2. Wrong API Import Path

**The Problem:**
- Code called `api.physician.getCheckInHistory`
- Function actually exists at `api.checkIn.getCheckInHistory`

**Why This Happened:**
- Check-in functions logically seem related to "physician" operations
- No clear namespace conventions documented
- Easy to guess wrong location

**Impact:**
- Dashboard crashed when clicking on patients
- Multiple redeployment attempts before finding root cause

### 3. Vercel Build Cache

**The Problem:**
- Vercel serves cached builds even after code changes deployed
- Standard redeploy (`npx vercel --prod`) doesn't clear cache

**Why This Is Problematic:**
- Code fixes don't take effect immediately
- Appears like deployments are failing when they're actually cached
- Requires `--force` flag to bypass cache

**Impact:**
- Multiple failed redeployment attempts
- Confusion about whether fix was actually deployed
- Wasted time debugging "phantom" errors from old code

### 4. Session Token Invalidation

**The Problem:**
- Switching Convex instances invalidates all existing session tokens
- Tokens stored in browser localStorage persist across deployments
- No automatic cleanup of stale tokens

**Why This Causes Issues:**
- User sees "Invalid session token" errors
- Dashboard appears broken even after correct deployment
- Requires manual localStorage clearing by user

**Impact:**
- Additional debugging time
- User frustration with "broken" dashboard
- Required manual intervention in browser console

## Lessons Learned

### 1. Documentation Is Critical

**What We Learned:**
- Confusing configurations must be extensively documented
- Quick reference guides prevent repeated mistakes
- Troubleshooting checklists save time during incidents

**Actions Taken:**
- Created comprehensive `DEPLOY.md` with 6 common issue solutions
- Updated `CLAUDE.md` with critical Convex configuration warnings
- Created `TROUBLESHOOTING.md` quick reference guide
- Documented this incident for future reference

### 2. Namespace Conventions Matter

**What We Learned:**
- Clear API path conventions prevent wrong imports
- Documentation should include "wrong examples" to avoid
- Searching codebase is more reliable than guessing

**Actions Taken:**
- Added API Path Reference table to `DEPLOY.md`
- Documented correct namespaces for all major function groups
- Included "how to search for correct path" instructions

### 3. Cache Management

**What We Learned:**
- Always use `--force` flag when redeploying fixes
- Instruct users to clear browser cache and localStorage
- Document cache clearing procedures

**Actions Taken:**
- All deployment instructions now include `--force` flag
- Added browser cache clearing steps to troubleshooting guide
- Documented why cache issues occur

### 4. Session Lifecycle

**What We Learned:**
- Session tokens are tied to Convex instances
- Switching instances requires session cleanup
- Users need clear instructions for clearing sessions

**Actions Taken:**
- Documented session management in troubleshooting guide
- Added clear localStorage clearing instructions
- Explained why sessions become invalid

## Prevention Measures

### Immediate Actions (Completed)

- [x] Document two Convex instances with clear warnings
- [x] Add quick verification commands
- [x] Create troubleshooting guide with common errors
- [x] Document API path conventions
- [x] Add deployment verification checklist
- [x] Include cache clearing procedures

### Future Improvements

- [ ] Consider renaming Convex instances for clarity:
  - `enchanted-terrier-633` → `production-database`
  - `necessary-gnat-882` → `unused-old-instance`
- [ ] Add health check endpoint to verify correct Convex connection
- [ ] Create pre-deployment verification script
- [ ] Add automated tests for API path correctness
- [ ] Consider implementing automatic session cleanup on version changes

## Code Changes Made

### Files Modified

1. **`client/src/components/patient/tabs/MainDashboardTab.tsx`** (Line 84)
   - Changed: `api.physician.getCheckInHistory`
   - To: `api.checkIn.getCheckInHistory`

2. **`client/src/components/charts/MultiSourceSleepChart.tsx`**
   - Added wellness metrics overlay (energy/mood/focus)
   - Added toggle switches for data sources
   - Integrated wellness data from check-ins

3. **`client/src/components/patient/PillarDetailModal.tsx`**
   - Added `PILLAR_QUESTIONNAIRES` mapping
   - Added Data Sources section showing which questionnaires feed each pillar

### Environment Variables

- **Vercel Production:** `NEXT_PUBLIC_CONVEX_URL = https://enchanted-terrier-633.convex.cloud`
- **Local Dev:** `CONVEX_DEPLOYMENT = dev:enchanted-terrier-633`

### Deployment Commands Used

```bash
# Correct Convex URL
npx vercel env add NEXT_PUBLIC_CONVEX_URL production <<EOF
https://enchanted-terrier-633.convex.cloud
EOF

# Force rebuild (skip cache)
npx vercel --prod --force
```

## Verification

After resolution, the following should be verified:

- [x] Vercel env vars point to `enchanted-terrier-633`
- [x] Code uses `api.checkIn.getCheckInHistory`
- [x] Build completes without errors
- [ ] User tests deployment and confirms patient list loads
- [ ] User clicks on patient and verifies dashboard loads
- [ ] Wellness overlay and pillar data sources work correctly

## Final Notes

**Cost of Incident:**
- ~60 minutes of debugging and documentation
- Multiple failed deployment attempts
- User frustration with "zero patients" error

**Value of Documentation:**
- Future incidents can be resolved in <5 minutes
- Clear troubleshooting steps prevent repeated mistakes
- Quick reference guides enable self-service debugging

**Key Takeaway:**
When working with multiple backend instances that have confusing names, **document extensively** and **verify configuration before every deployment**.

---

**Related Documentation:**
- [`DEPLOY.md`](../DEPLOY.md) - Complete deployment guide
- [`TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) - Quick reference
- [`CLAUDE.md`](../CLAUDE.md) - Critical configuration info
