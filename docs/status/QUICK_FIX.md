# Quick Fix Guide

## Immediate Actions to Fix Issues

### 1. Restart Both Servers

**Stop current servers** (Ctrl+C in both terminals), then:

```bash
# Terminal 1 - Backend
cd server
npm run dev

# Terminal 2 - Frontend  
cd client
npm run dev
```

### 2. Verify Backend is Running

```bash
curl http://localhost:3001/api/health
```

Should return: `{"status":"ok","message":"ZOE API Server is running"}`

### 3. Test API Endpoints

```bash
# Get days
curl http://localhost:3001/api/days | python3 -m json.tool | head -20

# Get questions for Day 1 (replace 183 with actual day ID from above)
curl http://localhost:3001/api/days/1 | python3 -m json.tool
```

### 4. Use API Test Page

1. Open browser: http://localhost:3000/api-test
2. This will test all API connections
3. Check for any errors in the results

### 5. Clear Browser Cache

- Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
- Or clear browser cache completely

### 6. Check Browser Console

1. Open http://localhost:3000
2. Press F12 (DevTools)
3. Go to Console tab
4. Look for errors (red messages)
5. Go to Network tab
6. Try accessing admin panel
7. Check if API calls are being made
8. Check status codes (200 = success, 404/500 = error)

## Common Issues

### Backend Not Running
**Symptom**: All API calls fail
**Fix**: Start backend server in Terminal 1

### CORS Error
**Symptom**: CORS error in browser console
**Fix**: Restart backend server (CORS config updated)

### Questions Not Showing
**Symptom**: Admin panel shows "No questions"
**Fix**: 
1. Check browser console for errors
2. Verify API is accessible: `curl http://localhost:3001/api/admin/days/183/questions`
3. Check Network tab in browser DevTools

### Wrong Day IDs
**Symptom**: Questions linked to wrong days
**Fix**: Run verification script:
```bash
cd server
node scripts/verify-and-fix.js
```

## Debugging Steps

1. **Check Backend Logs**: Look at terminal where backend is running
2. **Check Frontend Logs**: Look at terminal where frontend is running  
3. **Check Browser Console**: F12 → Console tab
4. **Check Network Tab**: F12 → Network tab → Filter by "api"
5. **Test API Directly**: Use curl commands above

## What to Check

- [ ] Backend server running on port 3001
- [ ] Frontend server running on port 3000
- [ ] Database has 7 questions and 14 days
- [ ] API health check returns OK
- [ ] Browser can access http://localhost:3000
- [ ] No CORS errors in browser console
- [ ] API calls visible in Network tab
- [ ] Questions visible in API test page

## If Nothing Works

1. **Reset Database**:
   ```bash
   cd server
   rm database/zoe.db
   npm run seed
   ```

2. **Restart Everything**:
   ```bash
   # Kill all node processes
   pkill node
   
   # Restart backend
   cd server
   npm run dev
   
   # Restart frontend (new terminal)
   cd client
   npm run dev
   ```

3. **Check Ports**:
   ```bash
   lsof -i :3001  # Backend
   lsof -i :3000  # Frontend
   ```

4. **Verify Files**:
   - Check `server/database/zoe.db` exists
   - Check `server/server.js` has CORS enabled
   - Check `client/lib/api.ts` has correct API URL

## Still Having Issues?

Please provide:
1. Output of `curl http://localhost:3001/api/health`
2. Output of `curl http://localhost:3001/api/days`
3. Screenshot of browser console errors
4. Screenshot of Network tab (showing API calls)
5. Backend server logs
6. Frontend server logs

This will help identify the exact problem.

