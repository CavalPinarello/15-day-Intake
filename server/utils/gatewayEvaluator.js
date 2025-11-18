/**
 * Gateway Evaluation Engine
 * Evaluates gateway triggers based on user responses
 */

const fs = require('fs');
const path = require('path');

const GATEWAY_TRIGGERS_PATH = path.join(__dirname, '../../data/gateway_triggers.json');

/**
 * Load gateway triggers from JSON file
 */
function loadGatewayTriggers() {
  try {
    const data = fs.readFileSync(GATEWAY_TRIGGERS_PATH, 'utf-8');
    return JSON.parse(data);
  } catch (err) {
    console.error('Error loading gateway triggers:', err);
    return { gateways: [] };
  }
}

/**
 * Parse time string (HH:MM) to minutes since midnight
 */
function parseTimeToMinutes(timeStr) {
  if (!timeStr || typeof timeStr !== 'string') return null;
  
  const parts = timeStr.split(':');
  if (parts.length !== 2) return null;
  
  const hours = parseInt(parts[0], 10);
  const minutes = parseInt(parts[1], 10);
  
  if (isNaN(hours) || isNaN(minutes)) return null;
  
  return hours * 60 + minutes;
}

/**
 * Calculate weekday-weekend difference in sleep times
 */
function calculateWeekdayWeekendDifference(responses) {
  const weekdayBedtime = parseTimeToMinutes(responses['7']);
  const weekdayWaketime = parseTimeToMinutes(responses['8']);
  const weekendBedtime = parseTimeToMinutes(responses['9']);
  const weekendWaketime = parseTimeToMinutes(responses['10']);
  
  if (!weekdayBedtime || !weekdayWaketime || !weekendBedtime || !weekendWaketime) {
    return null;
  }
  
  // Calculate sleep duration for weekday and weekend
  let weekdayDuration = weekdayWaketime - weekdayBedtime;
  if (weekdayDuration < 0) weekdayDuration += 24 * 60; // Handle overnight
  
  let weekendDuration = weekendWaketime - weekendBedtime;
  if (weekendDuration < 0) weekendDuration += 24 * 60; // Handle overnight
  
  // Calculate difference in hours
  const difference = Math.abs(weekendDuration - weekdayDuration) / 60;
  
  return difference;
}

/**
 * Evaluate a single condition
 */
function evaluateCondition(condition, responses) {
  if (!condition || !condition.type) {
    return false;
  }
  
  switch (condition.type) {
    case 'equals':
      if (!condition.questionId) return false;
      const equalsValue = responses[condition.questionId];
      return equalsValue === condition.value || equalsValue === String(condition.value);
    
    case 'greaterThan':
      if (!condition.questionId) return false;
      const gtValue = parseFloat(responses[condition.questionId]);
      return !isNaN(gtValue) && gtValue > condition.value;
    
    case 'greaterThanOrEqual':
      if (!condition.questionId) return false;
      const gteValue = parseFloat(responses[condition.questionId]);
      return !isNaN(gteValue) && gteValue >= condition.value;
    
    case 'lessThan':
      if (!condition.questionId) return false;
      const ltValue = parseFloat(responses[condition.questionId]);
      return !isNaN(ltValue) && ltValue < condition.value;
    
    case 'lessThanOrEqual':
      if (!condition.questionId) return false;
      const lteValue = parseFloat(responses[condition.questionId]);
      return !isNaN(lteValue) && lteValue <= condition.value;
    
    case 'and':
      if (!condition.conditions || !Array.isArray(condition.conditions)) {
        return false;
      }
      return condition.conditions.every(subCondition => 
        evaluateCondition(subCondition, responses)
      );
    
    case 'or':
      if (!condition.conditions || !Array.isArray(condition.conditions)) {
        return false;
      }
      return condition.conditions.some(subCondition => 
        evaluateCondition(subCondition, responses)
      );
    
    case 'calculated':
      if (condition.function === 'weekdayWeekendDifference') {
        const difference = calculateWeekdayWeekendDifference(responses);
        if (difference === null) return false;
        return difference > condition.threshold;
      }
      return false;
    
    default:
      console.warn(`Unknown condition type: ${condition.type}`);
      return false;
  }
}

/**
 * Evaluate all gateway triggers for a user
 */
function evaluateGateways(userId, responses) {
  const { gateways } = loadGatewayTriggers();
  const results = {};
  
  for (const gateway of gateways) {
    // Skip optional gateways if trigger question doesn't exist
    if (gateway.optional) {
      const hasTriggerQuestion = gateway.triggerQuestionIds.some(qId => 
        responses.hasOwnProperty(qId)
      );
      if (!hasTriggerQuestion) {
        results[gateway.gatewayId] = {
          triggered: false,
          reason: 'Optional gateway - trigger question not found'
        };
        continue;
      }
    }
    
    // Check if all required questions are answered
    const allQuestionsAnswered = gateway.triggerQuestionIds.every(qId => 
      responses.hasOwnProperty(qId) && responses[qId] !== null && responses[qId] !== undefined && responses[qId] !== ''
    );
    
    if (!allQuestionsAnswered) {
      results[gateway.gatewayId] = {
        triggered: false,
        reason: 'Not all trigger questions answered'
      };
      continue;
    }
    
    // Evaluate the condition
    const triggered = evaluateCondition(gateway.condition, responses);
    
    results[gateway.gatewayId] = {
      triggered,
      gatewayId: gateway.gatewayId,
      name: gateway.name,
      targetModules: gateway.targetModules,
      evaluationData: {
        condition: gateway.condition,
        responses: gateway.triggerQuestionIds.reduce((acc, qId) => {
          acc[qId] = responses[qId];
          return acc;
        }, {})
      }
    };
  }
  
  return results;
}

/**
 * Get triggered modules for a user
 */
function getTriggeredModules(userId, responses) {
  const gatewayResults = evaluateGateways(userId, responses);
  const triggeredModules = new Set();
  
  for (const gatewayId in gatewayResults) {
    const result = gatewayResults[gatewayId];
    if (result.triggered && result.targetModules) {
      result.targetModules.forEach(moduleId => {
        triggeredModules.add(moduleId);
      });
    }
  }
  
  return Array.from(triggeredModules);
}

/**
 * Get gateway state for a specific gateway
 */
function getGatewayState(gatewayId, responses) {
  const { gateways } = loadGatewayTriggers();
  const gateway = gateways.find(g => g.gatewayId === gatewayId);
  
  if (!gateway) {
    return { triggered: false, reason: 'Gateway not found' };
  }
  
  // Check if all required questions are answered
  const allQuestionsAnswered = gateway.triggerQuestionIds.every(qId => 
    responses.hasOwnProperty(qId) && responses[qId] !== null && responses[qId] !== undefined && responses[qId] !== ''
  );
  
  if (!allQuestionsAnswered) {
    return { triggered: false, reason: 'Not all trigger questions answered' };
  }
  
  // Evaluate the condition
  const triggered = evaluateCondition(gateway.condition, responses);
  
  return {
    triggered,
    gatewayId: gateway.gatewayId,
    name: gateway.name,
    targetModules: gateway.targetModules,
    evaluationData: {
      condition: gateway.condition,
      responses: gateway.triggerQuestionIds.reduce((acc, qId) => {
        acc[qId] = responses[qId];
        return acc;
      }, {})
    }
  };
}

module.exports = {
  loadGatewayTriggers,
  evaluateGateways,
  evaluateCondition,
  getTriggeredModules,
  getGatewayState,
  calculateWeekdayWeekendDifference,
  parseTimeToMinutes
};




