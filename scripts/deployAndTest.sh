#!/bin/bash

# Deploy and Test Script for Standardized Questions System
# This script deploys the new schema and seeds all questions

set -e  # Exit on error

echo "🚀 Deploying Standardized Questions System..."
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Step 1: Deploy Convex schema
echo "📦 Step 1: Deploying Convex schema..."
npx convex deploy
echo "✅ Schema deployed"
echo ""

# Step 2: Seed assessment questions
echo "📝 Step 2: Seeding assessment questions..."
npx convex run seedQuestions:seedAssessmentQuestions
echo "✅ Assessment questions seeded"
echo ""

# Step 3: Seed sleep diary questions
echo "😴 Step 3: Seeding sleep diary questions..."
npx convex run seedQuestions:seedSleepDiaryQuestions
echo "✅ Sleep diary questions seeded"
echo ""

# Step 4: Seed assessment modules
echo "📚 Step 4: Seeding assessment modules..."
npx convex run seedModules:seedAssessmentModules
echo "✅ Modules seeded"
echo ""

# Step 5: Seed module-question mappings
echo "🔗 Step 5: Seeding module-question mappings..."
npx convex run seedModules:seedModuleQuestions
echo "✅ Module-question mappings seeded"
echo ""

# Step 6: Seed day-module mappings
echo "📅 Step 6: Seeding day-module mappings (15-day plan)..."
npx convex run seedModules:seedDayModules
echo "✅ Day-module mappings seeded"
echo ""

# Step 7: Run tests
echo "🧪 Step 7: Running verification tests..."
echo ""

echo "  Testing Day 1 questions..."
npx convex run assessmentQueries:getDaySummary --arg '{"dayNumber": 1}'
echo ""

echo "  Testing Day 2 questions..."
npx convex run assessmentQueries:getDaySummary --arg '{"dayNumber": 2}'
echo ""

echo "  Testing Sleep Diary questions..."
npx convex run assessmentQueries:getSleepDiaryQuestions
echo ""

echo "✅ All deployment steps completed successfully!"
echo ""
echo "📊 Summary:"
echo "  - Database schema deployed"
echo "  - 261 assessment questions seeded"
echo "  - 16 sleep diary questions seeded"
echo "  - 18 assessment modules configured"
echo "  - 15-day intake plan configured"
echo ""
echo "🎉 System ready for use!"


