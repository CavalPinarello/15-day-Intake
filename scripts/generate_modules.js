const fs = require('fs');
const path = require('path');

const QUESTIONS_PATH = path.resolve(__dirname, '..', 'data', 'sleep360_questions.json');
const MODULES_PATH = path.resolve(__dirname, '..', 'data', 'assessment_modules.json');
const DAY_PLAN_PATH = path.resolve(__dirname, '..', 'data', 'default_day_plan.json');

const questions = JSON.parse(fs.readFileSync(QUESTIONS_PATH, 'utf8'));

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

function tierType(tier) {
  if (tier === 'CORE') return 'core';
  if (tier === 'GATEWAY') return 'gateway';
  return 'expansion';
}

const modulesMap = new Map();

for (const q of questions) {
  const pillarSlug = slugify(q.pillar);
  const tierSlug = q.tier.toLowerCase();
  const moduleId = `${tierSlug}_${pillarSlug}`;

  if (!modulesMap.has(moduleId)) {
    modulesMap.set(moduleId, {
      moduleId,
      name: `${q.pillar} ${q.tier}`,
      description: `${q.tier} questions for ${q.pillar}`,
      pillar: q.pillar,
      tier: q.tier,
      moduleType: tierType(q.tier),
      questionIds: [],
      estimatedMinutes: 0,
    });
  }

  const module = modulesMap.get(moduleId);
  module.questionIds.push(q.id);
  module.estimatedMinutes += q.timeMinutes || 0.5;
}

const modules = Array.from(modulesMap.values()).map((module) => ({
  ...module,
  estimatedMinutes: Math.round(module.estimatedMinutes * 10) / 10,
}));

fs.writeFileSync(MODULES_PATH, JSON.stringify(modules, null, 2), 'utf8');
console.log(`Generated ${modules.length} modules -> ${MODULES_PATH}`);

// Create a naive default day plan (core modules spread over first 6 days)
const coreModules = modules.filter((m) => m.tier === 'CORE');
const gatewayModules = modules.filter((m) => m.tier === 'GATEWAY');
const expansionModules = modules.filter((m) => m.tier === 'EXPANSION');

const dayPlan = [];
let dayNumber = 1;

function assignModules(list) {
  for (const mod of list) {
    dayPlan.push({
      dayNumber,
      moduleId: mod.moduleId,
      estimatedMinutes: mod.estimatedMinutes,
    });
    dayNumber += 1;
  }
}

assignModules(coreModules);
assignModules(gatewayModules);

// Expansion modules are queued for later days by default (after core/gateways)
expansionModules.forEach((mod, index) => {
  dayPlan.push({
    dayNumber: coreModules.length + gatewayModules.length + index + 1,
    moduleId: mod.moduleId,
    estimatedMinutes: mod.estimatedMinutes,
  });
});

fs.writeFileSync(DAY_PLAN_PATH, JSON.stringify(dayPlan, null, 2), 'utf8');
console.log(`Generated default day plan (${dayPlan.length} entries) -> ${DAY_PLAN_PATH}`);

