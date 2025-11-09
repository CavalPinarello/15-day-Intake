# ZOE Sleep Coaching Platform - 14-Day Onboarding Journey

## Project Overview

This is the implementation of Component 1: 14-Day Onboarding Journey (SLE-130) from the ZOE Sleep Coaching Platform. It's built for rapid prototyping with features for testing and admin management.

## Features

- ✅ 14-day onboarding journey with themed daily experiences
- ✅ 9 different question input types (text, textarea, number, select, radio, checkbox, scale, date, time)
- ✅ Day advance feature for rapid testing
- ✅ Admin interface for managing and rearranging questions
- ✅ Progress tracking
- ✅ Hard-coded users (user1-user10) with password "1"
- ✅ Reusable backend architecture for other components

## Tech Stack

### Backend
- Node.js + Express
- SQLite (easily migratable to PostgreSQL)
- RESTful API

### Frontend
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- React

## Setup Instructions

### 1. Install Dependencies

```bash
# Install root dependencies
npm install

# Install all dependencies (root, server, client)
npm run install:all
```

### 2. Initialize Database and Seed Sample Questions

```bash
cd server
npm run seed
```

This will:
- Create the SQLite database
- Initialize 14 days
- Create 10 test users (user1-user10)
- Add sample questions for Day 1 and Day 2

### 3. Start the Backend Server

```bash
cd server
npm run dev
```

The server will run on http://localhost:3001

### 4. Start the Frontend

In a new terminal:

```bash
cd client
npm run dev
```

The client will run on http://localhost:3000

### 5. Or Run Both Simultaneously

From the root directory:

```bash
npm run dev
```

This will start both the server and client concurrently.

## Usage

### Login
- Username: `user1` through `user10`
- Password: `1`

### User Journey
1. Login with any user (user1-user10)
2. You'll see your current day in the onboarding journey
3. Answer questions for the day
4. Use the "⏩ Advance Day" button to quickly test multiple days
5. Progress is automatically saved

### Admin Panel
1. Click "Admin Panel" from the login page
2. Select a day from the dropdown
3. Add, edit, delete, or reorder questions
4. Drag and drop questions to rearrange them
5. Questions support 9 different input types

## Question Types

1. **Text** - Single-line text input
2. **Textarea** - Multi-line text input
3. **Number** - Numeric input
4. **Select** - Dropdown selection
5. **Radio** - Single choice from options
6. **Checkbox** - Multiple choice from options
7. **Scale** - Slider/scale input (1-10 by default)
8. **Date** - Date picker
9. **Time** - Time picker

## API Endpoints

### Auth
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user

### Days
- `GET /api/days` - Get all days
- `GET /api/days/:dayNumber` - Get specific day
- `GET /api/days/user/:userId/current` - Get user's current day

### Questions
- `GET /api/questions/day/:dayId` - Get questions for a day
- `POST /api/questions` - Create question
- `PUT /api/questions/:questionId` - Update question
- `DELETE /api/questions/:questionId` - Delete question

### Responses
- `POST /api/responses` - Save response
- `GET /api/responses/user/:userId/day/:dayId` - Get user responses for a day
- `POST /api/responses/user/:userId/day/:dayId/complete` - Mark day as completed

### Users
- `GET /api/users/:userId/progress` - Get user progress
- `POST /api/users/:userId/advance-day` - Advance to next day
- `POST /api/users/:userId/set-day` - Set user to specific day

### Admin
- `GET /api/admin/days/:dayId/questions` - Get questions for admin
- `POST /api/admin/days/:dayId/questions/reorder` - Reorder questions
- `POST /api/admin/days/:dayId/questions` - Create question
- `PUT /api/admin/questions/:questionId` - Update question
- `DELETE /api/admin/questions/:questionId` - Delete question

## Database Schema

The backend uses SQLite with the following tables:
- `users` - User accounts
- `days` - 14 days of the journey
- `questions` - Questions for each day
- `responses` - User responses to questions
- `user_progress` - User progress tracking

## Next Steps

This is a rapid prototyping version. For production, consider:
- Authentication system (currently hard-coded)
- PostgreSQL database migration
- Insight generation logic (42 insights)
- Conditional logic engine
- Celebration animations
- Notification scheduling
- Apple Health integration
- Swipeable card interface enhancements

## License

MIT

