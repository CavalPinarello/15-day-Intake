/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as assessment from "../assessment.js";
import type * as assessmentMutations from "../assessmentMutations.js";
import type * as assessmentQueries from "../assessmentQueries.js";
import type * as auth from "../auth.js";
import type * as days from "../days.js";
import type * as llm from "../llm.js";
import type * as physician from "../physician.js";
import type * as questions from "../questions.js";
import type * as responses from "../responses.js";
import type * as seedModules from "../seedModules.js";
import type * as seedQuestions from "../seedQuestions.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  assessment: typeof assessment;
  assessmentMutations: typeof assessmentMutations;
  assessmentQueries: typeof assessmentQueries;
  auth: typeof auth;
  days: typeof days;
  llm: typeof llm;
  physician: typeof physician;
  questions: typeof questions;
  responses: typeof responses;
  seedModules: typeof seedModules;
  seedQuestions: typeof seedQuestions;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
