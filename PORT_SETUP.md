# Port Configuration Guide

## Quick Setup

The app now uses environment variables for port configuration, so you can easily change ports without modifying code.

### 1. Configure Backend Port

Edit `server/.env`:
```env
PORT=3002
```

### 2. Configure Frontend API URL

Edit `client/.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:3002/api
```

### 3. Restart Both Servers

**Terminal 1 (Backend):**
```bash
cd server
npm run dev
```

**Terminal 2 (Frontend):**
```bash
cd client
npm run dev
```

## Default Ports

- **Backend**: 3001 (configurable via `server/.env`)
- **Frontend**: 3000 (Next.js default)

## Changing Ports

### Change Backend Port

1. Edit `server/.env`
2. Change `PORT=3002` to your desired port
3. Restart the server
4. Update `NEXT_PUBLIC_API_URL` in `client/.env.local` to match

### Change Frontend Port

```bash
cd client
PORT=3001 npm run dev
```

## Tips

- ✅ The server will tell you which port it's running on when it starts
- ✅ Make sure both `.env` files match (backend PORT = frontend API_URL port)
- ✅ Restart the frontend after changing `.env.local` for changes to take effect
- ✅ The backend will use port 3001 by default if `PORT` is not set

## Current Configuration

Based on your `.env` files:
- Backend: Port 3002
- Frontend API: http://localhost:3002/api



