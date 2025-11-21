# Deployment Guide

## Current Database Location

**Development**: `server/database/zoe.db` (SQLite - 462KB)  
**Status**: ✅ Already in `.gitignore` (won't be committed to GitHub)

---

## Deployment Options

### Option 1: Vercel + Vercel Postgres (Recommended)

**Best for**: Full-stack deployment on Vercel

**Pros:**
- Integrated with Vercel
- Automatic scaling
- Built-in connection pooling
- Free tier available

**Setup:**
1. Add Vercel Postgres to your Vercel project
2. Database adapter automatically uses PostgreSQL in production
3. SQLite still used in development

### Option 2: Vercel Frontend + Railway Backend

**Best for**: Separate frontend/backend deployment

**Pros:**
- Railway supports persistent databases
- Can use SQLite or PostgreSQL
- Easy deployment

**Setup:**
1. Deploy backend to Railway
2. Deploy frontend to Vercel
3. Connect via API

### Option 3: Vercel Frontend + Supabase Backend

**Best for**: Using Supabase for database + auth

**Pros:**
- Supabase provides PostgreSQL + auth
- Real-time features
- Free tier available

---

## Quick Setup: Vercel + Vercel Postgres

### Step 1: Prepare for GitHub

The database file is already in `.gitignore`, so it won't be committed. Let's prepare the repo:

```bash
# Check what will be committed
git status

# The database file should NOT appear (it's in .gitignore)
```

### Step 2: Create Database Adapter

We'll create an adapter that supports both SQLite (dev) and PostgreSQL (prod).

### Step 3: Deploy to Vercel

1. Push to GitHub
2. Connect GitHub repo to Vercel
3. Add Vercel Postgres database
4. Set environment variables
5. Deploy!

---

## Database Migration Strategy

The system will:
- Use **SQLite** in development (local)
- Use **PostgreSQL** in production (Vercel Postgres)
- Same schema, different database engine
- Automatic migration on first deploy

---

## Next Steps

I'll create:
1. Database adapter (SQLite ↔ PostgreSQL)
2. Migration scripts
3. Environment configuration
4. Vercel configuration files
5. GitHub setup guide

Ready to proceed?




