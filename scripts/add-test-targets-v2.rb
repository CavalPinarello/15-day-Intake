#!/usr/bin/env ruby
#
# add-test-targets-v2.rb - Safely add test targets to Xcode project
#

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = 'ZoeSleep/ZoeSleep.xcodeproj'
BACKUP_PATH = 'ZoeSleep/ZoeSleep.xcodeproj.backup'

puts "="*50
puts "Adding Test Targets to ZoeSleep"
puts "="*50

# Backup the project first
puts "\n📦 Creating backup..."
FileUtils.rm_rf(BACKUP_PATH)
FileUtils.cp_r(PROJECT_PATH, BACKUP_PATH)
puts "   Backup created at #{BACKUP_PATH}"

begin
  puts "\n📂 Opening project..."
  project = Xcodeproj::Project.open(PROJECT_PATH)

  # Find the main iOS target
  main_target = project.targets.find { |t| t.name == 'ZoeSleep' && t.platform_name == :ios }
  unless main_target
    puts "❌ Could not find ZoeSleep iOS target"
    exit 1
  end
  puts "   Found main target: #{main_target.name}"

  # Check if test targets already exist
  if project.targets.any? { |t| t.name == 'ZoeSleepTests' }
    puts "✅ ZoeSleepTests already exists!"
    exit 0
  end

  # Find or create the Products group
  products_group = project.main_group['Products'] || project.main_group.new_group('Products')

  # Get the main group
  main_group = project.main_group

  # ============================================
  # Create Unit Test Target
  # ============================================
  puts "\n🧪 Creating ZoeSleepTests target..."

  # Create the target
  unit_test_target = project.new_target(:unit_test_bundle, 'ZoeSleepTests', :ios, '17.0')

  # Add dependency on main target
  unit_test_target.add_dependency(main_target)

  # Create group for test files
  tests_group = main_group.new_group('ZoeSleepTests', 'ZoeSleepTests')

  # Add test source files
  test_files = [
    'TestUtilities.swift',
    'QuestionnaireManagerTests.swift',
    'ClinicalScoringTests.swift',
    'AuthenticationManagerTests.swift',
    'ConvexServiceTests.swift',
    'HealthKitManagerTests.swift',
    'ThemeManagerTests.swift',
    'IntegrationTests.swift'
  ]

  test_files.each do |filename|
    file_path = "ZoeSleepTests/#{filename}"
    if File.exist?("ZoeSleep/#{file_path}")
      file_ref = tests_group.new_file(filename)
      unit_test_target.source_build_phase.add_file_reference(file_ref)
      puts "   Added: #{filename}"
    else
      puts "   ⚠️  Missing: #{filename}"
    end
  end

  # Configure build settings
  unit_test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'ZoeSleepTests/Info.plist'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.zoesleep.app.tests'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/ZoeSleep.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ZoeSleep'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    config.build_settings['DEVELOPMENT_TEAM'] = 'HA7H8BB975'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  end

  puts "   ✅ ZoeSleepTests target created"

  # ============================================
  # Create UI Test Target
  # ============================================
  puts "\n🖥️  Creating ZoeSleepUITests target..."

  # Create the target
  ui_test_target = project.new_target(:ui_test_bundle, 'ZoeSleepUITests', :ios, '17.0')

  # Add dependency on main target
  ui_test_target.add_dependency(main_target)

  # Create group for UI test files
  ui_tests_group = main_group.new_group('ZoeSleepUITests', 'ZoeSleepUITests')

  # Add UI test source file
  ui_test_file = 'ZoeSleepUITests.swift'
  if File.exist?("ZoeSleep/ZoeSleepUITests/#{ui_test_file}")
    file_ref = ui_tests_group.new_file(ui_test_file)
    ui_test_target.source_build_phase.add_file_reference(file_ref)
    puts "   Added: #{ui_test_file}"
  end

  # Configure build settings
  ui_test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'ZoeSleepUITests/Info.plist'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.zoesleep.app.uitests'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TEST_TARGET_NAME'] = 'ZoeSleep'
    config.build_settings['DEVELOPMENT_TEAM'] = 'HA7H8BB975'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  end

  puts "   ✅ ZoeSleepUITests target created"

  # ============================================
  # Update scheme to include tests
  # ============================================
  puts "\n📋 Updating scheme..."

  scheme_path = "#{PROJECT_PATH}/xcshareddata/xcschemes/ZoeSleep.xcscheme"
  if File.exist?(scheme_path)
    scheme = Xcodeproj::XCScheme.new(scheme_path)

    # Add unit test target to test action
    unit_testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(unit_test_target)
    scheme.test_action.add_testable(unit_testable)

    # Add UI test target to test action
    ui_testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_test_target)
    scheme.test_action.add_testable(ui_testable)

    scheme.save!
    puts "   ✅ Updated ZoeSleep scheme"
  else
    puts "   ⚠️  Scheme not found, creating new scheme..."
    scheme = Xcodeproj::XCScheme.new
    scheme.add_build_target(main_target)
    scheme.add_test_target(unit_test_target)
    scheme.add_test_target(ui_test_target)
    scheme.save_as(PROJECT_PATH, 'ZoeSleep')
    puts "   ✅ Created new scheme"
  end

  # ============================================
  # Save project
  # ============================================
  puts "\n💾 Saving project..."
  project.save
  puts "   ✅ Project saved"

  # Verify the save worked
  puts "\n🔍 Verifying project..."
  verify_result = `xcodebuild -project #{PROJECT_PATH} -list 2>&1`
  if verify_result.include?('ZoeSleepTests')
    puts "   ✅ ZoeSleepTests verified"
  else
    puts "   ⚠️  Verification inconclusive"
  end

  puts "\n" + "="*50
  puts "✅ SUCCESS! Test targets added."
  puts "="*50
  puts "\nNext steps:"
  puts "1. In Xcode: Close and reopen the project (File → Close Project, then reopen)"
  puts "2. Press Cmd+U to run tests"
  puts "\nIf issues occur, restore backup: cp -r #{BACKUP_PATH} #{PROJECT_PATH}"

rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  puts "\n🔄 Restoring backup..."
  FileUtils.rm_rf(PROJECT_PATH)
  FileUtils.cp_r(BACKUP_PATH, PROJECT_PATH)
  puts "   Backup restored"
  exit 1
end
