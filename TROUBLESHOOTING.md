# Quick Troubleshooting Guide

## Emergency Checklist

### Dashboard shows "Zero Patients"

```bash
# 1. Check Vercel Convex URL
cd client
npx vercel env ls production | grep CONVEX

# 2. Must show: enchanted-terrier-633 (NOT necessary-gnat-882)
# If wrong, fix it:
npx vercel env rm NEXT_PUBLIC_CONVEX_URL production
npx vercel env add NEXT_PUBLIC_CONVEX_URL production <<EOF
https://enchanted-terrier-633.convex.cloud
EOF

# 3. Force rebuild
npx vercel --prod --force
```

### "Invalid session token" Error

**User must do:**
1. Open browser console (Cmd+Option+C in Safari)
2. Run: `localStorage.removeItem("physician_session")`
3. Refresh page
4. Log in again

### "Could not find public function" Error

**Common mistake:** `api.physician.getCheckInHistory`
**Correct path:** `api.checkIn.getCheckInHistory`

**How to find correct path:**
```bash
# Search for function definition
grep -rn "export const getCheckInHistory" convex/
# Result shows: convex/checkIn.ts → use api.checkIn.*
```

**API Path Quick Reference:**
- Check-ins → `api.checkIn.*`
- Sleep data → `api.healthkit.*`
- Pillar stats → `api.physician.*`
- Circadian → `api.circadian.*`

### Changes Not Showing After Deploy

```bash
# 1. Force rebuild (skip cache)
cd client
npx vercel --prod --force

# 2. User must:
# - Hard refresh: Cmd+Option+E then Cmd+R (Safari)
# - Clear localStorage: localStorage.removeItem("physician_session")
```

### Build Fails

```bash
# Test locally first
cd client
npm run build

# Check TypeScript errors
npx tsc --noEmit

# Common causes:
# - Missing imports
# - Type mismatches
# - Unused variables (strict mode)
```

## Critical URLs

| What | URL |
|------|-----|
| Convex (DEV - USE THIS) | `https://enchanted-terrier-633.convex.cloud` |
| Convex (PROD - EMPTY) | `https://necessary-gnat-882.convex.cloud` |
| Convex Dashboard | `https://dashboard.convex.dev` |
| Vercel Dashboard | `https://vercel.com/dashboard` |
| Clerk Dashboard | `https://dashboard.clerk.com` |

## Quick Verification Commands

```bash
# Check Vercel env
cd client
npx vercel env ls production

# Check local env
cat .env.local | grep CONVEX

# Test local build
npm run build

# Deploy with force (skip cache)
npx vercel --prod --force

# View recent deployments
npx vercel ls

# View logs
npx vercel logs
```

## Emergency Rollback

```bash
cd client

# List deployments
npx vercel ls

# Rollback to previous
npx vercel rollback [previous-url]

# Or promote specific deployment
npx vercel promote [deployment-url]
```

## Session Management

**Where sessions are stored:**
- Browser: `localStorage.physician_session`
- Database: `physician_sessions` table in Convex

**When to clear:**
- After switching Convex instances
- After "Invalid session token" errors
- After 24 hours (auto-expires)

**How to clear:**
```javascript
// Run in browser console
localStorage.removeItem("physician_session")
location.reload()
```

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "All Patients (0)" | Wrong Convex URL | Use `enchanted-terrier-633` |
| "Invalid session token" | Stale localStorage | Clear `physician_session` |
| "Could not find public function" | Wrong API path | Check function namespace |
| "Unauthenticated" | No session or expired | Re-login with master password |
| Build failed | Type errors | Run `npx tsc --noEmit` |

## Deployment Flow

1. **Make code changes** in `/client/src/`
2. **Test locally**: `npm run build` (must succeed)
3. **Deploy**: `npx vercel --prod --force`
4. **Wait** for build to complete (2-3 min)
5. **Verify env vars**: Must use `enchanted-terrier-633`
6. **Test deployment**:
   - Hard refresh browser
   - Clear localStorage if needed
   - Log in with master password
   - Check patient count > 0
   - Click on patient → verify no errors

## Key Configuration Files

| File | What to Check |
|------|---------------|
| `client/.env.local` | `CONVEX_DEPLOYMENT=dev:enchanted-terrier-633` |
| `ZoeSleep/ZoeSleep/ConvexManager.swift` | `deploymentUrl` must use `enchanted-terrier-633` |
| Vercel env vars | `NEXT_PUBLIC_CONVEX_URL` must use `enchanted-terrier-633` |

---

**Full documentation:** See [`DEPLOY.md`](./DEPLOY.md) for detailed explanations
