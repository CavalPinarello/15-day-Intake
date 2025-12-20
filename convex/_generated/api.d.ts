/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as anticipationEngine from "../anticipationEngine.js";
import type * as assessment from "../assessment.js";
import type * as assessmentMutations from "../assessmentMutations.js";
import type * as assessmentQueries from "../assessmentQueries.js";
import type * as auth from "../auth.js";
import type * as challenges from "../challenges.js";
import type * as cohortCompute from "../cohortCompute.js";
import type * as cohortStats from "../cohortStats.js";
import type * as days from "../days.js";
import type * as encouragement from "../encouragement.js";
import type * as gamification from "../gamification.js";
import type * as healthkit from "../healthkit.js";
import type * as http from "../http.js";
import type * as insightLibrary from "../insightLibrary.js";
import type * as insights from "../insights.js";
import type * as interventionLibrary from "../interventionLibrary.js";
import type * as ios from "../ios.js";
import type * as journey from "../journey.js";
import type * as llm from "../llm.js";
import type * as microCohorts from "../microCohorts.js";
import type * as physician from "../physician.js";
import type * as physicianAuth from "../physicianAuth.js";
import type * as questions from "../questions.js";
import type * as responses from "../responses.js";
import type * as seedBadges from "../seedBadges.js";
import type * as seedInsightTeasers from "../seedInsightTeasers.js";
import type * as seedInterventionLibrary from "../seedInterventionLibrary.js";
import type * as seedModules from "../seedModules.js";
import type * as seedQuestions from "../seedQuestions.js";
import type * as sleepInsights from "../sleepInsights.js";
import type * as sleepPhenotype from "../sleepPhenotype.js";
import type * as treatment from "../treatment.js";
import type * as users from "../users.js";
import type * as watch from "../watch.js";
import type * as web from "../web.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  anticipationEngine: typeof anticipationEngine;
  assessment: typeof assessment;
  assessmentMutations: typeof assessmentMutations;
  assessmentQueries: typeof assessmentQueries;
  auth: typeof auth;
  challenges: typeof challenges;
  cohortCompute: typeof cohortCompute;
  cohortStats: typeof cohortStats;
  days: typeof days;
  encouragement: typeof encouragement;
  gamification: typeof gamification;
  healthkit: typeof healthkit;
  http: typeof http;
  insightLibrary: typeof insightLibrary;
  insights: typeof insights;
  interventionLibrary: typeof interventionLibrary;
  ios: typeof ios;
  journey: typeof journey;
  llm: typeof llm;
  microCohorts: typeof microCohorts;
  physician: typeof physician;
  physicianAuth: typeof physicianAuth;
  questions: typeof questions;
  responses: typeof responses;
  seedBadges: typeof seedBadges;
  seedInsightTeasers: typeof seedInsightTeasers;
  seedInterventionLibrary: typeof seedInterventionLibrary;
  seedModules: typeof seedModules;
  seedQuestions: typeof seedQuestions;
  sleepInsights: typeof sleepInsights;
  sleepPhenotype: typeof sleepPhenotype;
  treatment: typeof treatment;
  users: typeof users;
  watch: typeof watch;
  web: typeof web;
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
