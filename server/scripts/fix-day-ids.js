const { getDatabase, initDatabase } = require('../database/init');

async function fixDayIds() {
  await initDatabase();
  const db = getDatabase();

  return new Promise((resolve, reject) => {
    // Get all days
    db.all('SELECT * FROM days ORDER BY day_number', [], (err, days) => {
      if (err) {
        reject(err);
        return;
      }

      // Create a map of day_number to day.id
      const dayMap = {};
      days.forEach(day => {
        dayMap[day.day_number] = day.id;
      });

      console.log('Day mapping:');
      Object.keys(dayMap).forEach(dayNum => {
        console.log(`  Day ${dayNum} -> id ${dayMap[dayNum]}`);
      });

      // Get all questions
      db.all('SELECT * FROM questions', [], (err, questions) => {
        if (err) {
          reject(err);
          return;
        }

        console.log(`\nFound ${questions.length} questions`);

        // Fix questions that have wrong day_ids
        let fixed = 0;
        questions.forEach(q => {
          // Get the day for this question
          const day = days.find(d => d.id === q.day_id);
          if (!day) {
            console.log(`Question ${q.id} has invalid day_id ${q.day_id}`);
            // Try to find by question text pattern or leave it
            return;
          }

          // Check if the question text suggests it belongs to a different day
          // This is a simple heuristic - in production you'd have better data
          console.log(`Question ${q.id}: day_id=${q.day_id} (Day ${day.day_number}) - "${q.question_text.substring(0, 50)}..."`);
        });

        // For now, we'll just verify the questions are correctly linked
        // The seed script should handle this correctly going forward
        resolve();
      });
    });
  });
}

fixDayIds()
  .then(() => {
    console.log('\nDay ID verification complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });

