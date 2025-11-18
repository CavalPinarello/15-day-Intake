# Physician Dashboard - Recent Changes

## ✅ Fixed Issues (Just Now)

### 1. Patient Names Showing as "Unknown" ✅
**Problem**: Patients without Sleep360 questionnaire responses showed "Unknown" name

**Solution**: Updated Convex queries to use username as fallback:
```typescript
name: nameResponse?.response_value || user.username
```

**Affected Files**:
- `convex/physician.ts` - Line 60 (getAllPatientsWithProgress)
- `convex/physician.ts` - Line 211 (getPatientDetails)

---

### 2. Physician User Appearing in Patient List ✅
**Problem**: The physician account appeared in their own patient list

**Solution**: Added role filter in `getAllPatientsWithProgress`:
```typescript
const patientUsers = users.filter(user => 
  user.role !== "physician" && user.role !== "admin"
);
```

**Affected Files**:
- `convex/physician.ts` - Lines 35-38

---

### 3. Can't Click on Patients ✅
**Problem**: Patient detail page was using mock/empty data

**Solution**: Connected to real Convex database:
```typescript
const patientData = useQuery(api.physician.getPatientDetails, 
  userId ? { userId: userId as Id<"users"> } : "skip"
);
```

**Affected Files**:
- `client/app/physician-dashboard/patient/[userId]/page.tsx`

---

### 4. Can't Select Days or View Responses ✅  
**Problem**: Responses tab was empty with placeholder text only

**Solution**: Implemented full day selector and response viewer:

**Features Added**:
- ✅ Clickable day buttons in Overview tab (switches to Responses tab)
- ✅ Day selector grid in Responses tab (Days 1-15)
- ✅ Real-time data fetching using `getPatientDayData` query
- ✅ Display all responses for selected day
- ✅ Show question IDs, question text, response values
- ✅ Show physician notes for each day
- ✅ Timestamp for each response

**UI Components**:
- Day selector with visual indicators (✓ for completed days)
- Selected day highlighting
- Response cards with question details
- Physician notes section (if any exist)
- Loading states and empty states

**Affected Files**:
- `client/app/physician-dashboard/patient/[userId]/page.tsx` - Lines 45, 54-57, 305-434

---

## Current Physician Dashboard Features

### Main Dashboard (`/physician-dashboard`)
- ✅ List all patients (excluding physicians/admins)
- ✅ Filter by review status
- ✅ Search by name or username
- ✅ Show patient progress (Day X/15, percentage)
- ✅ Click on patient to view details

### Patient Detail Page (`/physician-dashboard/patient/[userId]`)

#### Overview Tab
- Patient info (name, username, email, current day)
- Demographics (DOB, sex, height, weight) - if available
- Quick stats (days completed, total responses, progress %)
- Review status dropdown
- **Clickable day grid** - Click any day to view responses

#### Responses Tab ⭐ NEW
- **Day selector** (Days 1-15) with visual indicators
- **Click any day** to view all responses
- Shows:
  - Question ID
  - Question text
  - Response value
  - Timestamp
- Shows physician notes for the day (if any)
- Loading and empty states

#### Scores Tab
- Placeholder for LLM-powered questionnaire scoring
- Will calculate ISI, PSQI, ESS scores

#### Interventions Tab
- Placeholder for creating behavioral interventions
- Will allow structured intervention forms

#### Notes Tab
- Placeholder for physician notes
- Will show all notes across all days

---

## Data Flow

```
User clicks patient → 
  Loads patient details (getPatientDetails)
  
User clicks day in Overview → 
  Switches to Responses tab
  Sets selectedDay
  
Responses tab → 
  Fetches day data (getPatientDayData)
  Displays responses and notes
```

---

## Database Queries Used

1. **`getAllPatientsWithProgress`**
   - Lists all patients with progress stats
   - Excludes physicians and admins
   - Returns: username, name, email, current_day, progress_percentage, review_status

2. **`getPatientDetails`**
   - Gets comprehensive patient info
   - Returns: user data, demographics, review status, total responses, completed days

3. **`getPatientDayData`**
   - Gets all responses and notes for a specific day
   - Enriches responses with question details from assessment_questions table
   - Returns: responses array, notes array

---

## Next Steps (Not Yet Implemented)

1. **Add Annotations**: Allow physicians to add notes while viewing responses
2. **Questionnaire Scoring**: Implement LLM-powered ISI, PSQI, ESS scoring
3. **Intervention Builder**: Create structured forms for interventions
4. **Field Visibility Editor**: Let physicians control what patients see
5. **View Standardized Questionnaires**: Show PSQ, ESS, etc. responses separately

---

## Testing

To test the new features:

1. **Login as physician**: http://localhost:3000/login
   - Username: `physician`
   
2. **View patients**: You should see Martin and Martin2

3. **Click on a patient**: Opens patient detail page

4. **Overview Tab**: Click any day box → Should switch to Responses tab

5. **Responses Tab**: 
   - Click day buttons to switch between days
   - View all responses for that day
   - Currently shows "No responses" if patient hasn't answered questions yet

---

**Status**: ✅ All core viewing functionality working
**Date**: November 13, 2025
**Files Modified**: 
- `convex/physician.ts`
- `client/app/physician-dashboard/page.tsx`
- `client/app/physician-dashboard/patient/[userId]/page.tsx`
