/**
 * Convex Database Adapter
 * Provides a SQLite-like interface for Convex database operations
 */

const { ConvexHttpClient } = require("convex/browser");
const path = require("path");

// Import API - need to use absolute path
// Convex API is ES module, so we'll use dynamic import
let api = null;
let apiPromise = null;

async function getApi() {
  if (api) return api;
  if (apiPromise) return apiPromise;
  
  apiPromise = (async () => {
    try {
      const apiPath = path.join(__dirname, "../../convex/_generated/api.js");
      const apiModule = await import(apiPath);
      api = apiModule.api || apiModule;
      return api;
    } catch (err) {
      console.error("Error loading Convex API. Make sure to run 'npx convex dev' first.");
      throw err;
    }
  })();
  
  return apiPromise;
}

// Get Convex URL from environment or use default
// You can set this in .env.local or environment variables
const CONVEX_URL = process.env.NEXT_PUBLIC_CONVEX_URL || 
                   process.env.CONVEX_URL || 
                   "https://enchanted-terrier-633.convex.cloud";

let client = null;

/**
 * Get Convex client instance
 */
function getConvexClient() {
  if (!client) {
    client = new ConvexHttpClient(CONVEX_URL);
  }
  return client;
}

/**
 * Convert Convex ID to numeric ID (for backward compatibility)
 * In SQLite, IDs are integers. In Convex, they're strings.
 * We'll use the numeric part of the Convex ID or maintain a mapping.
 */
function convexIdToNumber(convexId) {
  if (!convexId) return null;
  // Convex IDs are like "j1234567890abcdef"
  // Extract numeric part if possible, or use a hash
  const match = convexId.match(/\d+/);
  return match ? parseInt(match[0], 10) : null;
}

/**
 * Convert numeric ID to Convex ID
 * This is a simplified approach - in production you'd want a proper mapping
 */
function numberToConvexId(tableName, numericId) {
  // This is a limitation - we can't directly convert numeric IDs to Convex IDs
  // We'll need to query by other fields (like username) instead
  return numericId;
}

/**
 * Convex Database Adapter
 * Provides SQLite-compatible methods that call Convex functions
 */
class ConvexAdapter {
  constructor() {
    this.client = getConvexClient();
  }

  // ============================================
  // User Operations
  // ============================================

  async getUserByUsername(username) {
    const api = await getApi();
    const user = await this.client.query(api.users.getUserByUsername, { username });
    if (user) {
      return {
        id: convexIdToNumber(user._id) || user._id,
        _id: user._id, // Keep Convex ID for Convex operations
        ...user,
      };
    }
    return null;
  }

  async loginUser(username, password) {
    // Get user for login (password comparison done server-side)
    try {
      const api = await getApi();
      if (!api || !api.auth || !api.auth.getUserForLogin) {
        console.error('Convex API not properly loaded. Make sure to run "npx convex dev"');
        throw new Error('Convex API not available');
      }
      const user = await this.client.query(api.auth.getUserForLogin, { username });
      if (!user) {
        console.log(`Convex: User '${username}' not found`);
        return null;
      }
      console.log(`Convex: Found user '${username}' with ID ${user._id}`);
      return {
        id: convexIdToNumber(user._id) || user._id,
        _id: user._id,
        ...user,
      };
    } catch (err) {
      console.error('Error in loginUser:', err);
      throw err;
    }
  }

  async registerUser(userData) {
    // Hash password should be done server-side before calling this
    const api = await getApi();
    const userId = await this.client.mutation(api.auth.registerUser, {
      username: userData.username,
      password_hash: userData.password_hash,
      email: userData.email,
      email_verification_token: userData.email_verification_token,
      email_verification_expires: userData.email_verification_expires,
    });
    return userId;
  }

  async getUserById(userId) {
    // If userId is numeric, we need to find the user another way
    // For now, assume it's already a Convex ID
    try {
      // First try as Convex ID
      const api = await getApi();
      const user = await this.client.query(api.users.getUserById, { userId });
      if (user) {
        return {
          id: convexIdToNumber(user._id) || user._id,
          _id: user._id, // Keep Convex ID for Convex operations
          ...user,
        };
      }
    } catch (err) {
      // If userId is numeric, try to find by querying all users
      // This is inefficient but works for migration
      try {
        const api = await getApi();
        const users = await this.client.query(api.users.getAllUsers, {});
        const user = users.find((u) => {
          const numericId = convexIdToNumber(u._id);
          return numericId === userId || u._id === userId;
        });
        if (user) {
          return {
            id: convexIdToNumber(user._id) || user._id,
            _id: user._id, // Keep Convex ID for Convex operations
            ...user,
          };
        }
      } catch (queryErr) {
        console.error('Error querying users:', queryErr);
      }
    }
    return null;
  }

  async updateUserLastAccessed(userId) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.updateUserLastAccessed, { userId });
  }

  async storeRefreshToken(userId, token, expiresAt) {
    // userId should be Convex ID (_id)
    // expiresAt should be Unix timestamp (number)
    const api = await getApi();
    await this.client.mutation(api.auth.storeRefreshToken, {
      user_id: userId,
      token,
      expires_at: expiresAt,
    });
  }

  async getRefreshToken(token) {
    const api = await getApi();
    const tokenData = await this.client.query(api.auth.getRefreshToken, { token });
    if (!tokenData || !tokenData.user) {
      return null;
    }
    // Convert user to have numeric id for compatibility
    const user = tokenData.user;
    return {
      ...tokenData,
      user: {
        id: convexIdToNumber(user._id) || user._id,
        _id: user._id,
        ...user,
      },
    };
  }

  async revokeRefreshToken(token, userId) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.revokeRefreshToken, {
      token,
      userId,
    });
  }

  async createUser(userData) {
    const api = await getApi();
    const userId = await this.client.mutation(api.users.createUser, {
      username: userData.username,
      password_hash: userData.password_hash,
      email: userData.email,
      current_day: userData.current_day || 1,
    });
    return {
      lastID: convexIdToNumber(userId) || userId,
      changes: 1,
    };
  }

  async updateUser(userId, updates) {
    // Convert numeric userId to Convex ID if needed
    let convexUserId = userId;
    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) throw new Error('User not found');
      convexUserId = user._id;
    }

    await this.client.mutation(api.users.updateUser, {
      userId: convexUserId,
      updates: {
        current_day: updates.current_day,
        last_accessed: updates.last_accessed ? Date.now() : undefined,
        email: updates.email,
        onboarding_completed: updates.onboarding_completed,
        onboarding_completed_at: updates.onboarding_completed_at,
      },
    });
    return { changes: 1 };
  }

  // ============================================
  // Day Operations
  // ============================================

  async getAllDays() {
    const days = await this.client.query(api.days.getAllDays, {});
    return days.map((day) => ({
      id: convexIdToNumber(day._id) || day._id,
      ...day,
    }));
  }

  async getDayByNumber(dayNumber) {
    const day = await this.client.query(api.days.getDayByNumber, { dayNumber });
    if (day) {
      return {
        id: convexIdToNumber(day._id) || day._id,
        ...day,
      };
    }
    return null;
  }

  // ============================================
  // Question Operations
  // ============================================

  async getQuestionsByDay(dayId) {
    // Convert numeric dayId to Convex ID if needed
    let convexDayId = dayId;
    if (typeof dayId === 'number') {
      const day = await this.getDayByNumber(dayId);
      if (!day) return [];
      convexDayId = day._id;
    }

    const questions = await this.client.query(api.questions.getQuestionsByDay, {
      dayId: convexDayId,
    });
    return questions.map((q) => ({
      id: convexIdToNumber(q._id) || q._id,
      ...q,
      options: q.options ? JSON.parse(q.options) : null,
      conditional_logic: q.conditional_logic ? JSON.parse(q.conditional_logic) : null,
    }));
  }

  async createQuestion(questionData) {
    // Convert numeric day_id to Convex ID
    let convexDayId = questionData.day_id;
    if (typeof questionData.day_id === 'number') {
      const day = await this.getDayByNumber(questionData.day_id);
      if (!day) throw new Error('Day not found');
      convexDayId = day._id;
    }

    const questionId = await this.client.mutation(api.questions.createQuestion, {
      day_id: convexDayId,
      question_text: questionData.question_text,
      question_type: questionData.question_type,
      options: questionData.options ? JSON.stringify(questionData.options) : undefined,
      order_index: questionData.order_index,
      required: questionData.required,
      conditional_logic: questionData.conditional_logic
        ? JSON.stringify(questionData.conditional_logic)
        : undefined,
    });
    return {
      lastID: convexIdToNumber(questionId) || questionId,
      changes: 1,
    };
  }

  async updateQuestion(questionId, updates) {
    // Convert numeric questionId to Convex ID if needed
    let convexQuestionId = questionId;
    if (typeof questionId === 'number') {
      // We'd need to query to find the Convex ID - for now assume it's already Convex ID
      // In production, maintain a mapping
    }

    await this.client.mutation(api.questions.updateQuestion, {
      questionId: convexQuestionId,
      updates: {
        question_text: updates.question_text,
        question_type: updates.question_type,
        options: updates.options ? JSON.stringify(updates.options) : undefined,
        order_index: updates.order_index,
        required: updates.required,
        conditional_logic: updates.conditional_logic
          ? JSON.stringify(updates.conditional_logic)
          : undefined,
      },
    });
    return { changes: 1 };
  }

  async deleteQuestion(questionId) {
    let convexQuestionId = questionId;
    if (typeof questionId === 'number') {
      // Similar issue - would need mapping
    }
    await this.client.mutation(api.questions.deleteQuestion, {
      questionId: convexQuestionId,
    });
    return { changes: 1 };
  }

  // ============================================
  // Response Operations
  // ============================================

  async saveResponse(responseData) {
    // Convert IDs to Convex IDs
    let convexUserId = responseData.user_id;
    let convexQuestionId = responseData.question_id;
    let convexDayId = responseData.day_id;

    if (typeof responseData.user_id === 'number') {
      const user = await this.getUserById(responseData.user_id);
      if (!user) throw new Error('User not found');
      convexUserId = user._id;
    }

    if (typeof responseData.question_id === 'number') {
      // Would need to query questions - simplified for now
    }

    if (typeof responseData.day_id === 'number') {
      const day = await this.getDayByNumber(responseData.day_id);
      if (!day) throw new Error('Day not found');
      convexDayId = day._id;
    }

    const responseId = await this.client.mutation(api.responses.saveResponse, {
      user_id: convexUserId,
      question_id: convexQuestionId,
      day_id: convexDayId,
      response_value: responseData.response_value,
      response_data: responseData.response_data
        ? JSON.stringify(responseData.response_data)
        : undefined,
    });
    return {
      lastID: convexIdToNumber(responseId) || responseId,
      changes: 1,
    };
  }

  async getUserDayResponses(userId, dayId) {
    // Convert IDs
    let convexUserId = userId;
    let convexDayId = dayId;

    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) return [];
      convexUserId = user._id;
    }

    if (typeof dayId === 'number') {
      const day = await this.getDayByNumber(dayId);
      if (!day) return [];
      convexDayId = day._id;
    }

    const responses = await this.client.query(api.responses.getUserDayResponses, {
      userId: convexUserId,
      dayId: convexDayId,
    });
    return responses.map((r) => ({
      ...r,
      response_data: r.response_data ? JSON.parse(r.response_data) : null,
    }));
  }

  // ============================================
  // Assessment Operations
  // ============================================

  async getMasterQuestions() {
    const questions = await this.client.query(api.assessment.getMasterQuestions, {});
    return questions.map((q) => ({
      question_id: q.question_id,
      question_text: q.question_text,
      pillar: q.pillar,
      tier: q.tier,
      question_type: q.question_type,
      options_json: q.options_json,
      estimated_time: q.estimated_time,
      trigger: q.trigger,
      notes: q.notes,
    }));
  }

  async updateAssessmentQuestion(questionId, updates) {
    await this.client.mutation(api.assessment.updateAssessmentQuestion, {
      questionId,
      updates: {
        question_text: updates.text || updates.question_text,
        question_type: updates.type || updates.question_type,
        options_json: updates.options ? JSON.stringify(updates.options) : undefined,
        estimated_time: updates.estimatedMinutes || updates.estimated_time,
        trigger: updates.trigger,
      },
    });
    return { changes: 1 };
  }

  async getModules() {
    const modules = await this.client.query(api.assessment.getModules, {});
    return modules.map((mod) => ({
      module_id: mod.module_id,
      name: mod.name,
      description: mod.description,
      pillar: mod.pillar,
      tier: mod.tier,
      module_type: mod.module_type,
      estimated_minutes: mod.estimated_minutes,
      default_day_number: mod.default_day_number,
      repeat_interval: mod.repeat_interval,
    }));
  }

  async getModuleQuestions(moduleId) {
    const moduleQuestions = await this.client.query(api.assessment.getModuleQuestions, { moduleId });
    return moduleQuestions.map((mq) => ({
      question_id: mq.question_id,
      order_index: mq.order_index,
    }));
  }

  async getDayAssignments() {
    return await this.client.query(api.assessment.getDayAssignments, {});
  }

  async getAllUserNames() {
    const names = await this.client.query(api.assessment.getAllUserNames, {});
    return { names };
  }

  async saveAssessmentResponse(userId, questionId, responseValue, dayNumber) {
    let convexUserId = userId;
    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) throw new Error('User not found');
      convexUserId = user._id;
    }

    await this.client.mutation(api.assessment.saveAssessmentResponse, {
      userId: convexUserId,
      questionId,
      responseValue,
      dayNumber,
    });
    return { changes: 1 };
  }

  async getUserResponses(userId) {
    let convexUserId = userId;
    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) return {};
      convexUserId = user._id;
    }

    return await this.client.query(api.assessment.getUserResponses, {
      userId: convexUserId,
    });
  }

  async reorderModuleQuestions(moduleId, questionIds) {
    await this.client.mutation(api.assessment.reorderModuleQuestions, {
      moduleId,
      questionIds,
    });
    return { success: true };
  }

  async assignModuleToDay(dayNumber, moduleId, orderIndex) {
    await this.client.mutation(api.assessment.assignModuleToDay, {
      dayNumber,
      moduleId,
      orderIndex,
    });
    return { success: true };
  }

  async removeModuleFromDay(dayNumber, moduleId) {
    await this.client.mutation(api.assessment.removeModuleFromDay, {
      dayNumber,
      moduleId,
    });
    return { success: true };
  }

  async reorderDayModules(dayNumber, moduleIds) {
    await this.client.mutation(api.assessment.reorderDayModules, {
      dayNumber,
      moduleIds,
    });
    return { success: true };
  }

  async getModuleWithQuestions(moduleId) {
    return await this.client.query(api.assessment.getModuleWithQuestions, { moduleId });
  }

  async getSleepDiaryQuestions() {
    const questions = await this.client.query(api.assessment.getSleepDiaryQuestions, {});
    return questions.map((q) => ({
      id: q.id,
      question_text: q.question_text,
      question_type: q.question_type,
      options_json: q.options_json,
      group_key: q.group_key,
      help_text: q.help_text,
      condition_json: q.condition_json,
      estimated_time: q.estimated_time,
    }));
  }

  async getUserGatewayStates(userId) {
    let convexUserId = userId;
    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) return {};
      convexUserId = user._id;
    }

    return await this.client.query(api.assessment.getUserGatewayStates, {
      userId: convexUserId,
    });
  }

  async saveGatewayState(userId, gatewayId, triggered, triggeredAt, evaluationDataJson) {
    let convexUserId = userId;
    if (typeof userId === 'number') {
      const user = await this.getUserById(userId);
      if (!user) throw new Error('User not found');
      convexUserId = user._id;
    }

    await this.client.mutation(api.assessment.saveGatewayState, {
      userId: convexUserId,
      gatewayId,
      triggered,
      triggeredAt,
      evaluationDataJson,
    });
    return { success: true };
  }

  // ============================================
  // Email Verification Operations
  // ============================================

  async getUserByVerificationToken(token) {
    const api = await getApi();
    const user = await this.client.query(api.auth.getUserByVerificationToken, { token });
    if (!user) return null;
    return {
      id: convexIdToNumber(user._id) || user._id,
      _id: user._id,
      ...user,
    };
  }

  async verifyUserEmail(userId) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.verifyUserEmail, { userId });
  }

  async getUserByEmail(email) {
    const api = await getApi();
    const user = await this.client.query(api.auth.getUserByEmail, { email });
    if (!user) return null;
    return {
      id: convexIdToNumber(user._id) || user._id,
      _id: user._id,
      ...user,
    };
  }

  async getUserByUsernameOrEmail(identifier) {
    const api = await getApi();
    const user = await this.client.query(api.auth.getUserByUsernameOrEmail, { identifier });
    if (!user) return null;
    return {
      id: convexIdToNumber(user._id) || user._id,
      _id: user._id,
      ...user,
    };
  }

  // ============================================
  // Password Reset Operations
  // ============================================

  async setPasswordResetToken(userId, resetToken, resetExpires) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.setPasswordResetToken, {
      userId,
      resetToken,
      resetExpires,
    });
  }

  async getUserByPasswordResetToken(token) {
    const api = await getApi();
    const user = await this.client.query(api.auth.getUserByPasswordResetToken, { token });
    if (!user) return null;
    return {
      id: convexIdToNumber(user._id) || user._id,
      _id: user._id,
      ...user,
    };
  }

  async updateUserPassword(userId, passwordHash) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.updateUserPassword, {
      userId,
      password_hash: passwordHash,
    });
  }

  async clearPasswordResetToken(userId) {
    // userId should be Convex ID (_id)
    const api = await getApi();
    await this.client.mutation(api.auth.clearPasswordResetToken, { userId });
  }
}

// Create singleton instance
let adapterInstance = null;

function getConvexAdapter() {
  if (!adapterInstance) {
    adapterInstance = new ConvexAdapter();
  }
  return adapterInstance;
}

module.exports = {
  getConvexAdapter,
  ConvexAdapter,
};

