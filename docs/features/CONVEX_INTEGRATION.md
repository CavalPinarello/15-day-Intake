# Convex Integration Guide

## ✅ What's Been Done

1. **Convex Schema Updated** - Added all missing tables:
   - `assessment_questions`
   - `assessment_modules`
   - `module_questions`
   - `day_modules`
   - `module_gateways`
   - `user_gateway_states`
   - `user_assessment_responses`
   - `sleep_diary_questions`

2. **Convex Functions Created** - All database operations have Convex functions:
   - `convex/users.ts` - User operations
   - `convex/days.ts` - Day operations
   - `convex/questions.ts` - Question operations
   - `convex/responses.ts` - Response operations
   - `convex/auth.ts` - Authentication operations
   - `convex/assessment.ts` - Assessment system operations

3. **Unified Database Interface** - Created `server/database/db.js` that supports both:
   - SQLite (development) - default
   - Convex (production) - when `USE_CONVEX=true`

4. **Convex Adapter** - Created `server/database/convexAdapter.js` that provides SQLite-like interface for Convex

## 🚀 Setup Steps

### Step 1: Deploy Convex Schema

```bash
cd "/Users/martinkawalski/Documents/1. Projects/15-Day Test"
npx convex dev
```

This will:
- Deploy the schema to Convex
- Generate API files
- Start the Convex dev server

### Step 2: Get Convex URL

After running `npx convex dev`, you'll see a Convex URL. Copy it and set it in your environment:

```bash
# In .env.local or server/.env
NEXT_PUBLIC_CONVEX_URL=https://your-deployment.convex.cloud
CONVEX_URL=https://your-deployment.convex.cloud
```

### Step 3: Enable Convex (Optional)

To use Convex instead of SQLite, set:

```bash
USE_CONVEX=true
```

Or in production:

```bash
NODE_ENV=production
```

## 📝 Migration Strategy

### Option 1: Use Both (Recommended for now)
- **Development**: SQLite (local, fast)
- **Production**: Convex (cloud, scalable)

Set `USE_CONVEX=true` only in production.

### Option 2: Full Migration to Convex
1. Deploy schema: `npx convex dev`
2. Migrate data from SQLite to Convex (see migration script below)
3. Set `USE_CONVEX=true`
4. Update all routes to use unified interface

## 🔄 Data Migration

To migrate existing SQLite data to Convex, you'll need to:

1. Export data from SQLite
2. Transform to Convex format
3. Import using Convex mutations

Example migration script structure:

```javascript
// scripts/migrate-to-convex.js
const { getDatabase } = require('../server/database/init');
const { getConvexAdapter } = require('../server/database/convexAdapter');

async function migrate() {
  const sqlite = getDatabase();
  const convex = getConvexAdapter();
  
  // Migrate users
  const users = await sqlite.all('SELECT * FROM users');
  for (const user of users) {
    await convex.createUser(user);
  }
  
  // Migrate days, questions, etc.
  // ...
}
```

## 🛠️ Updating Routes

Routes can now use the unified database interface:

```javascript
// Old way (SQLite only)
const { getDatabase } = require('../database/init');
const db = getDatabase();
db.get('SELECT * FROM users WHERE id = ?', [userId], callback);

// New way (works with both SQLite and Convex)
const { getDatabase } = require('../database/db');
const db = await getDatabase();
const user = await db.getUserById(userId);
```

## 📊 Current Status

### ✅ Routes Using Unified Interface
- Assessment routes (partially)
- Auth routes (can be updated)

### ⏳ Routes Still Using SQLite Directly
- `server/routes/auth.js`
- `server/routes/admin.js`
- `server/routes/days.js`
- `server/routes/questions.js`
- `server/routes/responses.js`
- `server/routes/users.js`

These can be updated incrementally to use the unified interface.

## 🧪 Testing

1. **Test with SQLite** (default):
   ```bash
   cd server
   npm run dev
   ```

2. **Test with Convex**:
   ```bash
   USE_CONVEX=true cd server && npm run dev
   ```

## 📚 Key Files

- `convex/schema.ts` - Convex database schema
- `convex/*.ts` - Convex functions (queries/mutations)
- `server/database/db.js` - Unified database interface
- `server/database/convexAdapter.js` - Convex adapter
- `server/database/init.js` - SQLite initialization (still used)

## 🎯 Next Steps

1. **Deploy Schema**: Run `npx convex dev`
2. **Set Environment**: Add `CONVEX_URL` to `.env.local`
3. **Test**: Verify Convex functions work
4. **Migrate Data**: Move existing SQLite data to Convex
5. **Update Routes**: Gradually update routes to use unified interface
6. **Enable Convex**: Set `USE_CONVEX=true` in production

## ⚠️ Important Notes

- Convex uses string IDs (`_id`), SQLite uses numeric IDs
- The adapter handles ID conversion automatically
- Some complex queries may need adjustment
- Gateway evaluation logic may need updates for Convex

## 🆘 Troubleshooting

### "Error loading Convex API"
- Run `npx convex dev` first to generate API files

### "Convex URL not found"
- Set `CONVEX_URL` or `NEXT_PUBLIC_CONVEX_URL` in environment
- Or use the default URL from `npx convex dev` output

### "Function not found"
- Make sure schema is deployed: `npx convex dev`
- Check function names match in `convex/_generated/api.js`

## 📞 Support

For Convex-specific issues, check:
- Convex Dashboard: https://dashboard.convex.dev
- Convex Docs: https://docs.convex.dev



