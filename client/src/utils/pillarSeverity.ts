/**
 * Pillar Severity Utilities
 * Shared utilities for calculating clinical severity levels for health pillars
 */

export type SeverityLevel = "normal" | "mild" | "moderate" | "severe" | "unknown";

export interface PillarSeverity {
  name: string;
  level: SeverityLevel;
  value?: number;
  label?: string;
}

// Severity color mapping for UI
export const severityColors: Record<SeverityLevel, { bg: string; text: string; border: string; dot: string }> = {
  normal: { bg: "bg-green-500/20", text: "text-green-400", border: "border-green-500/30", dot: "bg-green-500" },
  mild: { bg: "bg-yellow-500/20", text: "text-yellow-400", border: "border-yellow-500/30", dot: "bg-yellow-500" },
  moderate: { bg: "bg-orange-500/20", text: "text-orange-400", border: "border-orange-500/30", dot: "bg-orange-500" },
  severe: { bg: "bg-red-500/20", text: "text-red-400", border: "border-red-500/30", dot: "bg-red-500" },
  unknown: { bg: "bg-gray-500/20", text: "text-gray-400", border: "border-gray-500/30", dot: "bg-gray-500" },
};

// Score thresholds for each questionnaire
export const scoreThresholds: Record<string, { ranges: Array<{ max: number; severity: SeverityLevel; label: string }> }> = {
  ISI: {
    ranges: [
      { max: 7, severity: "normal", label: "No clinically significant insomnia" },
      { max: 14, severity: "mild", label: "Subthreshold insomnia" },
      { max: 21, severity: "moderate", label: "Clinical insomnia (moderate)" },
      { max: 28, severity: "severe", label: "Clinical insomnia (severe)" },
    ],
  },
  "PHQ-9": {
    ranges: [
      { max: 4, severity: "normal", label: "Minimal depression" },
      { max: 9, severity: "mild", label: "Mild depression" },
      { max: 14, severity: "moderate", label: "Moderate depression" },
      { max: 19, severity: "moderate", label: "Moderately severe depression" },
      { max: 27, severity: "severe", label: "Severe depression" },
    ],
  },
  "GAD-7": {
    ranges: [
      { max: 4, severity: "normal", label: "Minimal anxiety" },
      { max: 9, severity: "mild", label: "Mild anxiety" },
      { max: 14, severity: "moderate", label: "Moderate anxiety" },
      { max: 21, severity: "severe", label: "Severe anxiety" },
    ],
  },
  ESS: {
    ranges: [
      { max: 7, severity: "normal", label: "Normal daytime sleepiness" },
      { max: 12, severity: "mild", label: "Mild excessive daytime sleepiness" },
      { max: 15, severity: "moderate", label: "Moderate excessive daytime sleepiness" },
      { max: 24, severity: "severe", label: "Severe excessive daytime sleepiness" },
    ],
  },
  "STOP-BANG": {
    ranges: [
      { max: 2, severity: "normal", label: "Low risk for OSA" },
      { max: 4, severity: "mild", label: "Intermediate risk for OSA" },
      { max: 8, severity: "moderate", label: "High risk for OSA" },
    ],
  },
  PSQI: {
    ranges: [
      { max: 5, severity: "normal", label: "Good sleep quality" },
      { max: 10, severity: "mild", label: "Poor sleep quality" },
      { max: 15, severity: "moderate", label: "Moderate sleep difficulty" },
      { max: 21, severity: "severe", label: "Severe sleep difficulty" },
    ],
  },
  "DBAS-16": {
    ranges: [
      { max: 40, severity: "normal", label: "Low dysfunctional beliefs" },
      { max: 80, severity: "mild", label: "Mild dysfunctional beliefs" },
      { max: 120, severity: "moderate", label: "Moderate dysfunctional beliefs" },
      { max: 160, severity: "severe", label: "Severe dysfunctional beliefs" },
    ],
  },
  FSS: {
    ranges: [
      { max: 3, severity: "normal", label: "No significant fatigue" },
      { max: 4, severity: "mild", label: "Mild fatigue" },
      { max: 5, severity: "moderate", label: "Moderate fatigue" },
      { max: 7, severity: "severe", label: "Severe fatigue" },
    ],
  },
  BPI: {
    ranges: [
      { max: 3, severity: "normal", label: "Mild pain" },
      { max: 5, severity: "mild", label: "Moderate pain" },
      { max: 7, severity: "moderate", label: "Moderately severe pain" },
      { max: 10, severity: "severe", label: "Severe pain" },
    ],
  },
  MEDAS: {
    ranges: [
      { max: 5, severity: "severe", label: "Poor Mediterranean diet adherence" },
      { max: 8, severity: "moderate", label: "Moderate Mediterranean diet adherence" },
      { max: 11, severity: "mild", label: "Good Mediterranean diet adherence" },
      { max: 14, severity: "normal", label: "High Mediterranean diet adherence" },
    ],
  },
  MEQ: {
    ranges: [
      { max: 30, severity: "severe", label: "Definite evening type" },
      { max: 41, severity: "moderate", label: "Moderate evening type" },
      { max: 58, severity: "normal", label: "Neither type (intermediate)" },
      { max: 69, severity: "mild", label: "Moderate morning type" },
      { max: 86, severity: "normal", label: "Definite morning type" },
    ],
  },
  BMI: {
    ranges: [
      { max: 18.5, severity: "mild", label: "Underweight" },
      { max: 24.9, severity: "normal", label: "Normal weight" },
      { max: 29.9, severity: "mild", label: "Overweight" },
      { max: 34.9, severity: "moderate", label: "Obese Class I" },
      { max: 39.9, severity: "severe", label: "Obese Class II" },
      { max: 100, severity: "severe", label: "Obese Class III" },
    ],
  },
};

// Map full questionnaire names to abbreviations
const questionnaireNameToAbbreviation: Record<string, string> = {
  "Insomnia Severity Index": "ISI",
  "Patient Health Questionnaire": "PHQ-9",
  "Patient Health Questionnaire-9": "PHQ-9",
  "Generalized Anxiety Disorder": "GAD-7",
  "Generalized Anxiety Disorder-7": "GAD-7",
  "Epworth Sleepiness Scale": "ESS",
  "STOP-BANG Sleep Apnea Screening": "STOP-BANG",
  "Pittsburgh Sleep Quality Index": "PSQI",
  "Dysfunctional Beliefs and Attitudes about Sleep": "DBAS-16",
  "Fatigue Severity Scale": "FSS",
  "Brief Pain Inventory": "BPI",
  "Mediterranean Diet Adherence Screener": "MEDAS",
  "Morningness-Eveningness Questionnaire": "MEQ",
};

/**
 * Get severity level for a clinical score
 */
export function getSeverityForScore(questionnaireName: string, score: number): { level: SeverityLevel; label: string } {
  // Try direct lookup first
  let thresholds = scoreThresholds[questionnaireName];

  // If not found, try normalized abbreviation
  if (!thresholds) {
    const abbreviation = questionnaireNameToAbbreviation[questionnaireName];
    if (abbreviation) {
      thresholds = scoreThresholds[abbreviation];
    }
  }

  if (!thresholds) return { level: "unknown", label: "Unknown" };

  for (const range of thresholds.ranges) {
    if (score <= range.max) {
      return { level: range.severity, label: range.label };
    }
  }
  return { level: "severe", label: "Severe" };
}

// Pillar to clinical score mapping
export type PillarKey =
  | "social"
  | "metabolic"
  | "sleepQuality"
  | "sleepQuantity"
  | "sleepRegularity"
  | "sleepTiming"
  | "mentalHealth"
  | "cognitive"
  | "physical"
  | "nutritional"
  | "sleepLog";

export const PILLAR_SCORE_MAPPING: Record<PillarKey, { scores: string[]; derived?: boolean }> = {
  sleepQuality: { scores: ["PSQI"] },
  sleepQuantity: { scores: [], derived: true }, // Derived from sleep log avg hours
  sleepRegularity: { scores: [], derived: true }, // Derived from sleep log variance
  sleepTiming: { scores: ["MEQ"] },
  mentalHealth: { scores: ["PHQ-9", "GAD-7"] }, // Show BOTH dots
  cognitive: { scores: ["DBAS-16"] },
  physical: { scores: ["BPI"] },
  nutritional: { scores: ["MEDAS"] },
  social: { scores: [], derived: true }, // Derived from responses
  metabolic: { scores: [], derived: true }, // Derived from BMI
  sleepLog: { scores: ["ISI", "ESS"] }, // Show worst-case
};

/**
 * Calculate severity for a pillar based on available clinical scores
 */
export function getPillarSeverities(
  pillarKey: PillarKey,
  scores: Record<string, number | undefined>,
  responses?: Record<string, unknown>
): PillarSeverity[] {
  const mapping = PILLAR_SCORE_MAPPING[pillarKey];
  const severities: PillarSeverity[] = [];

  // Handle pillars with clinical scores
  for (const scoreName of mapping.scores) {
    const scoreValue = scores[scoreName];
    if (scoreValue !== undefined && scoreValue !== null) {
      const { level, label } = getSeverityForScore(scoreName, scoreValue);
      severities.push({
        name: scoreName,
        level,
        value: scoreValue,
        label,
      });
    }
  }

  // Handle derived severities for pillars without clinical scores
  if (mapping.derived && severities.length === 0) {
    const derived = getDerivedSeverity(pillarKey, scores, responses);
    if (derived) {
      severities.push(derived);
    }
  }

  // For Sleep Log, show worst-case if multiple scores exist
  if (pillarKey === "sleepLog" && severities.length > 1) {
    const worstSeverity = getWorstSeverity(severities);
    return [worstSeverity];
  }

  return severities;
}

/**
 * Derive severity for pillars without dedicated clinical scores
 */
function getDerivedSeverity(
  pillarKey: PillarKey,
  scores: Record<string, number | undefined>,
  responses?: Record<string, unknown>
): PillarSeverity | null {
  switch (pillarKey) {
    case "metabolic":
      return deriveMetabolicSeverity(scores, responses);
    case "social":
      return deriveSocialSeverity(responses);
    case "sleepQuantity":
      return deriveSleepQuantitySeverity(scores);
    case "sleepRegularity":
      return deriveSleepRegularitySeverity(scores);
    default:
      return null;
  }
}

/**
 * Derive metabolic severity from BMI and health conditions
 */
function deriveMetabolicSeverity(
  scores: Record<string, number | undefined>,
  responses?: Record<string, unknown>
): PillarSeverity | null {
  // Check if BMI is available
  const bmi = scores["BMI"];
  if (bmi !== undefined && bmi !== null) {
    const { level, label } = getSeverityForScore("BMI", bmi);
    return { name: "BMI", level, value: bmi, label };
  }

  // Try to calculate BMI from height/weight responses
  if (responses) {
    const height = responses["D5"] as number | undefined; // Height in cm
    const weight = responses["D6"] as number | undefined; // Weight in kg
    if (height && weight && height > 0) {
      const heightM = height / 100;
      const calculatedBmi = weight / (heightM * heightM);
      const { level, label } = getSeverityForScore("BMI", calculatedBmi);
      return { name: "BMI", level, value: Math.round(calculatedBmi * 10) / 10, label };
    }
  }

  return null;
}

/**
 * Derive social severity from relationship and support responses
 */
function deriveSocialSeverity(responses?: Record<string, unknown>): PillarSeverity | null {
  if (!responses) return null;

  let concernScore = 0;
  let questionsAnswered = 0;

  // Q35: Social support satisfaction (1-5 scale, lower = worse)
  const socialSupport = responses["35"] as number | undefined;
  if (socialSupport !== undefined) {
    questionsAnswered++;
    if (socialSupport <= 2) concernScore += 2;
    else if (socialSupport <= 3) concernScore += 1;
  }

  // Q36: Relationship satisfaction (1-5 scale, lower = worse)
  const relationshipSat = responses["36"] as number | undefined;
  if (relationshipSat !== undefined) {
    questionsAnswered++;
    if (relationshipSat <= 2) concernScore += 2;
    else if (relationshipSat <= 3) concernScore += 1;
  }

  // Q53B: Shift work (yes = concern)
  const shiftWork = responses["53B"];
  if (shiftWork === true || shiftWork === "yes" || shiftWork === 1) {
    questionsAnswered++;
    concernScore += 1;
  }

  if (questionsAnswered === 0) return null;

  // Calculate severity based on concern score
  let level: SeverityLevel;
  let label: string;
  if (concernScore === 0) {
    level = "normal";
    label = "Good social support";
  } else if (concernScore <= 1) {
    level = "mild";
    label = "Some social concerns";
  } else if (concernScore <= 3) {
    level = "moderate";
    label = "Moderate social concerns";
  } else {
    level = "severe";
    label = "Significant social concerns";
  }

  return { name: "Social", level, label };
}

/**
 * Derive sleep quantity severity from average sleep hours
 */
function deriveSleepQuantitySeverity(scores: Record<string, number | undefined>): PillarSeverity | null {
  const avgHours = scores["avgSleepHours"];
  if (avgHours === undefined || avgHours === null) return null;

  let level: SeverityLevel;
  let label: string;
  if (avgHours >= 7) {
    level = "normal";
    label = "Adequate sleep duration";
  } else if (avgHours >= 6) {
    level = "mild";
    label = "Slightly reduced sleep";
  } else if (avgHours >= 5) {
    level = "moderate";
    label = "Insufficient sleep";
  } else {
    level = "severe";
    label = "Severely insufficient sleep";
  }

  return { name: "Sleep Hours", level, value: avgHours, label };
}

/**
 * Derive sleep regularity severity from bedtime variance
 */
function deriveSleepRegularitySeverity(scores: Record<string, number | undefined>): PillarSeverity | null {
  const variance = scores["bedtimeVariance"]; // Standard deviation in minutes
  if (variance === undefined || variance === null) return null;

  let level: SeverityLevel;
  let label: string;
  if (variance <= 30) {
    level = "normal";
    label = "Consistent sleep schedule";
  } else if (variance <= 60) {
    level = "mild";
    label = "Slightly irregular schedule";
  } else if (variance <= 90) {
    level = "moderate";
    label = "Irregular sleep schedule";
  } else {
    level = "severe";
    label = "Highly irregular schedule";
  }

  return { name: "Regularity", level, value: variance, label };
}

/**
 * Get the worst (most severe) severity from an array
 */
function getWorstSeverity(severities: PillarSeverity[]): PillarSeverity {
  const severityOrder: SeverityLevel[] = ["normal", "mild", "moderate", "severe", "unknown"];

  let worst = severities[0];
  for (const s of severities) {
    if (severityOrder.indexOf(s.level) > severityOrder.indexOf(worst.level)) {
      worst = s;
    }
  }
  return worst;
}

/**
 * Get the dot color class for a severity level
 */
export function getSeverityDotColor(level: SeverityLevel): string {
  return severityColors[level].dot;
}

/**
 * Get the text color class for a severity level
 */
export function getSeverityTextColor(level: SeverityLevel): string {
  return severityColors[level].text;
}
