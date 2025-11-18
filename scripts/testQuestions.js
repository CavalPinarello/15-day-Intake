/**
 * Test script to verify question conversion and data integrity
 */

const fs = require('fs');
const path = require('path');

function testConvertedQuestions() {
  console.log('🧪 Testing Converted Questions...\n');

  // Load converted files
  const assessmentFile = path.join(
    __dirname,
    '../data/converted/assessment_questions_converted.json'
  );
  const diaryFile = path.join(
    __dirname,
    '../data/converted/sleep_diary_questions_converted.json'
  );

  const assessmentQuestions = JSON.parse(fs.readFileSync(assessmentFile, 'utf8'));
  const diaryQuestions = JSON.parse(fs.readFileSync(diaryFile, 'utf8'));

  console.log(`✅ Loaded ${assessmentQuestions.length} assessment questions`);
  console.log(`✅ Loaded ${diaryQuestions.length} sleep diary questions\n`);

  // Test 1: Check all questions have required fields
  console.log('Test 1: Checking required fields...');
  let errors = [];

  for (const q of assessmentQuestions) {
    if (!q.question_id) errors.push(`Missing question_id`);
    if (!q.question_text) errors.push(`Missing question_text for ${q.question_id}`);
    if (!q.answer_format) errors.push(`Missing answer_format for ${q.question_id}`);
    if (!q.format_config) errors.push(`Missing format_config for ${q.question_id}`);
    if (!q.pillar) errors.push(`Missing pillar for ${q.question_id}`);
  }

  if (errors.length > 0) {
    console.log(`❌ Found ${errors.length} errors:`);
    errors.forEach((e) => console.log(`   - ${e}`));
  } else {
    console.log(`✅ All assessment questions have required fields`);
  }

  // Test 2: Check answer format distribution
  console.log('\nTest 2: Answer format distribution...');
  const formatCounts = {};
  for (const q of assessmentQuestions) {
    formatCounts[q.answer_format] = (formatCounts[q.answer_format] || 0) + 1;
  }

  console.log('Assessment Questions:');
  Object.entries(formatCounts)
    .sort((a, b) => b[1] - a[1])
    .forEach(([format, count]) => {
      console.log(`   ${format}: ${count}`);
    });

  const diaryFormatCounts = {};
  for (const q of diaryQuestions) {
    diaryFormatCounts[q.answer_format] = (diaryFormatCounts[q.answer_format] || 0) + 1;
  }

  console.log('\nSleep Diary Questions:');
  Object.entries(diaryFormatCounts)
    .sort((a, b) => b[1] - a[1])
    .forEach(([format, count]) => {
      console.log(`   ${format}: ${count}`);
    });

  // Test 3: Validate format_config JSON
  console.log('\nTest 3: Validating format_config JSON...');
  let jsonErrors = 0;
  for (const q of [...assessmentQuestions, ...diaryQuestions]) {
    try {
      if (typeof q.format_config === 'object') {
        // Already parsed, that's fine
      } else {
        JSON.parse(q.format_config);
      }
    } catch (e) {
      jsonErrors++;
      console.log(
        `   ❌ Invalid JSON for ${q.question_id || q.id}: ${e.message}`
      );
    }
  }
  if (jsonErrors === 0) {
    console.log(`✅ All format_config fields are valid JSON`);
  }

  // Test 4: Check validation rules
  console.log('\nTest 4: Checking validation rules...');
  let validationErrors = 0;
  for (const q of assessmentQuestions) {
    if (q.validation_rules) {
      try {
        if (typeof q.validation_rules === 'object') {
          // Already parsed
        } else {
          JSON.parse(q.validation_rules);
        }
      } catch (e) {
        validationErrors++;
        console.log(`   ❌ Invalid validation_rules for ${q.question_id}`);
      }
    }
  }
  if (validationErrors === 0) {
    console.log(`✅ All validation_rules are valid`);
  }

  // Test 5: Pillar distribution
  console.log('\nTest 5: Pillar distribution...');
  const pillarCounts = {};
  for (const q of assessmentQuestions) {
    pillarCounts[q.pillar] = (pillarCounts[q.pillar] || 0) + 1;
  }

  Object.entries(pillarCounts)
    .sort((a, b) => b[1] - a[1])
    .forEach(([pillar, count]) => {
      console.log(`   ${pillar}: ${count} questions`);
    });

  // Test 6: Tier distribution
  console.log('\nTest 6: Tier distribution...');
  const tierCounts = {};
  for (const q of assessmentQuestions) {
    tierCounts[q.tier] = (tierCounts[q.tier] || 0) + 1;
  }

  Object.entries(tierCounts).forEach(([tier, count]) => {
    console.log(`   ${tier}: ${count} questions`);
  });

  // Test 7: Sample questions from each format
  console.log('\nTest 7: Sample questions from each format...');
  const samplesByFormat = {};
  for (const q of [...assessmentQuestions, ...diaryQuestions]) {
    const format = q.answer_format;
    if (!samplesByFormat[format]) {
      samplesByFormat[format] = q;
    }
  }

  console.log('\nSample questions:');
  Object.entries(samplesByFormat).forEach(([format, q]) => {
    console.log(`\n   ${format}:`);
    console.log(`      ID: ${q.question_id || q.id}`);
    console.log(`      Text: ${q.question_text.substring(0, 60)}...`);
    const config =
      typeof q.format_config === 'string'
        ? JSON.parse(q.format_config)
        : q.format_config;
    console.log(`      Config: ${JSON.stringify(config).substring(0, 100)}...`);
  });

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 Summary:');
  console.log(`   Total Assessment Questions: ${assessmentQuestions.length}`);
  console.log(`   Total Sleep Diary Questions: ${diaryQuestions.length}`);
  console.log(`   Total Errors: ${errors.length + jsonErrors + validationErrors}`);
  console.log(
    `   Status: ${errors.length + jsonErrors + validationErrors === 0 ? '✅ PASS' : '❌ FAIL'}`
  );
  console.log('='.repeat(60));
}

if (require.main === module) {
  testConvertedQuestions();
}

module.exports = { testConvertedQuestions };


