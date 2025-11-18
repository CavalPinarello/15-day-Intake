# 🖥️ Server Status

## ✅ Servers Running

### Backend Server
- **Status**: ✅ Running on port 3001
- **Health Check**: ✅ Responding
- **Database**: Configured for Convex (check `server/.env`)

### Frontend Client  
- **Status**: ✅ Running on port 3000
- **URL**: http://localhost:3000

## 🔧 Configuration

The server is configured to use Convex when `USE_CONVEX=true` is set in `server/.env`.

## 🧪 Testing

### Open the App
Visit: **http://localhost:3000**

You'll be redirected to the login page.

### Test Login
- Quick login: Click "User 1", "User 2", etc.
- Manual login: username `user1`, password `1`

### What to Test
1. **Login** - Users are created/stored in Convex
2. **Answer Questions** - Responses saved to Convex
3. **View Data** - Check Convex dashboard: https://dashboard.convex.dev

## 📊 Verify Convex Connection

The server should show in logs:
```
Using Convex database - no local initialization needed
Using Convex database
```

If you see "Using SQLite database", the `.env` file isn't being read correctly.

## 🔄 Restart Server (if needed)

If you make changes to the code:
```bash
# Stop the server (Ctrl+C)
# Then restart:
cd server
npm run dev
```

Nodemon should auto-reload, but if issues persist, restart manually.

## ✅ Ready to Test!

Open http://localhost:3000 and start testing! 🚀
