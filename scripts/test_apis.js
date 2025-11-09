#!/usr/bin/env node
/**
 * API Testing Script
 * Tests all endpoints to ensure they work correctly
 */

const http = require('http');

const BASE_URL = 'http://localhost:3001/api';
let accessToken = null;
let refreshToken = null;
let userId = null;

// Helper function to make HTTP requests
function makeRequest(method, path, data = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    if (data) {
      options.headers['Content-Length'] = JSON.stringify(data).length;
    }

    const req = http.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, data: parsed, headers: res.headers });
        } catch (e) {
          resolve({ status: res.statusCode, data: body, headers: res.headers });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

// Test functions
async function testHealthCheck() {
  console.log('\n1. Testing Health Check...');
  try {
    const result = await makeRequest('GET', '/api/health-check');
    if (result.status === 200) {
      console.log('   ✓ Health check passed');
      return true;
    } else {
      console.log(`   ✗ Health check failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Health check error: ${error.message}`);
    return false;
  }
}

async function testLogin() {
  console.log('\n2. Testing Login...');
  try {
    const result = await makeRequest('POST', '/api/auth/login', {
      username: 'user1',
      password: '1'
    });

    if (result.status === 200 && result.data.accessToken) {
      accessToken = result.data.accessToken;
      refreshToken = result.data.refreshToken;
      userId = result.data.user.id;
      console.log('   ✓ Login successful');
      console.log(`   ✓ User ID: ${userId}`);
      console.log(`   ✓ Access Token: ${accessToken.substring(0, 20)}...`);
      return true;
    } else {
      console.log(`   ✗ Login failed: ${result.status}`);
      console.log(`   Response: ${JSON.stringify(result.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Login error: ${error.message}`);
    return false;
  }
}

async function testGetMe() {
  console.log('\n3. Testing GET /api/auth/me...');
  try {
    const result = await makeRequest('GET', '/api/auth/me', null, accessToken);
    if (result.status === 200 && result.data.user) {
      console.log('   ✓ Get current user successful');
      console.log(`   ✓ Username: ${result.data.user.username}`);
      return true;
    } else {
      console.log(`   ✗ Get me failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Get me error: ${error.message}`);
    return false;
  }
}

async function testHealthSync() {
  console.log('\n4. Testing POST /api/health/sync...');
  try {
    const testData = {
      sleepData: [{
        date: new Date().toISOString().split('T')[0],
        total_sleep_mins: 480,
        sleep_efficiency: 85.5,
        deep_sleep_mins: 120,
        light_sleep_mins: 180,
        rem_sleep_mins: 90,
        awake_mins: 90,
        interruptions_count: 2,
        sleep_latency_mins: 30
      }],
      activityData: [{
        date: new Date().toISOString().split('T')[0],
        steps: 8500,
        active_mins: 45,
        exercise_mins: 30,
        calories_burned: 450
      }],
      heartRateData: [{
        date: new Date().toISOString().split('T')[0],
        resting_hr: 58,
        avg_hr: 62,
        hrv_morning: 45.2,
        hrv_avg: 42.1
      }]
    };

    const result = await makeRequest('POST', '/api/health/sync', testData, accessToken);
    if (result.status === 200 && result.data.success) {
      console.log('   ✓ Health data sync successful');
      console.log(`   ✓ Sleep data: ${result.data.results.sleepData.inserted} inserted`);
      console.log(`   ✓ Activity data: ${result.data.results.activityData.inserted} inserted`);
      return true;
    } else {
      console.log(`   ✗ Health sync failed: ${result.status}`);
      console.log(`   Response: ${JSON.stringify(result.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Health sync error: ${error.message}`);
    return false;
  }
}

async function testGetSleepData() {
  console.log('\n5. Testing GET /api/health/sleep/:date...');
  try {
    const today = new Date().toISOString().split('T')[0];
    const result = await makeRequest('GET', `/api/health/sleep/${today}`, null, accessToken);
    if (result.status === 200 || result.status === 404) {
      if (result.status === 200) {
        console.log('   ✓ Get sleep data successful');
        console.log(`   ✓ Total sleep: ${result.data.sleepData.total_sleep_mins} mins`);
      } else {
        console.log('   ⚠ No sleep data found (this is OK if not synced yet)');
      }
      return true;
    } else {
      console.log(`   ✗ Get sleep data failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Get sleep data error: ${error.message}`);
    return false;
  }
}

async function testGetHealthSummary() {
  console.log('\n6. Testing GET /api/health/summary...');
  try {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 30);
    const endDate = new Date();
    const result = await makeRequest(
      'GET',
      `/api/health/summary?startDate=${startDate.toISOString().split('T')[0]}&endDate=${endDate.toISOString().split('T')[0]}`,
      null,
      accessToken
    );
    if (result.status === 200) {
      console.log('   ✓ Get health summary successful');
      if (result.data.sleep.avg_sleep_mins) {
        console.log(`   ✓ Avg sleep: ${Math.round(result.data.sleep.avg_sleep_mins)} mins`);
      }
      return true;
    } else {
      console.log(`   ✗ Get health summary failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Get health summary error: ${error.message}`);
    return false;
  }
}

async function testGetActiveInterventions() {
  console.log('\n7. Testing GET /api/user/interventions/active...');
  try {
    const result = await makeRequest('GET', '/api/user/interventions/active', null, accessToken);
    if (result.status === 200) {
      console.log('   ✓ Get active interventions successful');
      console.log(`   ✓ Found ${result.data.interventions.length} active interventions`);
      return true;
    } else {
      console.log(`   ✗ Get active interventions failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Get active interventions error: ${error.message}`);
    return false;
  }
}

async function testRefreshToken() {
  console.log('\n8. Testing POST /api/auth/refresh...');
  try {
    if (!refreshToken) {
      console.log('   ⚠ No refresh token available, skipping');
      return true;
    }

    const result = await makeRequest('POST', '/api/auth/refresh', {
      refreshToken: refreshToken
    });

    if (result.status === 200 && result.data.accessToken) {
      console.log('   ✓ Token refresh successful');
      accessToken = result.data.accessToken; // Update token
      return true;
    } else {
      console.log(`   ✗ Token refresh failed: ${result.status}`);
      return false;
    }
  } catch (error) {
    console.log(`   ✗ Token refresh error: ${error.message}`);
    return false;
  }
}

// Run all tests
async function runTests() {
  console.log('='.repeat(60));
  console.log('API Testing Suite');
  console.log('='.repeat(60));

  const results = [];

  results.push(await testHealthCheck());
  results.push(await testLogin());

  if (accessToken) {
    results.push(await testGetMe());
    results.push(await testHealthSync());
    results.push(await testGetSleepData());
    results.push(await testGetHealthSummary());
    results.push(await testGetActiveInterventions());
    results.push(await testRefreshToken());
  } else {
    console.log('\n⚠ Skipping authenticated tests - login failed');
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('Test Summary');
  console.log('='.repeat(60));
  const passed = results.filter(r => r).length;
  const total = results.length;
  console.log(`Passed: ${passed}/${total}`);
  console.log(`Failed: ${total - passed}/${total}`);

  if (passed === total) {
    console.log('\n✓ All tests passed!');
    process.exit(0);
  } else {
    console.log('\n✗ Some tests failed');
    process.exit(1);
  }
}

// Check if server is running first
makeRequest('GET', '/api/health-check')
  .then(() => {
    runTests();
  })
  .catch((error) => {
    console.error('Error: Server is not running or not accessible');
    console.error('Please start the server with: cd server && npm run dev');
    console.error(`Error details: ${error.message}`);
    process.exit(1);
  });

