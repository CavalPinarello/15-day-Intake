const { getDatabase, initDatabase } = require('../database/init');

async function verifyAndFix() {
  await initDatabase();
  const db = getDatabase();

  return new Promise((resolve, reject) => {
    // Get all days
    db.all('SELECT * FROM days ORDER BY day_number', [], (err, days) => {
      if (err) {
        reject(err);
        return;
      }

      console.log('\n=== Days in Database ===');
      days.forEach(day => {
        console.log(`Day ${day.day_number}: id=${day.id}, title="${day.title}"`);
      });

      // Get all questions
      db.all(`
        SELECT q.*, d.day_number, d.title as day_title
        FROM questions q
        LEFT JOIN days d ON q.day_id = d.id
        ORDER BY q.id
      `, [], (err, questions) => {
        if (err) {
          reject(err);
          return;
        }

        console.log('\n=== Questions in Database ===');
        questions.forEach(q => {
          if (q.day_number) {
            console.log(`✓ Question ${q.id}: Linked to Day ${q.day_number} (id=${q.day_id}) - "${q.question_text.substring(0, 50)}..."`);
          } else {
            console.log(`✗ Question ${q.id}: NOT LINKED (day_id=${q.day_id} doesn't exist) - "${q.question_text.substring(0, 50)}..."`);
          }
        });

        // Fix any unlinked questions
        const unlinkedQuestions = questions.filter(q => !q.day_number);
        if (unlinkedQuestions.length > 0) {
          console.log(`\n=== Fixing ${unlinkedQuestions.length} unlinked questions ===`);
          
          unlinkedQuestions.forEach(q => {
            // Try to find matching day by question text patterns
            // This is a heuristic - you might need to adjust
            let targetDay = 1; // Default to Day 1
            
            // You can add logic here to match questions to days
            // For now, we'll just link them to Day 1
            db.run(
              'UPDATE questions SET day_id = (SELECT id FROM days WHERE day_number = ?) WHERE id = ?',
              [targetDay, q.id],
              (err) => {
                if (err) {
                  console.error(`Error fixing question ${q.id}:`, err);
                } else {
                  console.log(`  Fixed question ${q.id} -> Day ${targetDay}`);
                }
              }
            );
          });
        }

        // Summary
        console.log('\n=== Summary ===');
        console.log(`Days: ${days.length}`);
        console.log(`Questions: ${questions.length}`);
        console.log(`Linked questions: ${questions.filter(q => q.day_number).length}`);
        console.log(`Unlinked questions: ${unlinkedQuestions.length}`);

        resolve();
      });
    });
  });
}

verifyAndFix()
  .then(() => {
    console.log('\n✓ Verification complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });

