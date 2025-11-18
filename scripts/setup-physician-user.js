/**
 * Setup script to configure user roles and create physician account
 * 
 * This script:
 * 1. Migrates all existing users to have "patient" role
 * 2. Sets the "physician" user to have "physician" role
 * 3. Creates a physician user if it doesn't exist
 */

const { ConvexHttpClient } = require("convex/browser");
const { api } = require("../convex/_generated/api");
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function setupPhysicianUser() {
  try {
    // Get Convex URL from environment
    const convexUrl = process.env.NEXT_PUBLIC_CONVEX_URL || process.env.CONVEX_URL;
    
    if (!convexUrl) {
      console.error('❌ NEXT_PUBLIC_CONVEX_URL or CONVEX_URL not found');
      console.log('\nPlease set your Convex URL:');
      console.log('  export NEXT_PUBLIC_CONVEX_URL="https://your-deployment.convex.cloud"');
      process.exit(1);
    }

    console.log('🔗 Connecting to Convex:', convexUrl);
    const client = new ConvexHttpClient(convexUrl);

    // Step 1: Migrate existing users to have "patient" role
    console.log('\n📋 Step 1: Migrating existing users to "patient" role...');
    const migrationResult = await client.mutation(api.users.migrateUserRoles, {});
    console.log(`✅ ${migrationResult.message}`);

    // Step 2: Check if physician user exists
    console.log('\n📋 Step 2: Checking for physician user...');
    const physicianUser = await client.query(api.users.getUserByUsername, { username: 'physician' });

    if (physicianUser) {
      console.log('✅ Physician user found');
      console.log(`   Current role: ${physicianUser.role || '(none)'}`);
      
      if (physicianUser.role !== 'physician') {
        console.log('🔄 Updating physician user role...');
        await client.mutation(api.users.setRoleByUsername, {
          username: 'physician',
          role: 'physician'
        });
        console.log('✅ Physician role updated');
      } else {
        console.log('✅ Physician role already set correctly');
      }
    } else {
      console.log('⚠️  Physician user not found');
      console.log('\nYou need to create a physician user first.');
      console.log('Please register a user with username "physician" at:');
      console.log('  http://localhost:3000/register');
      console.log('\nAfter registration, run this script again to set the role.');
    }

    // Step 3: List all users with roles
    console.log('\n📋 Step 3: Current users and their roles:');
    const allUsers = await client.query(api.users.getAllUsers, {});
    console.log('\nUsername                 | Role       ');
    console.log('-------------------------|------------');
    allUsers.forEach(user => {
      const username = user.username.padEnd(24);
      const role = (user.role || 'patient').padEnd(11);
      console.log(`${username} | ${role}`);
    });

    console.log('\n✅ Setup complete!');
    console.log('\nPhysician login details:');
    console.log('  Username: physician');
    console.log('  URL: http://localhost:3000/login');
    console.log('\nAfter login, physicians will be redirected to:');
    console.log('  http://localhost:3000/physician-dashboard');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  } finally {
    rl.close();
  }
}

// Run the setup
setupPhysicianUser();



