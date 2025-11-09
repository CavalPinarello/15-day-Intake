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

      // If no questions to insert, exit
      if (insertPromises.length === 0) {
        console.log('No questions to seed');
        process.exit(0);
      }
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

