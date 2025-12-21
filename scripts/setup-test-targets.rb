#!/usr/bin/env ruby
#
# setup-test-targets.rb
# Adds ZoeSleepTests and ZoeSleepUITests targets to the Xcode project
#
# Usage: ruby scripts/setup-test-targets.rb
#
# Requires: gem install xcodeproj
#

require 'xcodeproj'

PROJECT_PATH = 'ZoeSleep/ZoeSleep.xcodeproj'

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find main target
main_target = project.targets.find { |t| t.name == 'ZoeSleep' }
unless main_target
  puts "Error: Could not find ZoeSleep target"
  exit 1
end

puts "Found main target: #{main_target.name}"

# Check if test targets already exist
existing_unit_test = project.targets.find { |t| t.name == 'ZoeSleepTests' }
existing_ui_test = project.targets.find { |t| t.name == 'ZoeSleepUITests' }

# Create Unit Test Target
unless existing_unit_test
  puts "Creating ZoeSleepTests target..."

  unit_test_target = project.new_target(:unit_test_bundle, 'ZoeSleepTests', :ios, '17.0')
  unit_test_target.add_dependency(main_target)

  # Create group for test files
  tests_group = project.main_group.find_subpath('ZoeSleepTests', true)
  tests_group.set_source_tree('<group>')
  tests_group.set_path('ZoeSleepTests')

  # Add test files
  test_files = Dir.glob('ZoeSleep/ZoeSleepTests/*.swift')
  test_files.each do |file|
    file_ref = tests_group.new_file(File.basename(file))
    unit_test_target.source_build_phase.add_file_reference(file_ref)
  end

  # Add Info.plist
  info_plist = tests_group.new_file('Info.plist')

  # Configure build settings
  unit_test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'ZoeSleepTests/Info.plist'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.zoesleep.app.tests'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/ZoeSleep.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ZoeSleep'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  end

  puts "Created ZoeSleepTests target with #{test_files.count} files"
else
  puts "ZoeSleepTests target already exists"
end

# Create UI Test Target
unless existing_ui_test
  puts "Creating ZoeSleepUITests target..."

  ui_test_target = project.new_target(:ui_test_bundle, 'ZoeSleepUITests', :ios, '17.0')
  ui_test_target.add_dependency(main_target)

  # Create group for UI test files
  ui_tests_group = project.main_group.find_subpath('ZoeSleepUITests', true)
  ui_tests_group.set_source_tree('<group>')
  ui_tests_group.set_path('ZoeSleepUITests')

  # Add UI test files
  ui_test_files = Dir.glob('ZoeSleep/ZoeSleepUITests/*.swift')
  ui_test_files.each do |file|
    file_ref = ui_tests_group.new_file(File.basename(file))
    ui_test_target.source_build_phase.add_file_reference(file_ref)
  end

  # Add Info.plist
  info_plist = ui_tests_group.new_file('Info.plist')

  # Configure build settings
  ui_test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'ZoeSleepUITests/Info.plist'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.zoesleep.app.uitests'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TEST_TARGET_NAME'] = 'ZoeSleep'
  end

  puts "Created ZoeSleepUITests target with #{ui_test_files.count} files"
else
  puts "ZoeSleepUITests target already exists"
end

# Update scheme to include test targets
puts "Updating scheme..."

scheme_path = "#{PROJECT_PATH}/xcshareddata/xcschemes/ZoeSleep.xcscheme"
if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path)

  # Add test targets to scheme
  unit_test_target = project.targets.find { |t| t.name == 'ZoeSleepTests' }
  ui_test_target = project.targets.find { |t| t.name == 'ZoeSleepUITests' }

  if unit_test_target
    testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(unit_test_target)
    scheme.test_action.add_testable(testable)
  end

  if ui_test_target
    testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_test_target)
    scheme.test_action.add_testable(testable)
  end

  scheme.save!
  puts "Updated ZoeSleep scheme with test targets"
else
  puts "Warning: Scheme file not found, please add test targets manually in Xcode"
end

# Save project
project.save
puts "Project saved successfully!"
puts ""
puts "Next steps:"
puts "1. Open Xcode and verify the test targets appear"
puts "2. Build the project (Cmd+B)"
puts "3. Run tests (Cmd+U)"
