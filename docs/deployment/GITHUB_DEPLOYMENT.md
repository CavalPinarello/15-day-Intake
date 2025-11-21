# GitHub & Vercel Deployment Guide

## Current Status

✅ **Database**: SQLite at `server/database/zoe.db` (462KB)  
✅ **Git Ignore**: Database file is already excluded from Git  
✅ **Ready**: Code is ready to push to GitHub

---

## Step 1: Prepare Repository

### Check Git Status

```bash
# Check what will be committed
git status

# The database file should NOT appear (it's in .gitignore)
# Only code files should be listed
```

### Files That Will Be Committed

✅ **Will be committed:**
- All source code files
- Configuration files
- Documentation
- Package files

❌ **Will NOT be committed** (already in `.gitignore`):
- `server/database/*.db` - Database files
- `node_modules/` - Dependencies
- `.env` - Environment variables
- Build artifacts

---

## Step 2: Push to GitHub

### Initialize Git (if not already done)

```bash
# Check if git is initialized
git status

# If not initialized:
git init
git add .
git commit -m "Initial commit: Complete ZOE Sleep Platform with all components"
```

### Create GitHub Repository

1. Go to https://github.com/new
2. Create a new repository (e.g., `zoe-sleep-platform`)
3. **Don't** initialize with README (we already have one)

### Push to GitHub

```bash
# Add remote (replace with your repo URL)
git remote add origin https://github.com/YOUR_USERNAME/zoe-sleep-platform.git

# Push to GitHub
git branch -M main
git push -u origin main
```

---

## Step 3: Deploy to Vercel

### Option A: Vercel Frontend + Vercel Postgres (Recommended)

#### 1. Deploy Frontend to Vercel

1. Go to https://vercel.com
2. Click "New Project"
3. Import your GitHub repository
4. Configure:
   - **Framework Preset**: Next.js
   - **Root Directory**: `client`
   - **Build Command**: `npm run build`
   - **Output Directory**: `.next`

#### 2. Add Vercel Postgres Database

1. In your Vercel project, go to **Storage** tab
2. Click **Create Database** → **Postgres**
3. Choose a name (e.g., `zoe-db`)
4. Select region closest to your users
5. Click **Create**

#### 3. Configure Environment Variables

In Vercel project settings → **Environment Variables**, add:

```
DATABASE_URL=<automatically set by Vercel Postgres>
POSTGRES_URL=<automatically set by Vercel Postgres>
JWT_SECRET=<generate a secure random string>
JWT_REFRESH_SECRET=<generate a secure random string>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
NEXT_PUBLIC_API_URL=https://your-api.vercel.app/api
NODE_ENV=production
```

#### 4. Deploy Backend API

Create a separate Vercel project for the API:

1. **New Project** → Import same GitHub repo
2. Configure:
   - **Framework Preset**: Other
   - **Root Directory**: `server`
   - **Build Command**: (leave empty or `npm install`)
   - **Output Directory**: (leave empty)
   - **Install Command**: `npm install`

3. Add `vercel.json` in server directory:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "server.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "server.js"
    }
  ]
}
```

### Option B: Railway Backend + Vercel Frontend

#### 1. Deploy Backend to Railway

1. Go to https://railway.app
2. Click **New Project** → **Deploy from GitHub**
3. Select your repository
4. Configure:
   - **Root Directory**: `server`
   - **Start Command**: `npm start`
5. Add PostgreSQL database:
   - Click **New** → **Database** → **PostgreSQL**
6. Set environment variables in Railway

#### 2. Deploy Frontend to Vercel

1. Deploy frontend as described in Option A
2. Set `NEXT_PUBLIC_API_URL` to your Railway API URL

---

## Step 4: Database Migration

### Automatic Migration

The database adapter will automatically:
1. Detect PostgreSQL connection string
2. Use PostgreSQL in production
3. Use SQLite in development
4. Run schema initialization on first deploy

### Manual Migration (if needed)

```bash
# Connect to Vercel Postgres
vercel env pull .env.local

# Run migration script
cd server
node scripts/migrate-to-postgres.js
```

---

## Step 5: Verify Deployment

### Test API

```bash
# Test health endpoint
curl https://your-api.vercel.app/api/health-check

# Test login
curl -X POST https://your-api.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"1"}'
```

### Test Frontend

1. Visit your Vercel frontend URL
2. Login should work
3. API calls should connect to backend

---

## Environment Variables Reference

### Development (.env)

```env
# Leave DATABASE_URL empty for SQLite
JWT_SECRET=dev-secret-key
JWT_REFRESH_SECRET=dev-refresh-secret
PORT=3001
NODE_ENV=development
NEXT_PUBLIC_API_URL=http://localhost:3001/api
```

### Production (Vercel)

```env
# Automatically set by Vercel Postgres
DATABASE_URL=postgres://...
POSTGRES_URL=postgres://...

# Set manually
JWT_SECRET=<strong-random-secret>
JWT_REFRESH_SECRET=<strong-random-secret>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
NODE_ENV=production
NEXT_PUBLIC_API_URL=https://your-api.vercel.app/api
```

---

## Troubleshooting

### Database Connection Issues

**Error**: "Cannot connect to database"

**Solution**:
1. Check `DATABASE_URL` is set in Vercel
2. Verify Vercel Postgres is running
3. Check database adapter is using PostgreSQL

### CORS Issues

**Error**: "CORS policy blocked"

**Solution**:
1. Update CORS in `server/server.js` to include Vercel domain
2. Set `NEXT_PUBLIC_API_URL` correctly

### Build Failures

**Error**: Build fails on Vercel

**Solution**:
1. Check `package.json` scripts
2. Verify all dependencies are listed
3. Check build logs in Vercel dashboard

---

## Quick Deploy Checklist

- [ ] Code pushed to GitHub
- [ ] Database file NOT in Git (check `.gitignore`)
- [ ] Vercel Postgres database created
- [ ] Environment variables set in Vercel
- [ ] Frontend deployed to Vercel
- [ ] Backend API deployed (Vercel or Railway)
- [ ] Database migration completed
- [ ] API endpoints tested
- [ ] Frontend connects to API

---

## Next Steps After Deployment

1. **Seed Production Database**:
   - Create admin user
   - Add initial data
   - Set up coaches

2. **Monitor**:
   - Check Vercel logs
   - Monitor database usage
   - Set up error tracking

3. **Scale**:
   - Upgrade Vercel Postgres if needed
   - Add caching (Redis)
   - Optimize queries

---

## Cost Estimates

### Vercel (Free Tier)
- Frontend: Free (hobby plan)
- API Functions: Free (within limits)
- **Vercel Postgres**: Free tier available (limited storage)

### Railway (Alternative)
- Backend: $5/month (hobby plan)
- PostgreSQL: Included or $5/month

### Total Estimated Cost
- **Free tier**: $0/month (with limitations)
- **Production**: $10-20/month (with scaling)

---

## Support

If you encounter issues:
1. Check Vercel deployment logs
2. Check database connection
3. Verify environment variables
4. Test API endpoints directly

**Ready to deploy!** 🚀




