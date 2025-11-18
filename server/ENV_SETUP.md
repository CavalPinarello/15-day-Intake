# Environment Setup for Convex

## Quick Setup

To test locally with Convex online database, create a `.env` file in the `server/` directory:

```bash
cd server
```

Create `.env` file with:

```
USE_CONVEX=true
CONVEX_URL=https://enchanted-terrier-633.convex.cloud
NEXT_PUBLIC_CONVEX_URL=https://enchanted-terrier-633.convex.cloud
```

## Alternative: Set Environment Variables

If you can't create a `.env` file, set environment variables before starting the server:

```bash
export USE_CONVEX=true
export CONVEX_URL=https://enchanted-terrier-633.convex.cloud
export NEXT_PUBLIC_CONVEX_URL=https://enchanted-terrier-633.convex.cloud

cd server
npm run dev
```

## Verify It's Working

When you start the server, you should see:
```
Using Convex database
Server running on http://localhost:3001
```

If you see "Using SQLite database", the environment variable isn't set correctly.

## Switch Back to SQLite

Remove the environment variable or set it to false:
```bash
unset USE_CONVEX
# or
export USE_CONVEX=false
```



