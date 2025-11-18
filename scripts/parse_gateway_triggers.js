const fs = require('fs');
const path = require('path');

/**
 * Parse CSV and extract gateway trigger conditions
 * Maps question IDs to trigger rules and expansion modules
 */

const CSV_PATH = path.join(__dirname, '../../Downloads/Sleep_360_MODIFIED_Nov 11.xlsx - MASTER.csv');
const OUTPUT_PATH = path.join(__dirname, '../data/gateway_triggers.json');

// Fallback: Try absolute path if relative doesn't work
const CSV_ABS_PATH = '/Users/martinkawalski/Downloads/Sleep_360_MODIFIED_Nov 11.xlsx - MASTER.csv';

function parseCSVLine(line) {
  const values = [];
  let current = '';
  let inQuotes = false;
  
  for (let j = 0; j < line.length; j++) {
    const char = line[j];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      values.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  values.push(current.trim());
  
  return values;
}

function parseCSV(content) {
  const lines = content.split('\n').map(line => line.trim()).filter(line => line && !line.match(/^,+$/));
  
  // Find header line (usually line with #,Question,Pillar, etc.)
  let headerLineIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('#') && lines[i].includes('Question') && lines[i].includes('Pillar')) {
      headerLineIdx = i;
      break;
    }
  }
  
  if (headerLineIdx === -1) {
    throw new Error('Could not find header line in CSV');
  }
  
  const headers = parseCSVLine(lines[headerLineIdx]);
  
  // Find indices
  const questionIdx = headers.findIndex(h => h === '#' || h.startsWith('#'));
  const textIdx = headers.findIndex(h => h === 'Question' || h.includes('Question'));
  const pillarIdx = headers.findIndex(h => h === 'Pillar' || h.includes('Pillar'));
  const tierIdx = headers.findIndex(h => h === 'Tier' || h.includes('Tier'));
  const triggerIdx = headers.findIndex(h => h === 'Gateway Trigger' || h.includes('Gateway') || h.includes('Trigger'));
  const scaleIdx = headers.findIndex(h => h === 'Scale/Type' || h.includes('Scale') || h.includes('Type'));
  
  const questions = [];
  const gatewayTriggers = [];
  
  for (let i = headerLineIdx + 1; i < lines.length; i++) {
    const line = lines[i];
    
    // Skip section headers and empty lines
    if (!line || 
        line.startsWith('STATIC') || 
        line.startsWith('---') || 
        line.startsWith('#,') ||
        line.match(/^,+$/)) {
      continue;
    }
    
    const values = parseCSVLine(line);
    
    // Skip if not enough values
    if (values.length < Math.max(questionIdx, textIdx, pillarIdx, tierIdx) + 1) {
      continue;
    }
    
    const questionId = values[questionIdx]?.trim();
    const questionText = values[textIdx]?.trim();
    const pillar = values[pillarIdx]?.trim();
    const tier = values[tierIdx]?.trim();
    const trigger = triggerIdx >= 0 ? values[triggerIdx]?.trim() : '';
    const scaleType = scaleIdx >= 0 ? values[scaleIdx]?.trim() : '';
    
    // Skip if no question ID
    if (!questionId || questionId === '' || questionId === '-') continue;
    
    questions.push({
      id: questionId,
      text: questionText || '',
      pillar: pillar || '',
      tier: tier || '',
      trigger: trigger || '',
      scaleType: scaleType || ''
    });
    
    // Identify gateway questions and expansion triggers
    if (tier === 'GATEWAY' || (trigger && trigger !== 'Always' && trigger !== '-' && trigger !== '')) {
      gatewayTriggers.push({
        questionId,
        questionText,
        pillar,
        tier,
        trigger,
        scaleType
      });
    }
  }
  
  return { questions, gatewayTriggers };
}

function buildGatewayRules(questions, gatewayTriggers) {
  const rules = [];
  
  // 1. Insomnia Gateway (Q3)
  rules.push({
    gatewayId: 'insomnia',
    name: 'Insomnia Gateway',
    triggerQuestionIds: ['3'],
    condition: {
      type: 'equals',
      questionId: '3',
      value: 'Yes'
    },
    targetModules: ['expansion_sleep_quality'],
    description: 'Do you have trouble falling asleep, staying asleep, or waking too early?'
  });
  
  // 2. Depression Gateway (Q15)
  rules.push({
    gatewayId: 'depression',
    name: 'Depression Gateway',
    triggerQuestionIds: ['15'],
    condition: {
      type: 'greaterThanOrEqual',
      questionId: '15',
      value: 2
    },
    targetModules: ['expansion_mental_health'],
    description: 'In past 2 weeks, felt down, depressed, or hopeless?'
  });
  
  // 3. Anxiety Gateway (Q16)
  rules.push({
    gatewayId: 'anxiety',
    name: 'Anxiety Gateway',
    triggerQuestionIds: ['16'],
    condition: {
      type: 'greaterThanOrEqual',
      questionId: '16',
      value: 2
    },
    targetModules: ['expansion_mental_health'],
    description: 'In past 2 weeks, felt nervous, anxious, or on edge?'
  });
  
  // 4. Excessive Daytime Sleepiness (Q17)
  rules.push({
    gatewayId: 'excessive_sleepiness',
    name: 'Excessive Daytime Sleepiness',
    triggerQuestionIds: ['17'],
    condition: {
      type: 'greaterThanOrEqual',
      questionId: '17',
      value: 3
    },
    targetModules: ['expansion_cognitive'],
    description: 'Do you feel excessively tired or sleepy during the day?'
  });
  
  // 5. Cognitive Gateway (Q18)
  rules.push({
    gatewayId: 'cognitive',
    name: 'Cognitive Gateway',
    triggerQuestionIds: ['18'],
    condition: {
      type: 'equals',
      questionId: '18',
      value: 'Yes'
    },
    targetModules: ['expansion_cognitive'],
    description: 'Memory problems, difficulty concentrating, or mental fog?'
  });
  
  // 6. OSA Gateway (Q19 OR Q20)
  rules.push({
    gatewayId: 'osa',
    name: 'OSA Gateway',
    triggerQuestionIds: ['19', '20'],
    condition: {
      type: 'or',
      conditions: [
        {
          type: 'equals',
          questionId: '19',
          value: 'Yes'
        },
        {
          type: 'equals',
          questionId: '20',
          value: 'Yes'
        }
      ]
    },
    targetModules: ['expansion_physical'],
    description: 'Do you snore loudly OR has anyone observed you stop breathing during sleep?'
  });
  
  // 7. Pain Gateway (Q22 AND Q23)
  rules.push({
    gatewayId: 'pain',
    name: 'Pain Gateway',
    triggerQuestionIds: ['22', '23'],
    condition: {
      type: 'and',
      conditions: [
        {
          type: 'equals',
          questionId: '22',
          value: 'Yes'
        },
        {
          type: 'greaterThanOrEqual',
          questionId: '23',
          value: 4
        }
      ]
    },
    targetModules: ['expansion_physical'],
    description: 'Do you have pain that affects your sleep AND pain severity ≥ 4?'
  });
  
  // 8. Sleep Timing Gateway (Q7, Q8, Q9, Q10 - calculated)
  rules.push({
    gatewayId: 'sleep_timing',
    name: 'Sleep Timing Gateway',
    triggerQuestionIds: ['7', '8', '9', '10'],
    condition: {
      type: 'calculated',
      function: 'weekdayWeekendDifference',
      threshold: 1
    },
    targetModules: ['expansion_sleep_timing'],
    description: 'Weekday-weekend sleep time difference > 1 hour'
  });
  
  // 9. Diet Impact Gateway (Q34 - if exists)
  rules.push({
    gatewayId: 'diet_impact',
    name: 'Diet Impact Gateway',
    triggerQuestionIds: ['34'],
    condition: {
      type: 'equals',
      questionId: '34',
      value: 'Yes'
    },
    targetModules: ['expansion_nutritional'],
    description: 'Do you notice your diet affects your sleep quality?',
    optional: true // May not exist in all versions
  });
  
  // 10. Poor Sleep Quality (Q1 OR Q3)
  rules.push({
    gatewayId: 'poor_sleep_quality',
    name: 'Poor Sleep Quality',
    triggerQuestionIds: ['1', '3'],
    condition: {
      type: 'or',
      conditions: [
        {
          type: 'lessThanOrEqual',
          questionId: '1',
          value: 5
        },
        {
          type: 'equals',
          questionId: '3',
          value: 'Yes'
        }
      ]
    },
    targetModules: ['expansion_sleep_quality'],
    description: 'Overall sleep quality ≤ 5 OR insomnia gateway = Yes'
  });
  
  return rules;
}

function main() {
  console.log('Reading CSV file...');
  let csvContent;
  try {
    csvContent = fs.readFileSync(CSV_PATH, 'utf-8');
  } catch (err) {
    // Try absolute path as fallback
    csvContent = fs.readFileSync(CSV_ABS_PATH, 'utf-8');
  }
  
  console.log('Parsing CSV...');
  const { questions, gatewayTriggers } = parseCSV(csvContent);
  
  console.log(`Found ${questions.length} questions`);
  console.log(`Found ${gatewayTriggers.length} gateway triggers`);
  
  console.log('Building gateway rules...');
  const rules = buildGatewayRules(questions, gatewayTriggers);
  
  const output = {
    version: '1.0.0',
    generatedAt: new Date().toISOString(),
    gateways: rules,
    metadata: {
      totalGateways: rules.length,
      totalQuestions: questions.length
    }
  };
  
  console.log('Writing gateway triggers to file...');
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2), 'utf-8');
  
  console.log(`✓ Gateway triggers written to ${OUTPUT_PATH}`);
  console.log(`✓ Generated ${rules.length} gateway rules`);
}

if (require.main === module) {
  main();
}

module.exports = { parseCSV, buildGatewayRules };

