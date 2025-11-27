# TestFlight Testing Instructions for App Store Connect

## What to Test

ZOE Sleep 360 is a 15-day adaptive sleep coaching platform that conducts personalized clinical sleep assessments.

---

## Sign-In Information

**Test Account:**
- Username: `user1`
- Password: `1`

(Alternative accounts: user2 through user10, all with password: 1)

---

## Testing Steps

### 1. Initial Setup
1. Launch the app and sign in with the test credentials above
2. You will see the main Dashboard showing your journey progress

### 2. Complete Daily Assessment
1. On the Dashboard, tap "Start Today's Tasks"
2. Complete the **Stanford Sleep Log** (5 quick questions about last night's sleep)
3. Continue to the **Daily Assessment** questions
4. Answer all questions - use Next/Back buttons to navigate
5. Upon completion, you'll return to the Dashboard with updated progress

### 3. Test HealthKit Integration (Optional)
1. On the Dashboard, tap "Connect Apple Health"
2. Grant permissions when iOS prompts you
3. Verify the connection status shows as connected

### 4. View Journey Progress
1. Tap "Journey Overview" to see all 15 days
2. Completed days show green checkmarks
3. Current day is highlighted

---

## Key Features to Verify

- Sign in/sign out functionality
- Question navigation (back/next)
- Various input types: sliders, time pickers, yes/no, multi-select
- Progress tracking on Dashboard
- HealthKit permission request and connection
- Sleep Diary History viewing

---

## Apple Watch Companion (If Available)

1. Install the Watch app from your paired iPhone
2. Open the Watch app to see current day status
3. Questions can be answered on either device and sync automatically

---

## Notes

- Each day takes approximately 7-15 minutes to complete
- The app adapts questions based on your responses (Days 6-15 vary per user)
- Internet connection required for all functionality
- Data syncs in real-time across devices
