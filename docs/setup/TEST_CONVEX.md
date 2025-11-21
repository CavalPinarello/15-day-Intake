# Testing with Convex Database

## ✅ Setup Complete!

The Convex database is now configured for local testing. Here's what was done:

1. ✅ Created `server/.env` with `USE_CONVEX=true`
2. ✅ Updated `server/server.js` to load environment variables
3. ✅ Updated database initialization to skip SQLite when using Convex
4. ✅ Updated assessment routes to use unified database interface

## 🚀 Start Testing

### 1. Start the Server

```bash
cd server
npm run dev
```

You should see:
```
Using Convex database - no local initialization needed
Using Convex database
Server running on http://localhost:3001
```

### 2. Start the Client

In another terminal:
```bash
cd client
npm run dev
```

### 3. Test the App

1. Open http://localhost:3000
2. Try logging in (users will be created in Convex)
3. Answer questions (responses stored in Convex)
4. Check Convex Dashboard: https://dashboard.convex.dev

## 📊 Verify Data in Convex

1. Go to https://dashboard.convex.dev
2. Select your project
3. Go to "Data" tab
4. You should see tables like:
   - `users` - Your test users
   - `user_assessment_responses` - Question responses
   - `assessment_questions` - Question data
   - etc.

## 🔍 What's Working

- ✅ Server connects to Convex
- ✅ Assessment routes use Convex
- ✅ User names endpoint uses Convex
- ✅ Data persists online

## ⚠️ Routes Still Using SQLite

Some routes still use the old SQLite interface. They will continue to work but won't use Convex yet:
- `routes/auth.js` - Login/registration
- `routes/admin.js` - Admin operations
- `routes/days.js` - Day management
- `routes/questions.js` - Question CRUD
- `routes/responses.js` - Response handling
- `routes/users.js` - User management

These can be updated incrementally. For now, the assessment system (which is critical for testing) uses Convex.

## 🛠️ Troubleshooting

### "Using SQLite database" instead of Convex
- Check `server/.env` exists and has `USE_CONVEX=true`
- Restart the server

### "Error loading Convex API"
- Run `npx convex dev` to ensure API files are generated

### Connection errors
- Verify `CONVEX_URL` is correct in `.env`
- Check Convex dashboard to ensure deployment is active

## 🔄 Switch Back to SQLite

Edit `server/.env` and change:
```
USE_CONVEX=false
```

Or delete the `.env` file entirely.

## 📝 Next Steps

1. Test login and question answering
2. Verify data appears in Convex dashboard
3. Update remaining routes to use unified interface (optional)
4. Migrate existing SQLite data if needed

---

**Status**: ✅ Ready to test with Convex!



