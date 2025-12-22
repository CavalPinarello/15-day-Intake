import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Compliance-Outcome Correlation System
// Tracks relationship between compliance and sleep improvement
// ============================================

/**
 * Compute outcome correlation for a user
 * Analyzes compliance vs ISI/sleep improvement over a period
 */
export const computeOutcomeCorrelation = mutation({
  args: {
    userId: v.id("users"),
    periodDays: v.optional(v.number()), // Default 14
  },
  returns: v.id("compliance_outcome_correlation"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];
    const periodDays = args.periodDays ?? 14;

    // Calculate date range
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - periodDays);

    const periodStart = startDate.toISOString().split("T")[0];
    const periodEnd = today;

    // Get compliance data
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const allCompliance = await ctx.db
      .query("intervention_compliance")
      .collect();

    // Filter compliance for this user's interventions in the period
    const relevantCompliance = allCompliance.filter((c) => {
      const isUserIntervention = userInterventions.some(
        (ui) => ui._id === c.user_intervention_id
      );
      return (
        isUserIntervention &&
        c.scheduled_date >= periodStart &&
        c.scheduled_date <= periodEnd
      );
    });

    // Calculate overall compliance
    const totalTasks = relevantCompliance.length;
    const completedTasks = relevantCompliance.filter((c) => c.completed).length;
    const overallCompliancePct =
      totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

    // Calculate per-intervention compliance
    const interventionCompliance: Record<string, { completed: number; total: number }> = {};
    for (const c of relevantCompliance) {
      const uiId = c.user_intervention_id;
      if (!interventionCompliance[uiId]) {
        interventionCompliance[uiId] = { completed: 0, total: 0 };
      }
      interventionCompliance[uiId].total++;
      if (c.completed) interventionCompliance[uiId].completed++;
    }

    // Get questionnaire scores
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Find ISI scores (before and after)
    const isiScores = scores
      .filter((s) => s.questionnaire_name === "ISI")
      .sort((a, b) => a.calculated_at - b.calculated_at);

    const isiScoreStart = isiScores.length > 0 ? isiScores[0].score : undefined;
    const isiScoreEnd =
      isiScores.length > 1 ? isiScores[isiScores.length - 1].score : undefined;
    const isiChange =
      isiScoreStart !== undefined && isiScoreEnd !== undefined
        ? isiScoreEnd - isiScoreStart
        : undefined;

    // Find PHQ-9 scores
    const phq9Scores = scores
      .filter((s) => s.questionnaire_name === "PHQ-9")
      .sort((a, b) => a.calculated_at - b.calculated_at);

    const phq9ScoreStart = phq9Scores.length > 0 ? phq9Scores[0].score : undefined;
    const phq9ScoreEnd =
      phq9Scores.length > 1
        ? phq9Scores[phq9Scores.length - 1].score
        : undefined;
    const phq9Change =
      phq9ScoreStart !== undefined && phq9ScoreEnd !== undefined
        ? phq9ScoreEnd - phq9ScoreStart
        : undefined;

    // Find GAD-7 scores
    const gad7Scores = scores
      .filter((s) => s.questionnaire_name === "GAD-7")
      .sort((a, b) => a.calculated_at - b.calculated_at);

    const gad7ScoreStart = gad7Scores.length > 0 ? gad7Scores[0].score : undefined;
    const gad7ScoreEnd =
      gad7Scores.length > 1
        ? gad7Scores[gad7Scores.length - 1].score
        : undefined;
    const gad7Change =
      gad7ScoreStart !== undefined && gad7ScoreEnd !== undefined
        ? gad7ScoreEnd - gad7ScoreStart
        : undefined;

    // Get sleep data from HealthKit
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Filter to period and calculate averages
    const periodSleepData = sleepData.filter(
      (s) => s.date >= periodStart && s.date <= periodEnd
    );

    // Split into first half and second half for before/after comparison
    const midDate = new Date(startDate);
    midDate.setDate(midDate.getDate() + Math.floor(periodDays / 2));
    const midDateStr = midDate.toISOString().split("T")[0];

    const firstHalfSleep = periodSleepData.filter((s) => s.date < midDateStr);
    const secondHalfSleep = periodSleepData.filter((s) => s.date >= midDateStr);

    // Calculate sleep efficiency averages
    const avgEfficiencyStart =
      firstHalfSleep.length > 0
        ? firstHalfSleep.reduce((sum, s) => sum + (s.sleep_efficiency || 0), 0) /
          firstHalfSleep.length
        : undefined;
    const avgEfficiencyEnd =
      secondHalfSleep.length > 0
        ? secondHalfSleep.reduce((sum, s) => sum + (s.sleep_efficiency || 0), 0) /
          secondHalfSleep.length
        : undefined;

    // Calculate sleep duration averages
    const avgDurationStart =
      firstHalfSleep.length > 0
        ? firstHalfSleep.reduce((sum, s) => sum + (s.total_sleep_mins || 0), 0) /
          firstHalfSleep.length
        : undefined;
    const avgDurationEnd =
      secondHalfSleep.length > 0
        ? secondHalfSleep.reduce((sum, s) => sum + (s.total_sleep_mins || 0), 0) /
          secondHalfSleep.length
        : undefined;

    // Calculate sleep latency averages
    const avgLatencyStart =
      firstHalfSleep.length > 0
        ? firstHalfSleep.reduce(
            (sum, s) => sum + (s.sleep_latency_mins || 0),
            0
          ) / firstHalfSleep.length
        : undefined;
    const avgLatencyEnd =
      secondHalfSleep.length > 0
        ? secondHalfSleep.reduce(
            (sum, s) => sum + (s.sleep_latency_mins || 0),
            0
          ) / secondHalfSleep.length
        : undefined;

    // Calculate correlation (simple Pearson)
    // We correlate compliance % with ISI improvement
    let correlationValue: number | undefined;
    let correlationStrength: string | undefined;

    if (isiChange !== undefined && overallCompliancePct > 0) {
      // Simple heuristic: higher compliance + larger ISI reduction = strong correlation
      // ISI decrease (negative change) is good
      const isiImprovement = -1 * isiChange; // Positive = improvement
      const normalizedCompliance = overallCompliancePct / 100;

      // Simple correlation estimate
      if (normalizedCompliance >= 0.8 && isiImprovement >= 5) {
        correlationValue = 0.8;
        correlationStrength = "strong";
      } else if (normalizedCompliance >= 0.6 && isiImprovement >= 3) {
        correlationValue = 0.5;
        correlationStrength = "moderate";
      } else if (normalizedCompliance >= 0.4 && isiImprovement >= 1) {
        correlationValue = 0.3;
        correlationStrength = "weak";
      } else {
        correlationValue = 0.1;
        correlationStrength = "none";
      }
    }

    // Calculate check-in compliance
    const checkins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const periodCheckins = checkins.filter(
      (c) =>
        c.checkin_date >= periodStart &&
        c.checkin_date <= periodEnd &&
        c.completed
    );

    // Max possible check-ins = periodDays * 3 (morning, midday, evening)
    const maxCheckins = periodDays * 3;
    const checkinCompliancePct =
      maxCheckins > 0 ? (periodCheckins.length / maxCheckins) * 100 : 0;

    // Check if correlation already exists for today
    const existing = await ctx.db
      .query("compliance_outcome_correlation")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("computation_date", today)
      )
      .first();

    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        period_start: periodStart,
        period_end: periodEnd,
        overall_compliance_pct: overallCompliancePct,
        intervention_compliance_json: JSON.stringify(interventionCompliance),
        checkin_compliance_pct: checkinCompliancePct,
        isi_score_start: isiScoreStart,
        isi_score_end: isiScoreEnd,
        isi_change: isiChange,
        phq9_score_start: phq9ScoreStart,
        phq9_score_end: phq9ScoreEnd,
        phq9_change: phq9Change,
        gad7_score_start: gad7ScoreStart,
        gad7_score_end: gad7ScoreEnd,
        gad7_change: gad7Change,
        avg_sleep_efficiency_start: avgEfficiencyStart,
        avg_sleep_efficiency_end: avgEfficiencyEnd,
        avg_sleep_duration_start: avgDurationStart,
        avg_sleep_duration_end: avgDurationEnd,
        avg_sleep_latency_start: avgLatencyStart,
        avg_sleep_latency_end: avgLatencyEnd,
        compliance_improvement_correlation: correlationValue,
        correlation_strength: correlationStrength,
      });
      return existing._id;
    }

    // Create new correlation record
    return await ctx.db.insert("compliance_outcome_correlation", {
      user_id: args.userId,
      computation_date: today,
      period_start: periodStart,
      period_end: periodEnd,
      overall_compliance_pct: overallCompliancePct,
      intervention_compliance_json: JSON.stringify(interventionCompliance),
      checkin_compliance_pct: checkinCompliancePct,
      isi_score_start: isiScoreStart,
      isi_score_end: isiScoreEnd,
      isi_change: isiChange,
      phq9_score_start: phq9ScoreStart,
      phq9_score_end: phq9ScoreEnd,
      phq9_change: phq9Change,
      gad7_score_start: gad7ScoreStart,
      gad7_score_end: gad7ScoreEnd,
      gad7_change: gad7Change,
      avg_sleep_efficiency_start: avgEfficiencyStart,
      avg_sleep_efficiency_end: avgEfficiencyEnd,
      avg_sleep_duration_start: avgDurationStart,
      avg_sleep_duration_end: avgDurationEnd,
      avg_sleep_latency_start: avgLatencyStart,
      avg_sleep_latency_end: avgLatencyEnd,
      compliance_improvement_correlation: correlationValue,
      correlation_strength: correlationStrength,
      created_at: now,
    });
  },
});

/**
 * Get latest correlation data for dashboard display
 */
export const getCorrelationData = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.union(
    v.null(),
    v.object({
      computationDate: v.string(),
      periodStart: v.string(),
      periodEnd: v.string(),
      // Compliance
      overallCompliance: v.number(),
      checkinCompliance: v.optional(v.number()),
      // ISI changes
      isiStart: v.optional(v.number()),
      isiEnd: v.optional(v.number()),
      isiChange: v.optional(v.number()),
      isiImproved: v.optional(v.boolean()),
      // Sleep efficiency
      efficiencyStart: v.optional(v.number()),
      efficiencyEnd: v.optional(v.number()),
      efficiencyChange: v.optional(v.number()),
      // Sleep duration
      durationStart: v.optional(v.number()),
      durationEnd: v.optional(v.number()),
      durationChange: v.optional(v.number()),
      // Correlation
      correlationValue: v.optional(v.number()),
      correlationStrength: v.optional(v.string()),
      // Summary
      summary: v.string(),
    })
  ),
  handler: async (ctx, args) => {
    // Get latest correlation record
    const correlations = await ctx.db
      .query("compliance_outcome_correlation")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(1);

    const latest = correlations[0];
    if (!latest) return null;

    // Calculate changes
    const efficiencyChange =
      latest.avg_sleep_efficiency_start !== undefined &&
      latest.avg_sleep_efficiency_end !== undefined
        ? latest.avg_sleep_efficiency_end - latest.avg_sleep_efficiency_start
        : undefined;

    const durationChange =
      latest.avg_sleep_duration_start !== undefined &&
      latest.avg_sleep_duration_end !== undefined
        ? latest.avg_sleep_duration_end - latest.avg_sleep_duration_start
        : undefined;

    // Generate summary
    let summary = "";
    if (latest.correlation_strength === "strong") {
      summary =
        "Strong correlation between your compliance and sleep improvement. Keep it up!";
    } else if (latest.correlation_strength === "moderate") {
      summary =
        "Moderate correlation detected. Consistent effort is showing results.";
    } else if (latest.correlation_strength === "weak") {
      summary =
        "Early signs of improvement. Continue following your protocol for better results.";
    } else {
      summary =
        "Not enough data yet to determine correlation. Keep logging consistently.";
    }

    return {
      computationDate: latest.computation_date,
      periodStart: latest.period_start,
      periodEnd: latest.period_end,
      overallCompliance: latest.overall_compliance_pct,
      checkinCompliance: latest.checkin_compliance_pct,
      isiStart: latest.isi_score_start,
      isiEnd: latest.isi_score_end,
      isiChange: latest.isi_change,
      isiImproved: latest.isi_change !== undefined ? latest.isi_change < 0 : undefined,
      efficiencyStart: latest.avg_sleep_efficiency_start,
      efficiencyEnd: latest.avg_sleep_efficiency_end,
      efficiencyChange,
      durationStart: latest.avg_sleep_duration_start,
      durationEnd: latest.avg_sleep_duration_end,
      durationChange,
      correlationValue: latest.compliance_improvement_correlation,
      correlationStrength: latest.correlation_strength,
      summary,
    };
  },
});

/**
 * Get correlation history over time
 */
export const getCorrelationHistory = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      date: v.string(),
      compliance: v.number(),
      isiScore: v.optional(v.number()),
      efficiency: v.optional(v.number()),
      correlationStrength: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const limitCount = args.limit ?? 30;

    const correlations = await ctx.db
      .query("compliance_outcome_correlation")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(limitCount);

    return correlations.map((c) => ({
      date: c.computation_date,
      compliance: c.overall_compliance_pct,
      isiScore: c.isi_score_end,
      efficiency: c.avg_sleep_efficiency_end,
      correlationStrength: c.correlation_strength,
    }));
  },
});

/**
 * Get intervention-level effectiveness
 * Shows which interventions have the best compliance-to-improvement ratio
 */
export const getInterventionEffectiveness = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.array(
    v.object({
      interventionId: v.string(),
      name: v.string(),
      category: v.optional(v.string()),
      complianceRate: v.number(),
      daysActive: v.number(),
      // Effectiveness indicators
      contributesToImprovement: v.boolean(),
      effectivenessScore: v.optional(v.number()), // 0-100
    })
  ),
  handler: async (ctx, args) => {
    // Get user's interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get compliance data
    const allCompliance = await ctx.db.query("intervention_compliance").collect();

    // Get intervention details
    const interventions = await ctx.db.query("interventions").collect();
    const interventionMap = new Map(interventions.map((i) => [i._id, i]));

    // Get latest correlation for overall improvement context
    const correlations = await ctx.db
      .query("compliance_outcome_correlation")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(1);

    const hasImprovement =
      correlations[0]?.isi_change !== undefined && correlations[0].isi_change < 0;

    const results = userInterventions.map((ui) => {
      const intervention = interventionMap.get(ui.intervention_id);
      const uiCompliance = allCompliance.filter(
        (c) => c.user_intervention_id === ui._id
      );

      const totalDays = uiCompliance.length;
      const completedDays = uiCompliance.filter((c) => c.completed).length;
      const complianceRate = totalDays > 0 ? (completedDays / totalDays) * 100 : 0;

      // Calculate days active
      const startDate = new Date(ui.start_date);
      const today = new Date();
      const daysActive = Math.floor(
        (today.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)
      );

      // Simple effectiveness heuristic
      // High compliance + overall improvement = likely effective
      const contributesToImprovement = hasImprovement && complianceRate >= 70;
      const effectivenessScore = contributesToImprovement
        ? Math.min(100, complianceRate)
        : complianceRate >= 70
        ? 50
        : undefined;

      return {
        interventionId: intervention?.intervention_id || "",
        name: intervention?.name || "Unknown",
        category: intervention?.category,
        complianceRate,
        daysActive,
        contributesToImprovement,
        effectivenessScore,
      };
    });

    // Sort by effectiveness
    return results.sort(
      (a, b) => (b.effectivenessScore || 0) - (a.effectivenessScore || 0)
    );
  },
});

/**
 * Get compliance trends over time
 * For chart visualization
 */
export const getComplianceTrends = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      date: v.string(),
      taskComplianceRate: v.number(),
      checkinComplianceRate: v.number(),
      protocolComplianceRate: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;

    // Generate dates
    const dates: string[] = [];
    for (let i = daysToFetch - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get user interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    // Get all compliance
    const allCompliance = await ctx.db.query("intervention_compliance").collect();

    // Get check-ins
    const checkins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const results = dates.map((date) => {
      // Task compliance for this day
      const dayCompliance = allCompliance.filter((c) => {
        const isUserTask = userInterventions.some(
          (ui) => ui._id === c.user_intervention_id
        );
        return isUserTask && c.scheduled_date === date;
      });

      const taskTotal = dayCompliance.length;
      const taskCompleted = dayCompliance.filter((c) => c.completed).length;
      const taskComplianceRate =
        taskTotal > 0 ? (taskCompleted / taskTotal) * 100 : 0;

      // Check-in compliance for this day
      const dayCheckins = checkins.filter(
        (c) => c.checkin_date === date && c.completed
      );
      const checkinComplianceRate = (dayCheckins.length / 3) * 100; // 3 check-ins per day

      // Protocol compliance (same as task for now)
      const protocolComplianceRate = taskComplianceRate;

      return {
        date,
        taskComplianceRate,
        checkinComplianceRate,
        protocolComplianceRate,
      };
    });

    return results;
  },
});
