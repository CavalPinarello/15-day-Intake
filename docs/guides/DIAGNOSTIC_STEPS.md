# Diagnostic Steps - Immediate Actions

## Step 1: Verify Backend is Running

Open a new terminal and run:
```bash
curl http://localhost:3001/api/health
```

Expected output: `{"status":"ok","message":"ZOE API Server is running"}`

If this fails, the backend server is not running. Start it with:
```bash
cd server
npm run dev
```

## Step 2: Verify Database Has Data

```bash
cd server
sqlite3 database/zoe.db "SELECT COUNT(*) FROM questions; SELECT COUNT(*) FROM days;"
```

Expected: 7 questions, 14 days

## Step 3: Test API Endpoints Directly

```bash
# Get all days
curl http://localhost:3001/api/days

# Get Day 1 questions (replace 43 with actual day ID)
curl http://localhost:3001/api/days/1

# Get admin questions for Day 1
curl http://localhost:3001/api/admin/days/43/questions
```

## Step 4: Check Browser Console

1. Open http://localhost:3000 in your browser
2. Press F12 to open DevTools
3. Go to Console tab
4. Look for any red error messages
5. Go to Network tab
6. Try loading the admin panel
7. Check if API calls are being made
8. Check if API calls are failing (red entries)

## Step 5: Use API Test Page

1. Visit http://localhost:3000/api-test
2. This page will test all API connections
3. Check the results for any errors
4. Share the error messages if any

## Step 6: Check CORS Issues

If you see CORS errors in the browser console:
1. Verify backend server has CORS enabled
2. Check `server/server.js` - should have `app.use(cors(...))`
3. Restart the backend server

## Step 7: Verify API URL in Frontend

1. Open browser DevTools (F12)
2. Go to Console tab
3. Type: `process.env.NEXT_PUBLIC_API_URL`
4. Or check the Network tab to see what URL is being called
5. Should be: `http://localhost:3001/api`

## Common Issues and Quick Fixes

### Issue: "Cannot GET /api/admin/days/..."
**Fix**: Backend server not running or route not registered

### Issue: CORS error
**Fix**: Restart backend server (CORS config was updated)

### Issue: Questions not showing
**Fix**: 
1. Verify questions exist: `sqlite3 server/database/zoe.db "SELECT * FROM questions;"`
2. Verify questions are linked to days
3. Run: `cd server && npm run seed`

### Issue: Admin panel shows loading forever
**Fix**: Check browser console for errors, verify API is accessible

## Next Steps

After running these diagnostics, please share:
1. Output of `curl http://localhost:3001/api/health`
2. Output of `curl http://localhost:3001/api/days`
3. Any errors from browser console
4. Any errors from the API test page (http://localhost:3000/api-test)

This will help identify the exact issue.

