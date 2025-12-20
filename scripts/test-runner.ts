#!/usr/bin/env npx ts-node

/**
 * Comprehensive Test Runner for Zoe Sleep
 *
 * Usage:
 *   npx ts-node scripts/test-runner.ts --help
 *   npx ts-node scripts/test-runner.ts --generate-users
 *   npx ts-node scripts/test-runner.ts --validate-all
 *   npx ts-node scripts/test-runner.ts --test-gateways
 *   npx ts-node scripts/test-runner.ts --test-user <userId>
 *
 * Requires:
 *   - Convex CLI installed: npm install -g convex
 *   - Environment configured: CONVEX_URL in .env
 */

import { ConvexHttpClient } from "convex/browser";
import { api } from "../convex/_generated/api";
import * as fs from "fs";
import * as path from "path";

// Load environment
const envPath = path.join(__dirname, "../.env.local");
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, "utf-8");
  for (const line of envContent.split("\n")) {
    const [key, value] = line.split("=");
    if (key && value) {
      process.env[key.trim()] = value.trim();
    }
  }
}

const CONVEX_URL = process.env.NEXT_PUBLIC_CONVEX_URL || process.env.CONVEX_URL;

if (!CONVEX_URL) {
  console.error("Error: CONVEX_URL not found in environment");
  console.error("Set NEXT_PUBLIC_CONVEX_URL or CONVEX_URL in .env.local");
  process.exit(1);
}

const client = new ConvexHttpClient(CONVEX_URL);

// ============================================
// CLI Colors and Formatting
// ============================================

const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
};

const log = {
  info: (msg: string) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg: string) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warning: (msg: string) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg: string) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  header: (msg: string) => console.log(`\n${colors.bright}${colors.cyan}═══ ${msg} ═══${colors.reset}\n`),
  subheader: (msg: string) => console.log(`${colors.bright}${msg}${colors.reset}`),
};

// ============================================
// Test Runner Functions
// ============================================

async function generateTestUsers(options: {
  count?: number;
  password?: string;
  daysToSimulate?: number;
}): Promise<void> {
  log.header("Generating Test Users");

  const { count = 100, password = "test123", daysToSimulate = 7 } = options;

  log.info(`Generating ${count} test users with ${daysToSimulate} days of data...`);

  try {
    // First get templates
    const templates = await client.query(api.testUserGenerator.getTestUserTemplates, {});
    log.info(`Found ${templates.totalTemplates} user templates`);
    log.info(`Phenotypes: ${templates.phenotypes.map((p: { id: string }) => p.id).join(", ")}`);

    // Generate users in batches
    const batchSize = 10;
    let totalCreated = 0;
    let totalSkipped = 0;

    for (let i = 0; i < count; i += batchSize) {
      const result = await client.mutation(api.testUserGenerator.generateAllTestUsers, {
        password,
        startIndex: i,
        count: Math.min(batchSize, count - i),
        daysToSimulate,
      });

      totalCreated += result.summary.created;
      totalSkipped += result.summary.skipped;

      log.info(`Batch ${Math.floor(i / batchSize) + 1}: ${result.summary.created} created, ${result.summary.skipped} skipped`);
    }

    log.success(`Generated ${totalCreated} new test users (${totalSkipped} already existed)`);

    // Show stats
    const stats = await client.query(api.testUserGenerator.getTestUserStats, {});
    log.subheader("\nTest User Statistics:");
    console.log(`  Total test users: ${stats.totalTestUsers}`);
    console.log(`  By phenotype: ${JSON.stringify(stats.byPhenotype, null, 2)}`);
    console.log(`  By gateway: ${JSON.stringify(stats.byGateway, null, 2)}`);

  } catch (error) {
    log.error(`Failed to generate test users: ${error}`);
    throw error;
  }
}

async function validateGateways(): Promise<boolean> {
  log.header("Gateway Validation");

  try {
    const result = await client.query(api.testingAPI.validateAllGateways, {});

    log.info(`Status: ${result.status}`);
    log.info(`Summary: ${result.summary}`);

    let passed = true;

    for (const r of result.results) {
      switch (r.status) {
        case "pass":
          log.success(`${r.gatewayId}: ${r.message}`);
          break;
        case "warning":
          log.warning(`${r.gatewayId}: ${r.message}`);
          break;
        case "fail":
          log.error(`${r.gatewayId}: ${r.message}`);
          passed = false;
          break;
      }
    }

    return passed;
  } catch (error) {
    log.error(`Gateway validation failed: ${error}`);
    return false;
  }
}

async function validateQuestionnaireStructure(): Promise<boolean> {
  log.header("Questionnaire Structure Validation");

  try {
    const result = await client.query(api.testingAPI.validateQuestionnaireStructure, {});

    log.info(`Status: ${result.status}`);
    log.info(`Summary: ${result.summary}`);

    let passed = true;

    for (const r of result.results) {
      const countStr = r.count !== undefined ? ` (${r.count})` : "";
      switch (r.status) {
        case "pass":
          log.success(`${r.area}: ${r.message}${countStr}`);
          break;
        case "warning":
          log.warning(`${r.area}: ${r.message}${countStr}`);
          break;
        case "fail":
          log.error(`${r.area}: ${r.message}${countStr}`);
          passed = false;
          break;
      }
    }

    return passed;
  } catch (error) {
    log.error(`Questionnaire validation failed: ${error}`);
    return false;
  }
}

async function validateAnswerFormats(): Promise<boolean> {
  log.header("Answer Format Validation");

  try {
    const result = await client.query(api.testingAPI.validateAnswerFormats, {});

    log.info(`Status: ${result.status}`);
    log.info(`Total questions: ${result.totalQuestions}`);
    log.info(`Valid: ${result.validCount}, Invalid: ${result.invalidCount}`);

    if (result.invalidCount > 0) {
      log.subheader("\nInvalid Formats:");
      for (const r of result.results) {
        log.error(`${r.questionId} (${r.format}): ${r.message}`);
      }
      return false;
    }

    log.success("All answer formats are valid");
    return true;
  } catch (error) {
    log.error(`Answer format validation failed: ${error}`);
    return false;
  }
}

async function validateDataConsistency(): Promise<boolean> {
  log.header("Data Consistency Validation");

  try {
    const result = await client.query(api.testingAPI.validateDataConsistency, {});

    log.info(`Status: ${result.status}`);
    log.info(`Summary: ${result.summary}`);

    let passed = true;

    for (const r of result.results) {
      const countStr = r.count !== undefined ? ` (${r.count})` : "";
      switch (r.status) {
        case "pass":
          log.success(`${r.check}: ${r.message}${countStr}`);
          break;
        case "warning":
          log.warning(`${r.check}: ${r.message}${countStr}`);
          break;
        case "fail":
          log.error(`${r.check}: ${r.message}${countStr}`);
          passed = false;
          break;
      }
    }

    return passed;
  } catch (error) {
    log.error(`Data consistency validation failed: ${error}`);
    return false;
  }
}

async function testUserScoring(userId: string): Promise<boolean> {
  log.header(`Clinical Scoring Test for User: ${userId}`);

  try {
    const result = await client.mutation(api.testingAPI.validateClinicalScoring, {
      userId: userId as any,
    });

    log.info(`Status: ${result.status}`);
    log.info(`Summary: ${result.summary}`);

    let passed = true;

    for (const r of result.results) {
      const scoreStr = r.score !== undefined ? ` [${r.score}/${r.maxScore}]` : "";
      switch (r.status) {
        case "pass":
          log.success(`${r.questionnaire}${scoreStr}: ${r.message}`);
          break;
        case "skip":
          log.warning(`${r.questionnaire}: ${r.message}`);
          break;
        case "fail":
          log.error(`${r.questionnaire}${scoreStr}: ${r.message}`);
          passed = false;
          break;
      }
    }

    return passed;
  } catch (error) {
    log.error(`Clinical scoring test failed: ${error}`);
    return false;
  }
}

async function testGatewayTriggering(userId: string, dryRun: boolean = true): Promise<boolean> {
  log.header(`Gateway Triggering Test for User: ${userId}`);
  log.info(`Mode: ${dryRun ? "Dry run (no changes)" : "Live (will update states)"}`);

  try {
    const result = await client.mutation(api.testingAPI.testGatewayTriggering, {
      userId: userId as any,
      dryRun,
    });

    log.info(`Status: ${result.status}`);
    log.info(`Total gateways: ${result.totalGateways}`);
    log.info(`Triggered count: ${result.triggeredCount}`);
    log.info(`Mismatches: ${result.mismatchCount}`);

    for (const r of result.results) {
      const triggerIcon = r.shouldTrigger ? "🔴" : "⚪";
      const stateIcon = r.triggered ? "✓" : "✗";
      const match = r.shouldTrigger === r.triggered;

      if (match) {
        log.success(`${triggerIcon} ${r.gatewayId}: should=${r.shouldTrigger}, is=${r.triggered}`);
      } else {
        log.error(`${triggerIcon} ${r.gatewayId}: MISMATCH - should=${r.shouldTrigger}, is=${r.triggered}`);
      }
    }

    return result.mismatchCount === 0;
  } catch (error) {
    log.error(`Gateway triggering test failed: ${error}`);
    return false;
  }
}

async function testExpansionSchedule(userId: string): Promise<boolean> {
  log.header(`Expansion Schedule Test for User: ${userId}`);

  try {
    const result = await client.query(api.testingAPI.testExpansionScheduling, {
      userId: userId as any,
    });

    log.info(`Status: ${result.status}`);
    log.info(`Triggered gateways: ${result.triggeredGateways.join(", ") || "none"}`);

    if (result.schedule) {
      log.info(`Total expansion questions: ${result.schedule.totalQuestions}`);
      log.info(`Total minutes: ${result.schedule.totalMinutes}`);

      log.subheader("\nDay Assignments:");
      for (const day of result.schedule.dayAssignments) {
        console.log(`  Day ${day.day_number}: ${day.question_count} questions, ${day.estimated_minutes} min`);
        console.log(`    Modules: ${day.module_ids.join(", ")}`);
      }
    }

    if (result.results) {
      let passed = true;
      for (const r of result.results) {
        switch (r.status) {
          case "pass":
            log.success(`${r.check}: ${r.message}`);
            break;
          case "fail":
            log.error(`${r.check}: ${r.message}`);
            passed = false;
            break;
        }
      }
      return passed;
    }

    return result.status === "pass";
  } catch (error) {
    log.error(`Expansion schedule test failed: ${error}`);
    return false;
  }
}

async function runAllValidations(): Promise<boolean> {
  log.header("Running Full Test Suite");

  const results: { name: string; passed: boolean }[] = [];

  // Structural validations
  results.push({ name: "Gateway Validation", passed: await validateGateways() });
  results.push({ name: "Questionnaire Structure", passed: await validateQuestionnaireStructure() });
  results.push({ name: "Answer Formats", passed: await validateAnswerFormats() });
  results.push({ name: "Data Consistency", passed: await validateDataConsistency() });

  // Summary
  log.header("Test Suite Summary");

  let allPassed = true;
  for (const r of results) {
    if (r.passed) {
      log.success(r.name);
    } else {
      log.error(r.name);
      allPassed = false;
    }
  }

  const passCount = results.filter(r => r.passed).length;
  console.log(`\n${colors.bright}Total: ${passCount}/${results.length} passed${colors.reset}`);

  return allPassed;
}

async function testRandomUsers(count: number = 10): Promise<void> {
  log.header(`Testing ${count} Random Test Users`);

  try {
    const stats = await client.query(api.testUserGenerator.getTestUserStats, {});

    if (stats.totalTestUsers === 0) {
      log.warning("No test users found. Generate test users first with --generate-users");
      return;
    }

    log.info(`Found ${stats.totalTestUsers} test users`);

    // Get test users from the database
    // For now, we'll just report what we can test
    log.info(`Test ${Math.min(count, stats.totalTestUsers)} users by providing their IDs`);
    log.info("Use: npx ts-node scripts/test-runner.ts --test-user <userId>");

  } catch (error) {
    log.error(`Failed to test random users: ${error}`);
  }
}

async function cleanupTestUsers(): Promise<void> {
  log.header("Cleanup Test Users");

  log.warning("This will delete ALL test users and their data!");
  log.info("Press Ctrl+C to cancel...");

  // Wait 3 seconds for potential cancel
  await new Promise(resolve => setTimeout(resolve, 3000));

  try {
    const result = await client.mutation(api.testUserGenerator.deleteAllTestUsers, {
      confirmDelete: true,
    });

    log.success(result.message);
  } catch (error) {
    log.error(`Cleanup failed: ${error}`);
  }
}

// ============================================
// CLI Interface
// ============================================

function showHelp(): void {
  console.log(`
${colors.bright}Zoe Sleep Test Runner${colors.reset}

${colors.cyan}Usage:${colors.reset}
  npx ts-node scripts/test-runner.ts [command] [options]

${colors.cyan}Commands:${colors.reset}
  --help, -h              Show this help message
  --generate-users        Generate 100+ test users with diverse profiles
  --validate-all          Run all structural validation tests
  --validate-gateways     Validate gateway definitions
  --validate-questions    Validate questionnaire structure
  --validate-formats      Validate answer format configurations
  --validate-data         Validate data consistency
  --test-user <id>        Run all tests for a specific user
  --test-scoring <id>     Test clinical scoring for a user
  --test-gateways <id>    Test gateway triggering for a user
  --test-expansion <id>   Test expansion scheduling for a user
  --test-random [count]   Test random test users (default: 10)
  --cleanup               Delete all test users (caution!)
  --stats                 Show test user statistics

${colors.cyan}Options:${colors.reset}
  --count <n>             Number of test users to generate (default: 100)
  --password <p>          Password for test users (default: test123)
  --days <n>              Days of data to simulate (default: 7)
  --live                  Apply changes (default: dry run for gateway tests)

${colors.cyan}Examples:${colors.reset}
  # Generate 50 test users with 14 days of data
  npx ts-node scripts/test-runner.ts --generate-users --count 50 --days 14

  # Run all validations
  npx ts-node scripts/test-runner.ts --validate-all

  # Test a specific user
  npx ts-node scripts/test-runner.ts --test-user jh7abc123def456

  # Show statistics
  npx ts-node scripts/test-runner.ts --stats
`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    showHelp();
    return;
  }

  // Parse options
  const getArg = (flag: string): string | undefined => {
    const idx = args.indexOf(flag);
    if (idx !== -1 && args[idx + 1]) {
      return args[idx + 1];
    }
    return undefined;
  };

  const count = parseInt(getArg("--count") || "100");
  const password = getArg("--password") || "test123";
  const daysToSimulate = parseInt(getArg("--days") || "7");
  const isLive = args.includes("--live");

  try {
    if (args.includes("--generate-users")) {
      await generateTestUsers({ count, password, daysToSimulate });
    } else if (args.includes("--validate-all")) {
      const passed = await runAllValidations();
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--validate-gateways")) {
      const passed = await validateGateways();
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--validate-questions")) {
      const passed = await validateQuestionnaireStructure();
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--validate-formats")) {
      const passed = await validateAnswerFormats();
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--validate-data")) {
      const passed = await validateDataConsistency();
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--test-user")) {
      const userId = getArg("--test-user");
      if (!userId) {
        log.error("Please provide a user ID: --test-user <id>");
        process.exit(1);
      }
      const passed1 = await testUserScoring(userId);
      const passed2 = await testGatewayTriggering(userId, !isLive);
      const passed3 = await testExpansionSchedule(userId);
      process.exit(passed1 && passed2 && passed3 ? 0 : 1);
    } else if (args.includes("--test-scoring")) {
      const userId = getArg("--test-scoring");
      if (!userId) {
        log.error("Please provide a user ID: --test-scoring <id>");
        process.exit(1);
      }
      const passed = await testUserScoring(userId);
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--test-gateways")) {
      const userId = getArg("--test-gateways");
      if (!userId) {
        log.error("Please provide a user ID: --test-gateways <id>");
        process.exit(1);
      }
      const passed = await testGatewayTriggering(userId, !isLive);
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--test-expansion")) {
      const userId = getArg("--test-expansion");
      if (!userId) {
        log.error("Please provide a user ID: --test-expansion <id>");
        process.exit(1);
      }
      const passed = await testExpansionSchedule(userId);
      process.exit(passed ? 0 : 1);
    } else if (args.includes("--test-random")) {
      const randomCount = parseInt(getArg("--test-random") || "10");
      await testRandomUsers(randomCount);
    } else if (args.includes("--cleanup")) {
      await cleanupTestUsers();
    } else if (args.includes("--stats")) {
      const stats = await client.query(api.testUserGenerator.getTestUserStats, {});
      log.header("Test User Statistics");
      console.log(JSON.stringify(stats, null, 2));
    } else {
      log.error(`Unknown command: ${args[0]}`);
      showHelp();
      process.exit(1);
    }
  } catch (error) {
    log.error(`Test runner failed: ${error}`);
    process.exit(1);
  }
}

main();
