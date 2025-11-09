# Quick Start Guide

## Quick Setup (5 minutes)

### 1. Install Dependencies

```bash
npm run install:all
```

### 2. Initialize Database

```bash
cd server
npm run seed
```

This creates:
- SQLite database with schema
- 14 days initialized
- 10 test users (user1-user10, password: "1")
- Sample questions for Day 1 and Day 2

### 3. Start the Application

From the root directory:

```bash
npm run dev
```

This starts both:
- Backend server on http://localhost:3001
- Frontend client on http://localhost:3000

### 4. Login and Test

1. Open http://localhost:3000
2. Login with:
   - Username: `user1` (or user2-user10)
   - Password: `1`
3. Answer questions for Day 1
4. Use "⏩ Advance Day" button to test multiple days quickly
5. Visit Admin Panel to manage questions

## Admin Panel

1. Click "Admin Panel" from login page
2. Select a day from dropdown
3. Add/edit/delete questions
4. Drag and drop to reorder questions
5. Questions support 9 input types:
   - Text, Textarea, Number
   - Select, Radio, Checkbox
   - Scale/Slider, Date, Time

## Troubleshooting

### Database not found
Run `cd server && npm run seed` to initialize the database.

### Port already in use
Change ports in:
- Server: `server/server.js` (default: 3001)
- Client: `client/.env.local` (default: 3000)

### CORS errors
Make sure the server is running on port 3001 and client is configured correctly.

## Next Steps

- Add more questions via Admin Panel
- Customize day themes and colors
- Add conditional logic to questions
- Implement insight generation
- Add celebration animations

