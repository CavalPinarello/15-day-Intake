# Zoe Sleep Testing System

Comprehensive automated testing framework for validating the Zoe Sleep platform across all platforms and clinical scenarios.

## Quick Start

```bash
# Run all structural validations
npm test

# Generate 100 test users with diverse profiles
npm run test:generate-users:100

# View test user statistics
npm run test:stats

# Run clinical scenario tests
npm run test:clinical
```

## Architecture

The testing system consists of several interconnected components:

```
┌─────────────────────────────────────────────────────────────────┐
│                       Testing Framework                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  Test User       │  │  Validation      │  │  Clinical      │ │
│  │  Generator       │  │  API             │  │  Scenarios     │ │
│  │  (100+ profiles) │  │  (Gateways,      │  │  (12 cases)    │ │
│  │                  │  │   Questions,     │  │                │ │
│  │                  │  │   Formats)       │  │                │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬────────┘ │
│           │                     │                     │          │
│  ┌────────▼─────────────────────▼─────────────────────▼────────┐ │
│  │                    Convex Backend                           │ │
│  │  - testUserGenerator.ts    - crossPlatformValidator.ts     │ │
│  │  - testingAPI.ts           - clinicalScenarios.ts          │ │
│  │  - healthKitSimulator.ts                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    CLI Test Runner                          │ │
│  │                 scripts/test-runner.ts                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Test User Generator (`convex/testUserGenerator.ts`)

Generates 100+ diverse test users covering all sleep conditions:

**9 Sleep Phenotypes:**
- Tired but Wired - High anxiety, difficulty falling asleep
- Sleep State Misperception - Perceives sleep as worse than reality
- Compensator - Weekend catch-up sleep pattern
- Irregular Rhythm - Highly variable schedule
- Fragmented Sleeper - Multiple night awakenings
- Early Terminator - Wakes too early
- Delayed Phase - Natural night owl
- Short Sleeper - Functions on <6 hours
- Efficiency Struggler - Long time in bed, poor efficiency

**Demographic Diversity:**
- Age brackets: 18-25, 26-35, 36-45, 46-55, 56-65, 66+
- Genders: Male, Female, Other
- BMI categories: Underweight to Obese III
- Activity levels: Low, Moderate, High
- Chronotypes: Early bird, Normal, Night owl

**Usage:**
```bash
# Generate 100 users with 14 days of data
npm run test:generate-users:100

# Or via Convex directly
npx convex run testUserGenerator:generateAllTestUsers '{"count": 50, "daysToSimulate": 7}'

# View available templates
npx convex run testUserGenerator:getTestUserTemplates

# Cleanup test users
npm run test:cleanup
```

### 2. Testing API (`convex/testingAPI.ts`)

Provides validation endpoints for automated testing:

**Available Validations:**

| Function | Description |
|----------|-------------|
| `validateAllGateways` | Verify all 10 gateways are properly configured |
| `validateQuestionnaireStructure` | Check questions, modules, and mappings |
| `validateAnswerFormats` | Ensure format_config matches answer types |
| `validateDataConsistency` | Find orphan data, duplicates, invalid values |
| `validateClinicalScoring` | Test scoring functions for a user |
| `testGatewayTriggering` | Verify gateway triggering logic for a user |
| `testExpansionScheduling` | Check expansion pack day distribution |

**Usage:**
```bash
# Run all structural validations
npm test

# Individual validations
npm run test:gateways
npm run test:questions
npm run test:formats
npm run test:data

# User-specific tests
npx convex run testingAPI:validateClinicalScoring '{"userId": "abc123"}'
npx convex run testingAPI:testGatewayTriggering '{"userId": "abc123", "dryRun": true}'
```

### 3. Cross-Platform Validator (`convex/crossPlatformValidator.ts`)

Ensures consistency between iOS, Web, and backend:

**Checks:**
- iOS module definitions match backend modules
- All clinical questionnaire questions exist (ISI, PHQ-9, GAD-7, ESS, STOP-BANG, CSD)
- Score thresholds are consistent across platforms
- Gateway-to-expansion module mappings are valid

**Expected iOS Modules:**
- Core: 10 modules (Demographics, Social, Metabolic, Sleep Quality, etc.)
- Gateway: 4 modules (Mental Health, Cognitive, Sleep Quality, Physical)
- Expansion: 16 modules (ISI, PHQ-9, GAD-7, ESS, STOP-BANG, DBAS, etc.)
- Sleep Diary: 1 module (Consensus Sleep Diary)

**Usage:**
```bash
npm run test:cross-platform

# Or individual checks
npx convex run crossPlatformValidator:validateModuleConsistency
npx convex run crossPlatformValidator:validateClinicalQuestions
npx convex run crossPlatformValidator:validateScoreThresholds
npx convex run crossPlatformValidator:generateConsistencyReport
```

### 4. HealthKit Simulator (`convex/healthKitSimulator.ts`)

Generates realistic sleep and health data for testing:

**Sleep Patterns Available:**
| Pattern | Description | Efficiency |
|---------|-------------|------------|
| healthy | Normal sleep | 88-95% |
| insomnia_onset | Difficulty falling asleep | 65-78% |
| insomnia_maintenance | Frequent awakenings | 60-75% |
| early_awakening | Wakes too early | 70-82% |
| sleep_apnea | Fragmented with O2 drops | 55-70% |
| delayed_phase | Night owl | 85-92% |
| advanced_phase | Early bird | 85-92% |
| irregular | Variable schedule | 70-82% |
| short_sleeper | <6 hours, high efficiency | 92-97% |
| compensator | Weekend catch-up | 78-88% |

**Usage:**
```bash
# Generate 14 nights of insomnia pattern
npx convex run healthKitSimulator:generateMultipleNights '{
  "userId": "abc123",
  "startDate": "2025-12-01",
  "nights": 14,
  "patternName": "insomnia_onset"
}'

# Generate activity data
npx convex run healthKitSimulator:generateActivityData '{
  "userId": "abc123",
  "startDate": "2025-12-01",
  "days": 14,
  "activityLevel": "moderate"
}'

# List available patterns
npx convex run healthKitSimulator:getSleepPatterns
```

### 5. Clinical Scenarios (`convex/clinicalScenarios.ts`)

Pre-configured clinical test cases for validation:

**12 Clinical Scenarios:**

| Category | Scenario | Expected Gateways |
|----------|----------|-------------------|
| Insomnia | Sleep Onset Insomnia - Moderate | insomnia, anxiety, poor_sleep_quality |
| Insomnia | Sleep Maintenance Insomnia - Severe | insomnia, depression, poor_sleep_quality |
| Insomnia | Early Morning Awakening | insomnia, depression |
| Apnea | High Risk OSA - Classic | osa, excessive_sleepiness |
| Apnea | Moderate Risk OSA - Female | osa, insomnia |
| Mental | Anxiety-Driven Insomnia | anxiety, insomnia, poor_sleep_quality |
| Mental | Depression with Hypersomnia | depression |
| Circadian | Delayed Sleep Phase | sleep_timing |
| Circadian | Social Jet Lag | sleep_timing, poor_sleep_quality |
| Comorbid | Triple Threat (Insomnia+Anxiety+Depression) | insomnia, anxiety, depression, poor_sleep_quality |
| Comorbid | COMISA (OSA + Insomnia) | osa, insomnia, excessive_sleepiness, poor_sleep_quality |
| Control | Healthy Sleeper | (none) |

**Usage:**
```bash
# Run all clinical scenarios
npm run test:clinical

# Create a specific clinical test user
npx convex run clinicalScenarios:createClinicalTestUser '{"scenarioId": "insomnia_onset_moderate"}'

# List all scenarios
npx convex run clinicalScenarios:getClinicalTestCases

# Validate a user against expected outcomes
npx convex run clinicalScenarios:validateClinicalTestUser '{
  "userId": "abc123",
  "scenarioId": "insomnia_onset_moderate"
}'
```

## CLI Test Runner

The main entry point for testing: `scripts/test-runner.ts`

```bash
# Full help
npx ts-node scripts/test-runner.ts --help

# Commands
--generate-users        Generate test users
--validate-all          Run all structural validations
--validate-gateways     Validate gateway definitions
--validate-questions    Validate questionnaire structure
--validate-formats      Validate answer formats
--validate-data         Validate data consistency
--test-user <id>        Run all tests for a user
--test-scoring <id>     Test clinical scoring
--test-gateways <id>    Test gateway triggering
--test-expansion <id>   Test expansion scheduling
--cleanup               Delete all test users
--stats                 Show test user statistics

# Options
--count <n>             Number of users to generate
--password <p>          Password for test users
--days <n>              Days of data to simulate
--live                  Apply changes (vs dry run)
```

## Test User Credentials

All generated test users use:
- **Password:** `test123` (or custom via `--password`)
- **Email:** `{username}@test.zoesleep.com`
- **Developer Mode:** Enabled (allows day jumping)

## Gateway Coverage Matrix

| Gateway | Trigger Questions | Threshold |
|---------|-------------------|-----------|
| insomnia | Q3 | = "Yes" |
| depression | Q15 | >= 2 |
| anxiety | Q16 | >= 2 |
| excessive_sleepiness | Q17 | >= 3 |
| cognitive | Q18 | = "Yes" |
| osa | Q19 OR Q20 | = "Yes" |
| pain | Q22 AND Q23 | Q22="Yes" AND Q23>=4 |
| sleep_timing | Q7-Q10 | weekday-weekend diff > 1hr |
| diet_impact | Q34 | = "Yes" |
| poor_sleep_quality | Q1 OR Q3 | Q1<=5 OR Q3="Yes" |

## Clinical Score Thresholds

### ISI (Insomnia Severity Index)
- 0-7: No clinically significant insomnia
- 8-14: Subthreshold insomnia
- 15-21: Clinical insomnia (moderate)
- 22-28: Clinical insomnia (severe)

### PHQ-9 (Depression)
- 0-4: Minimal
- 5-9: Mild
- 10-14: Moderate
- 15-19: Moderately severe
- 20-27: Severe

### GAD-7 (Anxiety)
- 0-4: Minimal
- 5-9: Mild
- 10-14: Moderate
- 15-21: Severe

### ESS (Sleepiness)
- 0-10: Normal
- 11-14: Mild EDS
- 15-18: Moderate EDS
- 19-24: Severe EDS

### STOP-BANG (OSA Risk)
- 0-2: Low risk
- 3-4: Intermediate risk
- 5-8: High risk

## Continuous Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm test
```

## Physician Dashboard Testing

With 100+ test users generated, the physician dashboard can be used to:

1. **Review diverse patient profiles** - See various sleep conditions
2. **Test gateway detection** - Verify correct expansion packs trigger
3. **Validate scoring** - Check ISI, PHQ-9, GAD-7, ESS, STOP-BANG scores
4. **Assign interventions** - Test treatment assignment workflow
5. **Monitor treatment progress** - Simulate patient compliance

### Testing Workflow

1. Generate test users: `npm run test:generate-users:100`
2. Login to physician dashboard
3. Enable developer mode for specific patients
4. Jump to different days to test questionnaire flow
5. Review calculated scores and insights
6. Assign interventions and verify task generation

## Files Reference

| File | Purpose |
|------|---------|
| `convex/testUserGenerator.ts` | Generate diverse test users |
| `convex/testingAPI.ts` | Validation endpoints |
| `convex/crossPlatformValidator.ts` | iOS/Web/Backend consistency |
| `convex/healthKitSimulator.ts` | Sleep/health data generation |
| `convex/clinicalScenarios.ts` | Pre-configured test cases |
| `scripts/test-runner.ts` | CLI orchestration |

## Extending the Test Suite

### Adding New Phenotypes

Edit `SLEEP_PHENOTYPES` in `testUserGenerator.ts`:

```typescript
const SLEEP_PHENOTYPES = {
  // ... existing phenotypes
  my_new_phenotype: {
    name: "My New Phenotype",
    description: "Description of the pattern",
    gatewaysLikely: ["insomnia", "anxiety"],
    isiRange: [15, 21],
    // ... other parameters
  },
};
```

### Adding Clinical Scenarios

Edit `CLINICAL_TEST_CASES` in `clinicalScenarios.ts`:

```typescript
const CLINICAL_TEST_CASES: ClinicalTestCase[] = [
  // ... existing cases
  {
    id: "my_new_scenario",
    name: "My New Clinical Case",
    category: "insomnia",
    expectedGateways: ["insomnia", "anxiety"],
    expectedPhenotype: "tired_but_wired",
    expectedScores: {
      ISI: { range: [15, 21], severity: "moderate" },
    },
    responses: {
      "3": "Yes",
      // ... questionnaire responses
    },
    sleepPattern: "insomnia_onset",
    demographics: {
      ageRange: [30, 50],
      gender: "female",
      bmiRange: [22, 28],
    },
  },
];
```

### Adding Sleep Patterns

Edit `SLEEP_PATTERNS` in `healthKitSimulator.ts`:

```typescript
const SLEEP_PATTERNS: Record<string, SleepPattern> = {
  // ... existing patterns
  my_pattern: {
    name: "My Pattern",
    description: "Pattern description",
    bedtimeRange: ["23:00", "00:00"],
    wakeTimeRange: ["07:00", "08:00"],
    // ... other parameters
  },
};
```
