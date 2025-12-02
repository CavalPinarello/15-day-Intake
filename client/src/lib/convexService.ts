/**
 * Convex HTTP Client for Web
 * Direct HTTP calls to Convex for cross-device sync
 */

const CONVEX_URL = process.env.NEXT_PUBLIC_CONVEX_URL || 'https://enchanted-terrier-633.convex.cloud';

// User session (stored in localStorage)
let currentUserId: string | null = null;

export function setUserId(userId: string) {
  currentUserId = userId;
  if (typeof window !== 'undefined') {
    localStorage.setItem('convex_user_id', userId);
  }
}

export function getUserId(): string | null {
  if (currentUserId) return currentUserId;
  if (typeof window !== 'undefined') {
    currentUserId = localStorage.getItem('convex_user_id');
  }
  return currentUserId;
}

async function convexQuery<T>(path: string, args: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${CONVEX_URL}/api/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path, args }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Convex query failed: ${error}`);
  }

  const data = await response.json();
  return data.value;
}

async function convexMutation<T>(path: string, args: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${CONVEX_URL}/api/mutation`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path, args }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Convex mutation failed: ${error}`);
  }

  const data = await response.json();
  return data.value;
}

// Types
export interface QuestionProgress {
  currentQuestionIndex: number;
  totalQuestions: number;
  lastDevice: string;
  lastUpdatedAt: number;
  completed: boolean;
}

export interface SavedResponse {
  stringValue?: string;
  numberValue?: number;
  arrayValue?: string[];
}

// API Functions

/**
 * Get current question progress for a section
 */
export async function getQuestionProgress(
  dayNumber: number,
  section: string
): Promise<QuestionProgress | null> {
  const userId = getUserId();
  if (!userId) return null;

  try {
    return await convexQuery<QuestionProgress | null>('watch:getQuestionProgress', {
      userId,
      dayNumber,
      section,
    });
  } catch (error) {
    console.error('[Web Convex] Failed to get question progress:', error);
    return null;
  }
}

/**
 * Update question progress after answering a question
 */
export async function updateQuestionProgress(
  dayNumber: number,
  section: string,
  currentQuestionIndex: number,
  totalQuestions: number
): Promise<void> {
  const userId = getUserId();
  if (!userId) return;

  try {
    await convexMutation('watch:updateQuestionProgress', {
      userId,
      dayNumber,
      section,
      currentQuestionIndex,
      totalQuestions,
      device: 'web',
    });
    console.log(`[Web Convex] Progress synced: ${section} question ${currentQuestionIndex + 1}/${totalQuestions}`);
  } catch (error) {
    console.error('[Web Convex] Failed to update question progress:', error);
  }
}

/**
 * Get all saved responses for a day
 */
export async function getSavedResponses(
  dayNumber: number
): Promise<Record<string, SavedResponse>> {
  const userId = getUserId();
  if (!userId) return {};

  try {
    return await convexQuery<Record<string, SavedResponse>>('watch:getSavedResponses', {
      userId,
      dayNumber,
    });
  } catch (error) {
    console.error('[Web Convex] Failed to get saved responses:', error);
    return {};
  }
}

/**
 * Complete a section
 */
export async function completeSection(
  dayNumber: number,
  section: string
): Promise<void> {
  const userId = getUserId();
  if (!userId) return;

  try {
    await convexMutation('watch:completeSection', {
      userId,
      dayNumber,
      section,
    });
    console.log(`[Web Convex] Section completed: ${section}`);
  } catch (error) {
    console.error('[Web Convex] Failed to complete section:', error);
  }
}

/**
 * Get journey state
 */
export async function getJourneyState(): Promise<{
  currentDay: number;
  completedDays: number[];
  sleepLogCompleted: boolean;
  assessmentCompleted: boolean;
} | null> {
  const userId = getUserId();
  if (!userId) return null;

  try {
    return await convexQuery('watch:getJourneyState', { userId });
  } catch (error) {
    console.error('[Web Convex] Failed to get journey state:', error);
    return null;
  }
}
