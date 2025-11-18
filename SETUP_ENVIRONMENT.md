# Environment Setup Instructions

## ✅ Completed
- Convex provider configured in Next.js app
- React client ready to use Convex hooks

## 🔧 Manual Setup Required

### Step 1: Create `.env.local` in Client Directory

Navigate to the client folder and create a file named `.env.local`:

```bash
cd client
```

Create a file named `.env.local` with this exact content:

```env
NEXT_PUBLIC_CONVEX_URL=https://enchanted-terrier-633.convex.cloud
```

**Important:** 
- The file must be named exactly `.env.local` (with the dot at the beginning)
- It should be in the `client` folder, not the root folder
- This file is already in `.gitignore` so it won't be committed

### Step 2: Set OpenAI API Key in Convex

You need to set your OpenAI API key in the Convex dashboard:

1. **Go to Convex Dashboard:**
   ```
   https://dashboard.convex.dev
   ```

2. **Select Your Project:**
   - Look for "enchanted-terrier-633" or your project name

3. **Navigate to Settings → Environment Variables**

4. **Add New Variable:**
   - Click "Add Environment Variable"
   - Name: `OPENAI_API_KEY`
   - Value: `your-openai-api-key-here`
   - Click "Save"

**Alternative (Using Terminal):**
```bash
cd /Users/martinkawalski/Documents/1.\ Projects/15-Day\ Test
npx convex env set OPENAI_API_KEY "your-openai-api-key-here"
```

### Step 3: Verify Setup

1. **Check Convex Connection:**
   ```bash
   cd client
   npm run dev
   ```

2. **Look for the console output** - should see no errors about Convex URL

3. **Test the physician dashboard:**
   - Go to `http://localhost:3000/physician-dashboard`
   - Login with username "physician"

### Step 4: Deploy Convex Functions

Make sure your Convex functions are deployed:

```bash
cd /Users/martinkawalski/Documents/1.\ Projects/15-Day\ Test
npx convex dev
```

This will:
- Deploy all your Convex functions (physician.ts, llm.ts, etc.)
- Keep watching for changes
- Show deployment URL

## Verification Checklist

- [ ] `.env.local` file created in `client` folder with `NEXT_PUBLIC_CONVEX_URL`
- [ ] OpenAI API key set in Convex dashboard
- [ ] Convex dev server running (`npx convex dev`)
- [ ] Next.js dev server running (`cd client && npm run dev`)
- [ ] No console errors about missing Convex URL
- [ ] Can access physician dashboard

## Troubleshooting

### "Cannot find NEXT_PUBLIC_CONVEX_URL"
- Make sure `.env.local` is in the `client` folder (not root)
- Restart the Next.js dev server after creating the file
- Check the file is named exactly `.env.local` (with the dot)

### "OpenAI API error"
- Verify the API key is set in Convex dashboard
- Check the key is correct (starts with `sk-proj-`)
- Redeploy functions with `npx convex dev`

### "Convex functions not found"
- Run `npx convex dev` to deploy functions
- Check the Convex dashboard shows your functions
- Verify you're on the correct deployment

## Next Steps

Once environment is set up:

1. The physician dashboard should be fully functional
2. LLM analysis will work with your OpenAI key
3. All Convex queries and mutations will connect to your deployment

See `PHYSICIAN_DASHBOARD_IMPLEMENTATION.md` for usage instructions.



