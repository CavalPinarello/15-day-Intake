# Troubleshooting Guide

## Issues and Solutions

### 1. Questions Not Showing Up

**Problem**: Questions exist in database but don't appear in the UI.

**Possible Causes**:
- Day IDs don't match between questions and days
- API endpoints not returning data correctly
- Frontend not calling API correctly
- CORS issues preventing API calls

**Solutions**:

1. **Verify Database**:
   ```bash
   cd server
   sqlite3 database/zoe.db "SELECT q.id, q.day_id, d.day_number FROM questions q JOIN days d ON q.day_id = d.id;"
   ```

2. **Test API Endpoints**:
   ```bash
   # Test health
   curl http://localhost:3001/api/health
   
   # Test days
   curl http://localhost:3001/api/days
   
   # Test questions for Day 1
   curl http://localhost:3001/api/admin/days/43/questions
   ```

3. **Check Browser Console**:
   - Open browser DevTools (F12)
   - Check Console tab for errors
   - Check Network tab for failed API calls

4. **Use API Test Page**:
   - Visit http://localhost:3000/api-test
   - This will test all API connections
   - Check for any errors

### 2. Admin Panel Can't Access Backend

**Problem**: Admin panel shows errors when loading questions.

**Possible Causes**:
- Backend server not running
- CORS issues
- Wrong API URL
- Network connectivity issues

**Solutions**:

1. **Verify Backend is Running**:
   ```bash
   curl http://localhost:3001/api/health
   ```
   Should return: `{"status":"ok","message":"ZOE API Server is running"}`

2. **Check Server Logs**:
   - Look at the terminal where `npm run dev` is running
   - Check for error messages
   - Verify requests are being logged

3. **Check CORS Settings**:
   - Backend should have CORS enabled for `http://localhost:3000`
   - Check `server/server.js` for CORS configuration

4. **Verify API URL**:
   - Check browser Network tab
   - Verify API calls are going to `http://localhost:3001/api`
   - Check for CORS errors in console

### 3. Database Issues

**Problem**: Data not persisting or incorrect data.

**Solutions**:

1. **Re-seed Database**:
   ```bash
   cd server
   npm run seed
   ```

2. **Check Database File**:
   ```bash
   ls -la server/database/zoe.db
   ```

3. **Verify Database Schema**:
   ```bash
   sqlite3 server/database/zoe.db ".schema"
   ```

### 4. Frontend Not Loading

**Problem**: Frontend shows errors or blank page.

**Solutions**:

1. **Clear Browser Cache**:
   - Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
   - Or clear browser cache

2. **Check Next.js Dev Server**:
   - Verify it's running on port 3000
   - Check for compilation errors
   - Restart if needed: `cd client && npm run dev`

3. **Check Environment Variables**:
   - Verify `NEXT_PUBLIC_API_URL` is set (or using default)
   - Default should be `http://localhost:3001/api`

### 5. Questions Linked to Wrong Days

**Problem**: Questions appear on wrong days.

**Solution**:
- Run the fix script:
  ```bash
  cd server
  node scripts/fix-day-ids.js
  ```
- Or manually update:
  ```sql
  UPDATE questions SET day_id = (SELECT id FROM days WHERE day_number = 1) 
  WHERE id IN (1, 5, 6, 7);
  ```

## Quick Diagnostic Steps

1. **Check Backend**:
   ```bash
   curl http://localhost:3001/api/health
   ```

2. **Check Frontend**:
   - Open http://localhost:3000
   - Check browser console for errors

3. **Check Database**:
   ```bash
   cd server
   sqlite3 database/zoe.db "SELECT COUNT(*) FROM questions; SELECT COUNT(*) FROM days;"
   ```

4. **Test API**:
   - Visit http://localhost:3000/api-test
   - Review test results

5. **Check Logs**:
   - Backend server logs (terminal)
   - Browser console (F12)
   - Network tab (F12)

## Common Error Messages

### "Failed to fetch"
- Backend server not running
- CORS issue
- Wrong API URL

### "User or day not found"
- Database not seeded
- User doesn't exist
- Day doesn't exist

### "No questions found"
- Questions not linked to days
- Wrong day_id in questions table
- Database not seeded

### CORS Error
- Backend CORS not configured
- Wrong origin in CORS settings
- Check server/server.js CORS configuration

## Reset Everything

If nothing works, reset the database:

```bash
cd server
rm database/zoe.db
npm run seed
```

Then restart both servers:
```bash
# Terminal 1
cd server
npm run dev

# Terminal 2
cd client
npm run dev
```

