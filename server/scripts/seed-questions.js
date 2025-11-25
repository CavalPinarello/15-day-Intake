const { getDatabase } = require('../database/init');
const sqlite3 = require('sqlite3').verbose();

// Sample questions for Day 1
const sampleQuestions = [
  {
    day_number: 1,
    questions: [
      {
        question_text: 'Welcome! What brings you to your sleep journey today?',
        question_type: 'textarea',
        options: null,
        order_index: 0,
        required: true,
      },
      {
        question_text: 'How would you rate your current sleep quality?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Poor', maxLabel: 'Excellent' },
        order_index: 1,
        required: true,
      },
      {
        question_text: 'What time do you typically go to bed?',
        question_type: 'time',
        options: null,
        order_index: 2,
        required: true,
      },
      {
        question_text: 'What time do you typically wake up?',
        question_type: 'time',
        options: null,
        order_index: 3,
        required: true,
      },
    ],
  },
  {
    day_number: 2,
    questions: [
      {
        question_text: 'How many hours of sleep do you usually get per night?',
        question_type: 'number',
        options: null,
        order_index: 0,
        required: true,
      },
      {
        question_text: 'How often do you wake up during the night?',
        question_type: 'select',
        options: ['Never', 'Once', '2-3 times', '4-5 times', 'More than 5 times'],
        order_index: 1,
        required: true,
      },
      {
        question_text: 'What factors affect your sleep? (Select all that apply)',
        question_type: 'checkbox',
        options: ['Stress', 'Noise', 'Light', 'Temperature', 'Caffeine', 'Alcohol', 'Exercise', 'Other'],
        order_index: 2,
        required: false,
      },
    ],
  },
  {
    day_number: 3,
    questions: [
      {
        question_text: 'How would you describe your bedroom temperature at night?',
        question_type: 'select',
        options: ['Too hot', 'Slightly warm', 'Just right', 'Slightly cool', 'Too cold'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'What is the noise level in your bedroom?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Silent', maxLabel: 'Very Noisy' },
        order_index: 1,
        required: true,
      },
      {
        question_text: 'How dark is your room when you sleep?',
        question_type: 'select',
        options: ['Completely dark', 'Mostly dark', 'Some light', 'Quite bright'],
        order_index: 2,
        required: true,
      },
    ],
  },
  {
    day_number: 4,
    questions: [
      {
        question_text: 'Do you use electronic devices before bed?',
        question_type: 'checkbox',
        options: ['Phone', 'Tablet', 'TV', 'Computer', 'E-reader', 'None'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'How long before bed do you stop using screens?',
        question_type: 'select',
        options: ['I don\'t stop', 'Less than 30 minutes', '30-60 minutes', '1-2 hours', 'More than 2 hours'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 5,
    questions: [
      {
        question_text: 'What do you typically eat or drink before bed?',
        question_type: 'checkbox',
        options: ['Water', 'Tea', 'Coffee', 'Alcohol', 'Snack', 'Large meal', 'Nothing'],
        order_index: 0,
        required: false,
      },
      {
        question_text: 'How many hours before bed do you have your last meal?',
        question_type: 'number',
        options: { min: 0, max: 12, step: 0.5 },
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 6,
    questions: [
      {
        question_text: 'Do you exercise regularly?',
        question_type: 'select',
        options: ['Daily', 'Few times a week', 'Once a week', 'Rarely', 'Never'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'When do you usually exercise?',
        question_type: 'select',
        options: ['Morning', 'Afternoon', 'Evening', 'Night', 'I don\'t exercise'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 7,
    questions: [
      {
        question_text: 'How has your sleep been this week?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Much worse', maxLabel: 'Much better' },
        order_index: 0,
        required: true,
      },
      {
        question_text: 'What changes have you noticed in your sleep patterns?',
        question_type: 'textarea',
        options: null,
        order_index: 1,
        required: false,
      },
    ],
  },
  {
    day_number: 8,
    questions: [
      {
        question_text: 'How do you feel when you wake up in the morning?',
        question_type: 'select',
        options: ['Refreshed and energetic', 'Somewhat rested', 'Tired but okay', 'Very tired', 'Exhausted'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'Do you need an alarm to wake up?',
        question_type: 'select',
        options: ['Never', 'Rarely', 'Sometimes', 'Usually', 'Always'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 9,
    questions: [
      {
        question_text: 'What is your stress level before bed?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Very relaxed', maxLabel: 'Very stressed' },
        order_index: 0,
        required: true,
      },
      {
        question_text: 'What relaxation techniques do you use before sleep?',
        question_type: 'checkbox',
        options: ['Deep breathing', 'Meditation', 'Reading', 'Warm bath', 'Music', 'Stretching', 'None'],
        order_index: 1,
        required: false,
      },
    ],
  },
  {
    day_number: 10,
    questions: [
      {
        question_text: 'How consistent is your sleep schedule on weekends?',
        question_type: 'select',
        options: ['Same as weekdays', 'Slightly different', 'Very different', 'No schedule'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'Do you take naps during the day?',
        question_type: 'select',
        options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Daily'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 11,
    questions: [
      {
        question_text: 'How comfortable is your mattress?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Very uncomfortable', maxLabel: 'Perfect' },
        order_index: 0,
        required: true,
      },
      {
        question_text: 'When did you last replace your mattress?',
        question_type: 'select',
        options: ['Less than 1 year', '1-3 years', '4-7 years', '8-10 years', 'More than 10 years'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 12,
    questions: [
      {
        question_text: 'Do you snore or has anyone told you that you snore?',
        question_type: 'select',
        options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always', 'Not sure'],
        order_index: 0,
        required: true,
      },
      {
        question_text: 'Do you ever stop breathing during sleep (sleep apnea)?',
        question_type: 'select',
        options: ['No', 'Not sure', 'Rarely', 'Sometimes', 'Often'],
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 13,
    questions: [
      {
        question_text: 'How has your overall sleep improved over this journey?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Not at all', maxLabel: 'Significantly' },
        order_index: 0,
        required: true,
      },
      {
        question_text: 'What has been most helpful for your sleep?',
        question_type: 'textarea',
        options: null,
        order_index: 1,
        required: false,
      },
    ],
  },
  {
    day_number: 14,
    questions: [
      {
        question_text: 'What sleep goals do you want to focus on going forward?',
        question_type: 'checkbox',
        options: ['Better sleep schedule', 'Reduce wake-ups', 'Fall asleep faster', 'Feel more rested', 'Reduce stress', 'Improve sleep environment'],
        order_index: 0,
        required: false,
      },
      {
        question_text: 'How confident do you feel about maintaining good sleep habits?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Not confident', maxLabel: 'Very confident' },
        order_index: 1,
        required: true,
      },
    ],
  },
  {
    day_number: 15,
    questions: [
      {
        question_text: 'Congratulations on completing your 15-day sleep journey! How do you feel?',
        question_type: 'textarea',
        options: null,
        order_index: 0,
        required: false,
      },
      {
        question_text: 'Overall, how would you rate your sleep now compared to when you started?',
        question_type: 'scale',
        options: { min: 1, max: 10, minLabel: 'Much worse', maxLabel: 'Much better' },
        order_index: 1,
        required: true,
      },
      {
        question_text: 'Would you recommend this sleep program to others?',
        question_type: 'select',
        options: ['Definitely yes', 'Probably yes', 'Maybe', 'Probably no', 'Definitely no'],
        order_index: 2,
        required: true,
      },
    ],
  },
];

function seedQuestions() {
  const db = getDatabase();

  // Get all days
  db.all('SELECT * FROM days ORDER BY day_number', [], (err, days) => {
    if (err) {
      console.error('Error fetching days:', err);
      return;
    }

    // Don't delete questions - instead, update them or insert new ones
    // This prevents issues when day IDs change
    console.log('Seeding questions (will update existing or insert new)...');

    // Insert/update sample questions
    const insertPromises = [];

    sampleQuestions.forEach((dayData) => {
      const day = days.find((d) => d.day_number === dayData.day_number);
      if (!day) {
        console.warn(`Day ${dayData.day_number} not found`);
        return;
      }

      console.log(`Inserting questions for Day ${dayData.day_number} (day_id: ${day.id})`);

      dayData.questions.forEach((q, idx) => {
        const promise = new Promise((resolve, reject) => {
          // Check if question already exists for this day
          db.get(
            `SELECT id FROM questions WHERE day_id = ? AND question_text = ?`,
            [day.id, q.question_text],
            (err, existing) => {
              if (err) {
                reject(err);
                return;
              }

              if (existing) {
                // Update existing question
                db.run(
                  `UPDATE questions 
                   SET question_type = ?, options = ?, order_index = ?, required = ?
                   WHERE id = ?`,
                  [
                    q.question_type,
                    q.options ? JSON.stringify(q.options) : null,
                    q.order_index,
                    q.required ? 1 : 0,
                    existing.id,
                  ],
                  (err) => {
                    if (err) {
                      console.error(`Error updating question ${idx + 1} for day ${dayData.day_number}:`, err);
                      reject(err);
                    } else {
                      console.log(`  ✓ Updated: ${q.question_text.substring(0, 50)}...`);
                      resolve();
                    }
                  }
                );
              } else {
                // Insert new question
                db.run(
                  `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required)
                   VALUES (?, ?, ?, ?, ?, ?)`,
                  [
                    day.id,
                    q.question_text,
                    q.question_type,
                    q.options ? JSON.stringify(q.options) : null,
                    q.order_index,
                    q.required ? 1 : 0,
                  ],
                  function(err) {
                    if (err) {
                      console.error(`Error inserting question ${idx + 1} for day ${dayData.day_number}:`, err);
                      reject(err);
                    } else {
                      console.log(`  ✓ Inserted: ${q.question_text.substring(0, 50)}...`);
                      resolve();
                    }
                  }
                );
              }
            }
          );
        });
        insertPromises.push(promise);
      });
    });

    // If no questions to insert, exit
    if (insertPromises.length === 0) {
      console.log('No questions to seed');
      process.exit(0);
    }

    // Wait for all questions to be inserted/updated
    Promise.all(insertPromises)
        .then(() => {
          console.log(`Successfully seeded ${insertPromises.length} questions`);
          process.exit(0);
        })
        .catch((err) => {
          console.error('Error seeding questions:', err);
          process.exit(1);
        });
  });
}

// Initialize database first, then seed
const { initDatabase } = require('../database/init');
initDatabase()
  .then(() => {
    console.log('Database initialized, seeding questions...');
    seedQuestions();
  })
  .catch((err) => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
  });

