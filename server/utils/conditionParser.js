/**
 * Parse trigger strings from CSV and convert them to condition objects
 * Examples:
 * - "If 12A > 0" -> { type: "greaterThan", questionId: "12A", value: 0 }
 * - "If Q19=Yes (snoring)" -> { type: "equals", questionId: "19", value: "Yes" }
 * - "If pain present" -> { type: "equals", questionId: "22", value: "Yes" }
 * - "If caffeine" -> { type: "equals", questionId: "29", value: "Yes" }
 * - "If sex = Female" -> { type: "equals", questionId: "D4", value: "Female" }
 */

/**
 * Parse a trigger string and return a condition object
 */
function parseTrigger(trigger, questionId) {
  if (!trigger || trigger === '-' || trigger === 'Always' || trigger.trim() === '') {
    return null;
  }

  const triggerLower = trigger.trim().toLowerCase();

  // Pattern: "If 12A > 0"
  const greaterThanMatch = triggerLower.match(/if\s+(\w+)\s+>\s+(\d+)/);
  if (greaterThanMatch) {
    return {
      type: 'greaterThan',
      questionId: greaterThanMatch[1],
      value: parseInt(greaterThanMatch[2], 10)
    };
  }

  // Pattern: "If 12A > 0" (alternative format)
  const greaterThanMatch2 = triggerLower.match(/(\w+)\s+>\s+(\d+)/);
  if (greaterThanMatch2) {
    return {
      type: 'greaterThan',
      questionId: greaterThanMatch2[1],
      value: parseInt(greaterThanMatch2[2], 10)
    };
  }

  // Pattern: "If Q19=Yes" or "If Q19=Yes (snoring)"
  const equalsMatch = triggerLower.match(/if\s+q?(\w+)\s*=\s*(yes|no|female|male|other)/i);
  if (equalsMatch) {
    const value = equalsMatch[2];
    // Capitalize first letter
    const capitalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
    return {
      type: 'equals',
      questionId: equalsMatch[1],
      value: capitalizedValue
    };
  }

  // Pattern: "If 44A = Yes"
  const equalsMatch2 = triggerLower.match(/if\s+(\w+)\s*=\s*(yes|no)/i);
  if (equalsMatch2) {
    const value = equalsMatch2[2];
    const capitalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
    return {
      type: 'equals',
      questionId: equalsMatch2[1],
      value: capitalizedValue
    };
  }

  // Pattern: "If pain present" -> assumes Q22 (pain gateway)
  if (triggerLower.includes('pain present') || triggerLower.includes('if pain')) {
    return {
      type: 'equals',
      questionId: '22',
      value: 'Yes'
    };
  }

  // Pattern: "If caffeine" -> assumes Q29 (caffeine)
  if (triggerLower.includes('caffeine')) {
    return {
      type: 'equals',
      questionId: '29',
      value: 'Yes'
    };
  }

  // Pattern: "If alcohol" -> assumes Q32 (alcohol)
  if (triggerLower.includes('alcohol')) {
    return {
      type: 'equals',
      questionId: '32',
      value: 'Yes'
    };
  }

  // Pattern: "If partner" -> assumes Q35 (partner)
  if (triggerLower.includes('partner')) {
    return {
      type: 'equals',
      questionId: '35',
      value: 'Yes'
    };
  }

  // Pattern: "If children" -> assumes Q37 (children)
  if (triggerLower.includes('children')) {
    return {
      type: 'equals',
      questionId: '37',
      value: 'Yes'
    };
  }

  // Pattern: "If exercise" -> assumes Q24 (exercise)
  if (triggerLower.includes('exercise')) {
    return {
      type: 'equals',
      questionId: '24',
      value: 'Yes'
    };
  }

  // Pattern: "If sex = Female" or "If sex = Male"
  const sexMatch = triggerLower.match(/if\s+sex\s*=\s*(female|male|other)/i);
  if (sexMatch) {
    const value = sexMatch[1];
    const capitalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
    return {
      type: 'equals',
      questionId: 'D4',
      value: capitalizedValue
    };
  }

  // Pattern: "If Q19=Yes (snoring)" - more specific
  const snoringMatch = triggerLower.match(/q19\s*=\s*yes|snoring/i);
  if (snoringMatch) {
    return {
      type: 'equals',
      questionId: '19',
      value: 'Yes'
    };
  }

  // Default: try to extract question ID and value from common patterns
  // Pattern: "If [questionId] [operator] [value]"
  const genericMatch = triggerLower.match(/if\s+(\w+)\s*(>=|<=|>|<|=)\s*(\w+)/);
  if (genericMatch) {
    const qId = genericMatch[1];
    const operator = genericMatch[2];
    const value = genericMatch[3];

    if (operator === '=' || operator === '==') {
      const capitalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
      return {
        type: 'equals',
        questionId: qId,
        value: capitalizedValue
      };
    } else if (operator === '>') {
      return {
        type: 'greaterThan',
        questionId: qId,
        value: parseInt(value, 10) || 0
      };
    } else if (operator === '>=') {
      return {
        type: 'greaterThanOrEqual',
        questionId: qId,
        value: parseInt(value, 10) || 0
      };
    } else if (operator === '<') {
      return {
        type: 'lessThan',
        questionId: qId,
        value: parseInt(value, 10) || 0
      };
    } else if (operator === '<=') {
      return {
        type: 'lessThanOrEqual',
        questionId: qId,
        value: parseInt(value, 10) || 0
      };
    }
  }

  // If no pattern matches, return null (no condition)
  console.warn(`Could not parse trigger: "${trigger}" for question ${questionId}`);
  return null;
}

module.exports = { parseTrigger };




