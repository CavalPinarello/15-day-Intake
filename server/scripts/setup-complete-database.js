#!/usr/bin/env node
/**
 * Complete Database Setup Script
 * Sets up all database tables for all components
 */

const { initDatabase } = require('../database/init');
const { completeSchemaSetup, verifyDatabaseIntegrity } = require('../database/schema_complete');

async function setupCompleteDatabase() {
  console.log('='.repeat(60));
  console.log('Complete Database Setup');
  console.log('='.repeat(60));
  
  try {
    // Step 1: Initialize base database
    console.log('\n1. Initializing base database...');
    await initDatabase();
    console.log('   ✓ Base database initialized');
    
    // Step 2: Complete schema setup
    console.log('\n2. Setting up complete schema...');
    await completeSchemaSetup();
    console.log('   ✓ Complete schema setup finished');
    
    // Step 3: Verify integrity
    console.log('\n3. Verifying database integrity...');
    await verifyDatabaseIntegrity();
    console.log('   ✓ Database integrity verified');
    
    console.log('\n' + '='.repeat(60));
    console.log('✓ Complete database setup successful!');
    console.log('='.repeat(60));
    console.log('\nAll components are now integrated:');
    console.log('  ✓ Component 1: 14-Day Onboarding Journey');
    console.log('  ✓ Component 2: Daily App Use');
    console.log('  ✓ Component 3: Full Sleep Report');
    console.log('  ✓ Component 4: Coach Dashboard');
    console.log('  ✓ Component 5: Supporting Systems');
    console.log('\nDatabase is ready for use!');
    
    process.exit(0);
  } catch (error) {
    console.error('\n✗ Database setup failed:', error);
    process.exit(1);
  }
}

setupCompleteDatabase();




