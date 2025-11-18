#!/usr/bin/env node

/**
 * Automated Test: Verify Slider is Rendering
 * This script will:
 * 1. Create a test user
 * 2. Login
 * 3. Fetch the journey/assessment data
 * 4. Check if the scale question has the correct type
 * 5. Open the browser and verify visually
 */

const https = require('https');
const http = require('http');
const { exec } = require('child_process');

const API_BASE = 'http://localhost:3002/api';
const FRONTEND_URL = 'http://localhost:3001';

// Utility to make HTTP requests
function makeRequest(url, method = 'GET', data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port,
      path: parsedUrl.pathname + parsedUrl.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const client = parsedUrl.protocol === 'https:' ? https : http;
    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          resolve({ status: res.statusCode, data: json, headers: res.headers });
        } catch (e) {
          resolve({ status: res.statusCode, data: body, headers: res.headers });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runTest() {
  console.log('\n🧪 AUTOMATED SLIDER TEST\n');
  console.log('=' .repeat(60));
  
  try {
    // Step 1: Create test user
    console.log('\n1️⃣  Creating test user...');
    const timestamp = Date.now();
    const testEmail = `slidertest${timestamp}@test.com`;
    const testPassword = 'TestPass123!';
    
    const registerRes = await makeRequest(`${API_BASE}/auth/register`, 'POST', {
      username: `testuser${timestamp}`,
      email: testEmail,
      password: testPassword,
      skipEmailVerification: true
    });

    if (registerRes.status !== 201) {
      throw new Error(`Registration failed: ${JSON.stringify(registerRes.data)}`);
    }
    
    console.log('✅ User created:', testEmail);
    const { accessToken, user } = registerRes.data;
    console.log('   User ID:', user.id);

    // Step 2: Fetch assessment data
    console.log('\n2️⃣  Fetching assessment data for user...');
    const assessmentRes = await makeRequest(
      `${API_BASE}/assessment/user/${user.id}/day/current`,
      'GET',
      null,
      { 'Authorization': `Bearer ${accessToken}` }
    );

    if (assessmentRes.status !== 200) {
      throw new Error(`Assessment fetch failed: ${JSON.stringify(assessmentRes.data)}`);
    }

    console.log('✅ Assessment data loaded');

    // Step 3: Check for scale questions
    console.log('\n3️⃣  Checking for scale questions in data...');
    const assessment = assessmentRes.data;
    
    let foundScaleQuestion = false;
    let scaleQuestionDetails = null;

    // Check sleep diary in day.diary
    if (assessment.day?.diary?.questions && assessment.day.diary.questions.length > 0) {
      for (const question of assessment.day.diary.questions) {
        if (question.type === 'scale' || question.question_type === 'scale') {
          foundScaleQuestion = true;
          scaleQuestionDetails = question;
          break;
        }
      }
    }

    // Check modules in day.modules
    if (!foundScaleQuestion && assessment.day?.modules) {
      for (const module of assessment.day.modules) {
        if (module.questions) {
          for (const question of module.questions) {
            if (question.type === 'scale' || question.question_type === 'scale') {
              foundScaleQuestion = true;
              scaleQuestionDetails = question;
              break;
            }
          }
        }
        if (foundScaleQuestion) break;
      }
    }

    if (foundScaleQuestion) {
      console.log('✅ SCALE QUESTION FOUND IN DATA!');
      console.log('\n📊 Scale Question Details:');
      console.log('   ID:', scaleQuestionDetails.id);
      console.log('   Text:', scaleQuestionDetails.text || scaleQuestionDetails.question_text);
      console.log('   Type:', scaleQuestionDetails.type || scaleQuestionDetails.question_type);
      console.log('   Scale Min:', scaleQuestionDetails.scaleMin);
      console.log('   Scale Max:', scaleQuestionDetails.scaleMax);
      console.log('   Min Label:', scaleQuestionDetails.scaleMinLabel);
      console.log('   Max Label:', scaleQuestionDetails.scaleMaxLabel);
    } else {
      console.log('❌ NO SCALE QUESTIONS FOUND IN DATA');
      console.log('\n📄 Diary section:');
      console.log(JSON.stringify(assessment.day?.diary, null, 2));
      console.log('\n📋 Number of modules:', assessment.day?.modules?.length || 0);
      if (assessment.day?.diary?.questions) {
        console.log('📋 Number of diary questions:', assessment.day.diary.questions.length);
        console.log('📋 First diary question type:', assessment.day.diary.questions[0]?.type);
      }
    }

    // Step 4: Open browser
    console.log('\n4️⃣  Opening browser for visual verification...');
    console.log(`   URL: ${FRONTEND_URL}/journey`);
    console.log('\n📋 Test User Credentials:');
    console.log(`   Email: ${testEmail}`);
    console.log(`   Password: ${testPassword}`);
    console.log(`   Access Token: ${accessToken.substring(0, 20)}...`);

    // Open browser (works on macOS)
    exec(`open "${FRONTEND_URL}/login"`, (error) => {
      if (error) {
        console.log('\n⚠️  Could not auto-open browser. Please open manually:');
        console.log(`   ${FRONTEND_URL}/login`);
      } else {
        console.log('✅ Browser opened');
      }
    });

    console.log('\n' + '='.repeat(60));
    console.log('✅ TEST COMPLETE');
    console.log('\n📌 NEXT STEPS:');
    console.log('1. Login with the test credentials above');
    console.log('2. Navigate to the journey page');
    console.log('3. Check if you see a SLIDER for the sleep quality question');
    console.log('4. Open browser console (F12) and look for:');
    console.log('   🔍 QuestionCard DEBUG: { questionType: "scale", ... }');
    console.log('   🎚️ RENDERING SLIDER - QuestionCard.tsx updated!');
    console.log('\n' + '='.repeat(60) + '\n');

  } catch (error) {
    console.error('\n❌ TEST FAILED:', error.message);
    console.error('\nFull error:', error);
    process.exit(1);
  }
}

runTest();

