# 🚀 Quick Start: Test Locally with Convex

## ✅ Setup Complete!

Everything is configured to test your app locally with the Convex online database.

## 🎯 Start Testing (2 Steps)

### Step 1: Start Server
```bash
cd server
npm run dev
```

**Expected output:**
```
Using Convex database - no local initialization needed
Using Convex database
Server running on http://localhost:3001
```

### Step 2: Start Client
In a **new terminal**:
```bash
cd client
npm run dev
```

Then open: **http://localhost:3000**

## ✅ What's Configured

- ✅ `server/.env` created with `USE_CONVEX=true`
- ✅ Server loads environment variables automatically
- ✅ Database interface switches to Convex when `USE_CONVEX=true`
- ✅ Assessment routes updated to use Convex
- ✅ All data stored online in Convex cloud

## 📊 View Your Data

Visit Convex Dashboard:
- **URL**: https://dashboard.convex.dev
- **Project**: enchanted-terrier-633
- **Tables**: Check "Data" tab to see users, responses, etc.

## 🧪 Test It

1. **Login** - Create a test user (stored in Convex)
2. **Answer Questions** - Responses saved to Convex
3. **Check Dashboard** - See data appear in real-time

## 🔄 Switch Back to SQLite

Edit `server/.env`:
```
USE_CONVEX=false
```

Or delete `server/.env` file.

## ⚠️ Note

Some routes (auth, admin, etc.) still use SQLite. The assessment system (questions, responses) uses Convex. This is enough to test the core functionality!

---

**Ready to test!** 🎉



