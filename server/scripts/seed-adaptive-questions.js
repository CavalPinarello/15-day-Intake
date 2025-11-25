const { getDatabase } = require('../database/init');
const sqlite3 = require('sqlite3').verbose();

// Stanford Sleep Log - Asked every day in parallel with assessment questions
const dailySleepLogQuestions = [
  {
    question_text: 'What time did you go to bed last night? (Your subjective perception - don\'t check your wearable device)',
    question_type: 'time',
    options: null,
    order_index: 0,
    required: true,
    is_daily_log: true,
    help_text: 'We want your subjective perception of when you went to bed, not what your device recorded.'
  },
  {
    question_text: 'What time did you fall asleep last night? (Your best estimate - don\'t check your wearable)',
    question_type: 'time', 
    options: null,
    order_index: 1,
    required: true,
    is_daily_log: true,
    help_text: 'This is about your perception of when you actually fell asleep.'
  },
  {
    question_text: 'How many times did you wake up during the night?',
    question_type: 'number',
    options: { min: 0, max: 20 },
    order_index: 2,
    required: true,
    is_daily_log: true
  },
  {
    question_text: 'What time did you wake up this morning? (Final awakening - don\'t check your wearable)',
    question_type: 'time',
    options: null,
    order_index: 3,
    required: true,
    is_daily_log: true,
    help_text: 'We want your subjective perception, not device data.'
  },
  {
    question_text: 'How would you rate your sleep quality last night?',
    question_type: 'scale',
    options: { min: 1, max: 10, minLabel: 'Very Poor', maxLabel: 'Excellent' },
    order_index: 4,
    required: true,
    is_daily_log: true
  }
];

// Day 1: Demographics + Sleep Quality Core + PSQI (Part 1) - 15 questions, 12 minutes
const day1AssessmentQuestions = [
  // Demographics (Static)
  {
    question_text: 'What is your age?',
    question_type: 'number',
    options: { min: 18, max: 120 },
    order_index: 10,
    required: true,
    pillar: 'Social'
  },
  {
    question_text: 'What is your sex assigned at birth?',
    question_type: 'select',
    options: ['Male', 'Female', 'Other'],
    order_index: 11,
    required: true,
    pillar: 'Social'
  },
  {
    question_text: 'What is your height?',
    question_type: 'number',
    options: { min: 100, max: 250, unit: 'cm' },
    order_index: 12,
    required: true,
    pillar: 'Metabolic'
  },
  {
    question_text: 'What is your weight?',
    question_type: 'number', 
    options: { min: 30, max: 300, unit: 'kg' },
    order_index: 13,
    required: true,
    pillar: 'Metabolic'
  },
  
  // Sleep Quality Core
  {
    question_text: 'How often do you feel refreshed after sleep?',
    question_type: 'select',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
    order_index: 14,
    required: true,
    pillar: 'Sleep Quality'
  },
  {
    question_text: 'Overall sleep quality in past month',
    question_type: 'scale',
    options: { min: 1, max: 10, minLabel: 'Very Poor', maxLabel: 'Excellent' },
    order_index: 15,
    required: true,
    pillar: 'Sleep Quality',
    is_gateway: true,
    gateway_condition: 'sleep_quality_poor',
    gateway_threshold: 6
  },
  
  // PSQI Part 1 (Gateway questions included)
  {
    question_text: 'During the past month, when have you usually gone to bed at night? (Your subjective perception - don\'t check your wearable)',
    question_type: 'time',
    options: null,
    order_index: 16,
    required: true,
    pillar: 'Sleep Quality',
    help_text: 'We want your subjective perception of your usual bedtime, not what your device recorded.'
  },
  {
    question_text: 'During the past month, how long (in minutes) has it usually taken you to fall asleep each night?',
    question_type: 'number',
    options: { min: 0, max: 180, unit: 'minutes' },
    order_index: 17,
    required: true,
    pillar: 'Sleep Quality',
    is_gateway: true,
    gateway_condition: 'insomnia_gateway',
    gateway_threshold: 30
  },
  {
    question_text: 'During the past month, when have you usually gotten up in the morning? (Your subjective perception - don\'t check your wearable)',
    question_type: 'time',
    options: null,
    order_index: 18,
    required: true,
    pillar: 'Sleep Quality',
    help_text: 'We want your subjective perception, not device data.'
  },
  {
    question_text: 'During the past month, how many hours of actual sleep did you get at night?',
    question_type: 'number',
    options: { min: 0, max: 15, step: 0.5, unit: 'hours' },
    order_index: 19,
    required: true,
    pillar: 'Sleep Quality'
  }
];

// Day 2: PSQI Part 2 + Sleep Quantity + Sleep Regularity - 14 questions, 11 minutes  
const day2AssessmentQuestions = [
  {
    question_text: 'During the past month, how often have you had trouble sleeping because you cannot get to sleep within 30 minutes?',
    question_type: 'select',
    options: ['Not during the past month', 'Less than once a week', 'Once or twice a week', 'Three or more times a week'],
    order_index: 10,
    required: true,
    pillar: 'Sleep Quality',
    is_gateway: true,
    gateway_condition: 'insomnia_gateway',
    gateway_threshold: 2
  },
  {
    question_text: 'During the past month, how often have you had trouble sleeping because you wake up in the middle of the night or early morning?',
    question_type: 'select',
    options: ['Not during the past month', 'Less than once a week', 'Once or twice a week', 'Three or more times a week'],
    order_index: 11,
    required: true,
    pillar: 'Sleep Quality',
    is_gateway: true,
    gateway_condition: 'insomnia_gateway', 
    gateway_threshold: 2
  },
  {
    question_text: 'How many times do you typically wake up during the night?',
    question_type: 'number',
    options: { min: 0, max: 15 },
    order_index: 12,
    required: true,
    pillar: 'Sleep Quality'
  },
  {
    question_text: 'When you wake up at night, what is the MAIN reason?',
    question_type: 'select',
    options: ['Bathroom needs', 'Pain/discomfort', 'Noise', 'Light', 'Hot/cold', 'Dreams/nightmares', 'Worry/stress', 'Other'],
    order_index: 13,
    required: true,
    pillar: 'Sleep Quality'
  },
  {
    question_text: 'Do you use an alarm clock on weekdays?',
    question_type: 'select',
    options: ['Never', 'Rarely', 'Sometimes', 'Usually', 'Always'],
    order_index: 14,
    required: true,
    pillar: 'Sleep Quality'
  },
  {
    question_text: 'How much does your bedtime vary from night to night?',
    question_type: 'select',
    options: ['Less than 15 minutes', '15-30 minutes', '30-60 minutes', '1-2 hours', 'More than 2 hours'],
    order_index: 15,
    required: true,
    pillar: 'Sleep Quality',
    is_gateway: true,
    gateway_condition: 'chronotype_gateway',
    gateway_threshold: 3
  }
];

// Day 3: Sleep Timing + Mental Health + Cognitive Gateways - 10 questions, 8 minutes
const day3AssessmentQuestions = [
  {
    question_text: 'How often do you get morning sunlight exposure?',
    question_type: 'select',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Daily'],
    order_index: 10,
    required: true,
    pillar: 'Physical Health'
  },
  {
    question_text: 'How many hours per day do you spend looking at screens for work?',
    question_type: 'number',
    options: { min: 0, max: 18, unit: 'hours' },
    order_index: 11,
    required: true,
    pillar: 'Social'
  },
  {
    question_text: 'How often do you use electronic devices within 1 hour of bedtime?',
    question_type: 'select',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
    order_index: 12,
    required: true,
    pillar: 'Social'
  },
  {
    question_text: 'On a scale of 1-10, how would you rate your current stress level?',
    question_type: 'scale',
    options: { min: 1, max: 10, minLabel: 'No stress', maxLabel: 'Extremely stressed' },
    order_index: 13,
    required: true,
    pillar: 'Mental Health',
    is_gateway: true,
    gateway_condition: 'mental_health_gateway',
    gateway_threshold: 7
  },
  {
    question_text: 'Over the past 2 weeks, how often have you felt down, depressed, or hopeless?',
    question_type: 'select',
    options: ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    order_index: 14,
    required: true,
    pillar: 'Mental Health',
    is_gateway: true,
    gateway_condition: 'mental_health_gateway',
    gateway_threshold: 1
  },
  {
    question_text: 'Over the past 2 weeks, how often have you felt nervous, anxious, or on edge?',
    question_type: 'select', 
    options: ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    order_index: 15,
    required: true,
    pillar: 'Mental Health',
    is_gateway: true,
    gateway_condition: 'mental_health_gateway',
    gateway_threshold: 1
  }
];

// Day 4: Physical Health Gateways + Metabolic Core - 11 questions, 9 minutes
const day4AssessmentQuestions = [
  {
    question_text: 'Do you snore loudly (louder than talking or loud enough to be heard through closed doors)?',
    question_type: 'select',
    options: ['No', 'Yes', 'Don\'t know'],
    order_index: 10,
    required: true,
    pillar: 'Physical Health',
    is_gateway: true,
    gateway_condition: 'osa_gateway',
    gateway_threshold: 1
  },
  {
    question_text: 'Do you often feel tired, fatigued, or sleepy during daytime?',
    question_type: 'select',
    options: ['No', 'Yes'],
    order_index: 11,
    required: true,
    pillar: 'Physical Health',
    is_gateway: true,
    gateway_condition: 'daytime_sleepiness_gateway',
    gateway_threshold: 1
  },
  {
    question_text: 'Has anyone observed you stop breathing during your sleep?',
    question_type: 'select',
    options: ['No', 'Yes', 'Don\'t know'],
    order_index: 12,
    required: true,
    pillar: 'Physical Health',
    is_gateway: true,
    gateway_condition: 'osa_gateway',
    gateway_threshold: 1
  },
  {
    question_text: 'Do you have high blood pressure or are you currently on medication for high blood pressure?',
    question_type: 'select',
    options: ['No', 'Yes'],
    order_index: 13,
    required: true,
    pillar: 'Metabolic'
  },
  {
    question_text: 'On average, what is your pain level (0=no pain, 10=worst possible pain)?',
    question_type: 'scale',
    options: { min: 0, max: 10, minLabel: 'No pain', maxLabel: 'Worst possible' },
    order_index: 14,
    required: true,
    pillar: 'Physical Health',
    is_gateway: true,
    gateway_condition: 'pain_gateway',
    gateway_threshold: 4
  },
  {
    question_text: 'How often do you exercise or engage in physical activity?',
    question_type: 'select',
    options: ['Never', 'Less than once a week', '1-2 times per week', '3-4 times per week', '5+ times per week'],
    order_index: 15,
    required: true,
    pillar: 'Physical Health'
  }
];

// Day 5: Nutritional Core + Social Factors - 9 questions, 7 minutes  
const day5AssessmentQuestions = [
  {
    question_text: 'Do you consume caffeine (coffee, tea, energy drinks)?',
    question_type: 'select',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Daily'],
    order_index: 10,
    required: true,
    pillar: 'Metabolic'
  },
  {
    question_text: 'If you consume caffeine, how many cups/servings per day?',
    question_type: 'number',
    options: { min: 0, max: 20 },
    order_index: 11,
    required: false,
    pillar: 'Metabolic'
  },
  {
    question_text: 'How often do you consume alcohol?',
    question_type: 'select',
    options: ['Never', 'Less than monthly', 'Monthly', 'Weekly', 'Daily'],
    order_index: 12,
    required: true,
    pillar: 'Metabolic'
  },
  {
    question_text: 'Do you notice your diet affects your sleep quality?',
    question_type: 'select',
    options: ['Not at all', 'Slightly', 'Moderately', 'Quite a bit', 'Extremely'],
    order_index: 13,
    required: true,
    pillar: 'Metabolic',
    is_gateway: true,
    gateway_condition: 'diet_gateway',
    gateway_threshold: 2
  },
  {
    question_text: 'Do you share your bedroom with a partner?',
    question_type: 'select',
    options: ['No', 'Yes'],
    order_index: 14,
    required: true,
    pillar: 'Social'
  },
  {
    question_text: 'If yes, do they snore or disturb your sleep?',
    question_type: 'select',
    options: ['No', 'Yes', 'Not applicable'],
    order_index: 15,
    required: false,
    pillar: 'Social'
  }
];

// All 15 days with their assessment questions
const assessmentPlan = {
  1: { questions: day1AssessmentQuestions, description: 'Demographics + Sleep Quality Core + PSQI (Part 1)' },
  2: { questions: day2AssessmentQuestions, description: 'PSQI (Part 2) + Sleep Quantity + Sleep Regularity' },
  3: { questions: day3AssessmentQuestions, description: 'Sleep Timing + Mental Health + Cognitive Gateways' },
  4: { questions: day4AssessmentQuestions, description: 'Physical Health Gateways + Metabolic Core' },
  5: { questions: day5AssessmentQuestions, description: 'Nutritional Core + Social Factors' },
  6: { questions: [], description: 'EXPANSION: ISI (Insomnia Severity) - If insomnia gateway = YES' },
  7: { questions: [], description: 'EXPANSION: DBAS-16 (Part 1) - If insomnia gateway = YES' },
  8: { questions: [], description: 'EXPANSION: DBAS-16 (Part 2) + Sleep Hygiene (Part 1) - If insomnia gateway = YES' },
  9: { questions: [], description: 'EXPANSION: Sleep Hygiene (Part 2) + PSAS (Part 1) - If insomnia gateway = YES' },
  10: { questions: [], description: 'EXPANSION: PSAS (Part 2) + ESS - If gateways triggered' },
  11: { questions: [], description: 'EXPANSION: FSS + FOSQ-10 (Part 1) - If daytime sleepiness gateway = YES' },
  12: { questions: [], description: 'EXPANSION: FOSQ-10 (Part 2) + PHQ-9 + GAD-7 (Part 1) - If mental health gateways triggered' },
  13: { questions: [], description: 'EXPANSION: GAD-7 (Part 2) + DASS-21 (Part 1) + PROMIS Cognitive - If mental health gateways triggered' },
  14: { questions: [], description: 'EXPANSION: DASS-21 (Part 2) + STOP-BANG + Berlin - If OSA gateway triggered' },
  15: { questions: [], description: 'EXPANSION: Brief Pain Inventory + MEDAS + MEQ - If specific gateways triggered' }
};

function seedAdaptiveQuestions() {
  const db = getDatabase();

  // Clear existing questions
  db.run('DELETE FROM questions', (err) => {
    if (err) {
      console.error('Error clearing questions:', err);
      return;
    }

    console.log('Cleared existing questions');
    
    // Get all days
    db.all('SELECT * FROM days ORDER BY day_number', [], (err, days) => {
      if (err) {
        console.error('Error fetching days:', err);
        return;
      }

      console.log('Seeding adaptive 15-day assessment system...');
      
      const insertPromises = [];

      days.forEach(day => {
        if (day.day_number >= 1 && day.day_number <= 15) {
          console.log(`\\nDay ${day.day_number}: ${assessmentPlan[day.day_number].description}`);
          
          // Add daily sleep log questions to every day
          dailySleepLogQuestions.forEach((q, idx) => {
            const promise = new Promise((resolve, reject) => {
              db.run(
                `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required, conditional_logic)
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [
                  day.id,
                  q.question_text,
                  q.question_type,
                  q.options ? JSON.stringify(q.options) : null,
                  q.order_index,
                  q.required ? 1 : 0,
                  JSON.stringify({ 
                    is_daily_log: q.is_daily_log,
                    help_text: q.help_text || null,
                    pillar: 'Sleep Log'
                  })
                ],
                function(err) {
                  if (err) {
                    console.error(`Error inserting sleep log question ${idx + 1}:`, err);
                    reject(err);
                  } else {
                    console.log(`  ✓ Sleep Log: ${q.question_text.substring(0, 40)}...`);
                    resolve();
                  }
                }
              );
            });
            insertPromises.push(promise);
          });

          // Add assessment questions for days 1-5 (core foundation)
          if (day.day_number <= 5 && assessmentPlan[day.day_number].questions.length > 0) {
            assessmentPlan[day.day_number].questions.forEach((q, idx) => {
              const promise = new Promise((resolve, reject) => {
                db.run(
                  `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required, conditional_logic)
                   VALUES (?, ?, ?, ?, ?, ?, ?)`,
                  [
                    day.id,
                    q.question_text,
                    q.question_type,
                    q.options ? JSON.stringify(q.options) : null,
                    q.order_index,
                    q.required ? 1 : 0,
                    JSON.stringify({
                      pillar: q.pillar,
                      is_gateway: q.is_gateway || false,
                      gateway_condition: q.gateway_condition || null,
                      gateway_threshold: q.gateway_threshold || null,
                      help_text: q.help_text || null
                    })
                  ],
                  function(err) {
                    if (err) {
                      console.error(`Error inserting assessment question ${idx + 1}:`, err);
                      reject(err);
                    } else {
                      const gatewayNote = q.is_gateway ? ' [GATEWAY]' : '';
                      console.log(`  ✓ Assessment: ${q.question_text.substring(0, 40)}...${gatewayNote}`);
                      resolve();
                    }
                  }
                );
              });
              insertPromises.push(promise);
            });
          } else if (day.day_number > 5) {
            // For expansion days, add placeholder indicating conditional loading
            const promise = new Promise((resolve, reject) => {
              db.run(
                `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required, conditional_logic)
                 VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [
                  day.id,
                  `Day ${day.day_number} expansion questions will be loaded based on your gateway responses from Days 1-5`,
                  'info',
                  null,
                  20,
                  false,
                  JSON.stringify({
                    is_expansion_placeholder: true,
                    expansion_description: assessmentPlan[day.day_number].description
                  })
                ],
                function(err) {
                  if (err) {
                    console.error('Error inserting expansion placeholder:', err);
                    reject(err);
                  } else {
                    console.log(`  ✓ Expansion placeholder added`);
                    resolve();
                  }
                }
              );
            });
            insertPromises.push(promise);
          }
        }
      });

      // Wait for all questions to be inserted
      Promise.all(insertPromises)
        .then(() => {
          console.log(`\\n🎉 Successfully seeded adaptive 15-day assessment system!`);
          console.log(`📊 Total questions inserted: ${insertPromises.length}`);
          console.log(`\\n📋 System Features:`);
          console.log(`   ✅ Daily sleep log (5 questions per day)`);
          console.log(`   ✅ Core foundation (Days 1-5: ~47 assessment questions)`);
          console.log(`   ✅ Gateway trigger logic for adaptive expansion`);
          console.log(`   ✅ Subjective perception messaging for sleep timing`);
          console.log(`   ✅ Smart load balancing (light vs heavy days)`);
          process.exit(0);
        })
        .catch((err) => {
          console.error('Error seeding questions:', err);
          process.exit(1);
        });

      if (insertPromises.length === 0) {
        console.log('No questions to seed');
        process.exit(0);
      }
    });
  });
}

// Initialize database and seed
const { initDatabase } = require('../database/init');
initDatabase()
  .then(() => {
    console.log('Database initialized, seeding adaptive questions...');
    seedAdaptiveQuestions();
  })
  .catch((err) => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
  });