# Fix for Question Reordering Error

## Problem
The reordering endpoint was failing because the `module_questions` table has a PRIMARY KEY constraint on `(module_id, order_index)`, which prevents direct updates when reordering.

## Solution
Changed the backend endpoint to use DELETE + INSERT instead of UPDATE:
1. Delete all questions being reordered from the module
2. Re-insert them in the new order
3. All within a transaction for atomicity

## Changes Made

### Backend (`server/routes/admin.js`)
- Updated `/days/:dayNumber/questions/reorder` endpoint to:
  - Verify all questions exist in the module
  - Use DELETE + INSERT strategy instead of UPDATE
  - Proper transaction handling with rollback on errors

### Frontend (`client/components/DayDetailModal.tsx`)
- Updated `handleDrop` to:
  - Only allow reordering within the same module
  - Show alert if trying to reorder across modules
  - Reload data after successful reorder

## Testing
1. Open admin panel
2. Click on a day to view questions
3. Try dragging a question within the same module - should work
4. Try dragging a question to a different module's questions - should show alert

## Next Steps
- Update `handleMoveQuestion` function to also respect module boundaries
- Add visual indicators showing which questions belong to which module




