/**
 * Convert all questions to standardized answer format
 * This script converts Sleep 360° and Sleep Diary questions
 */

const fs = require('fs');
const path = require('path');

// ============================================
// Conversion Utilities
// ============================================

/**
 * Convert old scaleType to new answer_format
 */
function convertScaleType(scaleType) {
  const lowerType = (scaleType || '').toLowerCase();
  
  // Yes/No variations
  if (lowerType.includes('yes/no')) {
    return 'single_select_chips';
  }
  
  // Scale variations
  if (lowerType.includes('scale') || lowerType.includes('-point')) {
    return 'slider_scale';
  }
  
  // Time
  if (lowerType.includes('time') && !lowerType.includes('range')) {
    return 'time_picker';
  }
  
  // Time range (needs to be split into two questions)
  if (lowerType.includes('time range')) {
    return 'time_picker'; // Will need manual splitting
  }
  
  // Date
  if (lowerType.includes('date')) {
    return 'date_picker';
  }
  
  // Number variations
  if (lowerType.includes('number') && lowerType.includes('minutes')) {
    return 'minutes_scroll';
  }
  if (lowerType.includes('number') && lowerType.includes('hours')) {
    return 'number_scroll';
  }
  if (lowerType.includes('number')) {
    return 'number_input'; // Default for measurements
  }
  
  // Multiple choice
  if (lowerType.includes('multiple choice')) {
    return 'single_select_chips';
  }
  if (lowerType.includes('multiple select')) {
    return 'multi_select_chips';
  }
  
  // Text (skip for now)
  if (lowerType.includes('text') || lowerType.includes('email')) {
    return 'SKIP_TEXT_INPUT';
  }
  
  // Calculated (not a question)
  if (lowerType.includes('calculated')) {
    return 'SKIP_CALCULATED';
  }
  
  // Default to single_select for unknown
  console.warn(`Unknown scale type: ${scaleType}`);
  return 'single_select_chips';
}

/**
 * Extract scale range from scaleType string
 */
function extractScaleRange(scaleType) {
  // Match patterns like "0-3 scale", "1-10 scale", "5-point scale"
  const rangeMatch = scaleType.match(/(\d+)-(\d+)\s*scale/i);
  if (rangeMatch) {
    return {
      min: parseInt(rangeMatch[1]),
      max: parseInt(rangeMatch[2])
    };
  }
  
  // Match "X-point scale"
  const pointMatch = scaleType.match(/(\d+)-point\s*scale/i);
  if (pointMatch) {
    const max = parseInt(pointMatch[1]);
    return { min: 1, max };
  }
  
  return null;
}

/**
 * Get format config based on answer format and question details
 */
function getFormatConfig(answerFormat, question) {
  const scaleType = question.scaleType || question.type || '';
  
  switch (answerFormat) {
    case 'time_picker':
      return {
        format: 'HH:MM',
        allowCrossMidnight: true
      };
      
    case 'minutes_scroll':
      return {
        min: question.min || 0,
        max: question.max || 200,
        defaultValue: question.defaultValue || 0,
        step: question.step || 5,
        ...(question.specialValue && {
          specialValue: {
            value: question.specialValue,
            label: question.specialLabel || 'Other'
          }
        })
      };
      
    case 'number_scroll': {
      const isHours = scaleType.toLowerCase().includes('hours');
      return {
        min: question.min || 0,
        max: question.max || (isHours ? 40 : 20),
        defaultValue: question.defaultValue || 0,
        unit: isHours ? 'hours' : question.unit || 'times',
        step: question.step || (isHours ? 0.5 : 1)
      };
    }
      
    case 'slider_scale': {
      const range = extractScaleRange(scaleType);
      const min = range?.min || question.scaleMin || 1;
      const max = range?.max || question.scaleMax || 10;
      
      // Determine labels based on scale type
      let minLabel = 'Minimum';
      let maxLabel = 'Maximum';
      
      if (scaleType.includes('quality') || scaleType.includes('severity')) {
        if (min === 0) {
          minLabel = 'None';
          maxLabel = max === 3 ? 'Severe' : max === 4 ? 'Very severe' : 'Worst';
        } else {
          minLabel = 'Very poor';
          maxLabel = 'Excellent';
        }
      } else if (scaleType.includes('frequency')) {
        minLabel = 'Never';
        maxLabel = 'Always';
      } else if (scaleType.includes('difficulty')) {
        minLabel = 'None';
        maxLabel = 'Very difficult';
      }
      
      // Override with explicit labels if provided
      if (question.scaleMinLabel) minLabel = question.scaleMinLabel;
      if (question.scaleMaxLabel) maxLabel = question.scaleMaxLabel;
      
      return {
        min,
        max,
        minLabel,
        maxLabel,
        defaultValue: question.defaultValue || Math.floor((min + max) / 2),
        showNumberLabel: true,
        step: 1
      };
    }
      
    case 'single_select_chips': {
      let options = [];
      
      // Parse from options string if available
      if (question.options) {
        if (Array.isArray(question.options)) {
          options = question.options.map(opt => ({
            value: opt.toLowerCase().replace(/\s+/g, '_'),
            label: opt
          }));
        } else if (typeof question.options === 'string') {
          // Parse from text
          const optionsList = question.options.split('/').map(o => o.trim());
          options = optionsList.map(opt => ({
            value: opt.toLowerCase().replace(/\s+/g, '_'),
            label: opt
          }));
        }
      }
      
      // Handle Yes/No variants
      if (scaleType.toLowerCase().includes('yes/no')) {
        const parts = scaleType.split('/').map(s => s.trim());
        options = parts.map(opt => ({
          value: opt.toLowerCase().replace(/\s+/g, '_'),
          label: opt
        }));
      }
      
      // Extract options from question text if not found
      if (options.length === 0) {
        const match = question.text.match(/\((.*?)\)/);
        if (match) {
          const optionsList = match[1].split('/').map(o => o.trim());
          options = optionsList.map(opt => ({
            value: opt.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, ''),
            label: opt
          }));
        }
      }
      
      // Default to Yes/No if nothing found
      if (options.length === 0) {
        options = [
          { value: 'yes', label: 'Yes' },
          { value: 'no', label: 'No' }
        ];
      }
      
      return {
        options,
        layout: options.length <= 3 ? 'horizontal' : 'grid'
      };
    }
      
    case 'multi_select_chips': {
      // Extract options from question or defaults
      let options = [];
      if (question.options && Array.isArray(question.options)) {
        options = question.options.map(opt => ({
          value: opt.toLowerCase().replace(/\s+/g, '_'),
          label: opt
        }));
      }
      
      return {
        options,
        layout: 'grid',
        minSelections: 0,
        maxSelections: 10
      };
    }
      
    case 'date_picker':
      return {
        format: 'YYYY-MM-DD',
        maxDate: 'today',
        defaultValue: question.autoFill ? 'today' : undefined,
        autoFill: question.autoFill || false
      };
      
    case 'number_input': {
      const isHeight = question.text.toLowerCase().includes('height');
      const isWeight = question.text.toLowerCase().includes('weight');
      const isTemp = question.text.toLowerCase().includes('temperature');
      
      if (isHeight) {
        return {
          unitOptions: [
            { value: 'cm', label: 'cm' },
            { value: 'in', label: 'inches', conversionFactor: 2.54 }
          ],
          min: 100,
          max: 250,
          step: 1,
          decimalPlaces: 0,
          inputMode: 'numeric'
        };
      } else if (isWeight) {
        return {
          unitOptions: [
            { value: 'kg', label: 'kg' },
            { value: 'lbs', label: 'lbs', conversionFactor: 0.453592 }
          ],
          min: 30,
          max: 300,
          step: 0.1,
          decimalPlaces: 1,
          inputMode: 'decimal'
        };
      } else if (isTemp) {
        return {
          unitOptions: [
            { value: 'c', label: '°C' },
            { value: 'f', label: '°F' }
          ],
          min: 10,
          max: 35,
          step: 0.5,
          decimalPlaces: 1,
          inputMode: 'decimal'
        };
      } else {
        return {
          min: question.min || 0,
          max: question.max || 1000,
          step: 1,
          decimalPlaces: 0,
          inputMode: 'numeric'
        };
      }
    }
      
    default:
      return {};
  }
}

/**
 * Get validation rules for a question
 */
function getValidationRules(answerFormat, question) {
  const rules = {
    required: question.required !== false && question.tier !== 'EXPANSION'
  };
  
  switch (answerFormat) {
    case 'minutes_scroll':
    case 'number_scroll':
    case 'slider_scale':
    case 'number_input':
      const config = getFormatConfig(answerFormat, question);
      if (config.min !== undefined) rules.min = config.min;
      if (config.max !== undefined) rules.max = config.max;
      break;
  }
  
  return rules;
}

/**
 * Clean question text - remove formatting, extract options
 */
function cleanQuestionText(text) {
  // Remove parenthetical options
  text = text.replace(/\s*\([^)]+\)\s*$/, '');
  // Remove scale indicators
  text = text.replace(/\s*\(?\d+-\d+\)?\s*$/, '');
  return text.trim();
}

/**
 * Estimate time in seconds for a question
 */
function estimateTimeSeconds(answerFormat, question) {
  if (question.timeMinutes) {
    return Math.round(question.timeMinutes * 60);
  }
  if (question.estimatedMinutes) {
    return Math.round(question.estimatedMinutes * 60);
  }
  
  // Default estimates by type
  const defaults = {
    'time_picker': 18,
    'minutes_scroll': 12,
    'number_scroll': 12,
    'slider_scale': 10,
    'single_select_chips': 8,
    'multi_select_chips': 15,
    'date_picker': 10,
    'number_input': 15,
    'repeating_group': 36
  };
  
  return defaults[answerFormat] || 10;
}

// ============================================
// Convert Sleep 360° Questions
// ============================================

function convertSleep360Questions() {
  const inputFile = path.join(__dirname, '../data/sleep360_questions.json');
  const questions = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
  
  const converted = [];
  let skipped = [];
  
  for (const q of questions) {
    const answerFormat = convertScaleType(q.scaleType);
    
    // Skip text inputs and calculated fields for now
    if (answerFormat.startsWith('SKIP_')) {
      skipped.push({
        id: q.id,
        text: q.text,
        reason: answerFormat
      });
      continue;
    }
    
    const formatConfig = getFormatConfig(answerFormat, q);
    const validationRules = getValidationRules(answerFormat, q);
    
    converted.push({
      question_id: q.id,
      question_text: cleanQuestionText(q.text),
      help_text: q.notes && q.notes[0] !== '---' ? q.notes[0] : undefined,
      pillar: q.pillar,
      tier: q.tier || 'CORE',
      answer_format: answerFormat,
      format_config: formatConfig,
      validation_rules: validationRules,
      estimated_time_seconds: estimateTimeSeconds(answerFormat, q),
      trigger: q.trigger,
      created_at: Date.now(),
      updated_at: Date.now()
    });
  }
  
  console.log(`✅ Converted ${converted.length} Sleep 360° questions`);
  console.log(`⚠️  Skipped ${skipped.length} questions (text/calculated)`);
  
  return { converted, skipped };
}

// ============================================
// Convert Sleep Diary Questions
// ============================================

function convertSleepDiaryQuestions() {
  const inputFile = path.join(__dirname, '../data/sleep_diary_questions.json');
  const questions = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
  
  const converted = [];
  
  for (const q of questions) {
    // Already mostly in correct format, just standardize
    const answerFormat = q.type || 'single_select_chips';
    const formatConfig = getFormatConfig(answerFormat, q);
    const validationRules = getValidationRules(answerFormat, q);
    
    // Handle conditional logic
    let conditionalLogic = undefined;
    if (q.condition) {
      conditionalLogic = {
        show_if: {
          question_id: q.condition.questionId,
          operator: q.condition.greaterThan !== undefined ? 'greater_than' : 'equals',
          value: q.condition.greaterThan !== undefined ? q.condition.greaterThan : q.condition.equals
        }
      };
    }
    
    converted.push({
      id: q.id,
      question_text: q.text,
      help_text: q.helpText,
      group_key: q.group,
      pillar: q.pillar || 'Sleep Diary',
      answer_format: answerFormat,
      format_config: formatConfig,
      validation_rules: validationRules,
      conditional_logic: conditionalLogic,
      order_index: converted.length + 1,
      estimated_time_seconds: estimateTimeSeconds(answerFormat, q),
      created_at: Date.now(),
      updated_at: Date.now()
    });
  }
  
  console.log(`✅ Converted ${converted.length} Sleep Diary questions`);
  
  return converted;
}

// ============================================
// Main Execution
// ============================================

function main() {
  console.log('🔄 Converting questions to standardized format...\n');
  
  // Convert Sleep 360° questions
  const { converted: sleep360, skipped } = convertSleep360Questions();
  
  // Convert Sleep Diary questions
  const sleepDiary = convertSleepDiaryQuestions();
  
  // Write output files
  const outputDir = path.join(__dirname, '../data/converted');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  fs.writeFileSync(
    path.join(outputDir, 'assessment_questions_converted.json'),
    JSON.stringify(sleep360, null, 2)
  );
  
  fs.writeFileSync(
    path.join(outputDir, 'sleep_diary_questions_converted.json'),
    JSON.stringify(sleepDiary, null, 2)
  );
  
  fs.writeFileSync(
    path.join(outputDir, 'skipped_questions.json'),
    JSON.stringify(skipped, null, 2)
  );
  
  console.log('\n✅ Conversion complete!');
  console.log(`   - ${sleep360.length} assessment questions → data/converted/assessment_questions_converted.json`);
  console.log(`   - ${sleepDiary.length} sleep diary questions → data/converted/sleep_diary_questions_converted.json`);
  console.log(`   - ${skipped.length} skipped questions → data/converted/skipped_questions.json`);
}

if (require.main === module) {
  main();
}

module.exports = {
  convertScaleType,
  getFormatConfig,
  getValidationRules,
  convertSleep360Questions,
  convertSleepDiaryQuestions
};


