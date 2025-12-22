#!/usr/bin/env python3
"""
Add ZoeSleepTests and ZoeSleepUITests targets to the Xcode project.
This script modifies project.pbxproj directly.
"""

import os
import re
import uuid
import hashlib

PROJECT_PATH = "ZoeSleep/ZoeSleep.xcodeproj/project.pbxproj"

def generate_uuid():
    """Generate a 24-character UUID for Xcode."""
    return hashlib.md5(uuid.uuid4().bytes).hexdigest()[:24].upper()

# Generate UUIDs for all new objects
UUIDS = {
    # ZoeSleepTests
    "tests_target": generate_uuid(),
    "tests_product": generate_uuid(),
    "tests_sources_phase": generate_uuid(),
    "tests_frameworks_phase": generate_uuid(),
    "tests_resources_phase": generate_uuid(),
    "tests_dependency": generate_uuid(),
    "tests_container_proxy": generate_uuid(),
    "tests_config_list": generate_uuid(),
    "tests_debug_config": generate_uuid(),
    "tests_release_config": generate_uuid(),
    "tests_group": generate_uuid(),
    # Test files
    "tests_file_utilities": generate_uuid(),
    "tests_file_questionnaire": generate_uuid(),
    "tests_file_clinical": generate_uuid(),
    "tests_file_auth": generate_uuid(),
    "tests_file_convex": generate_uuid(),
    "tests_file_healthkit": generate_uuid(),
    "tests_file_theme": generate_uuid(),
    "tests_file_integration": generate_uuid(),
    "tests_file_info": generate_uuid(),
    # Build files
    "tests_build_utilities": generate_uuid(),
    "tests_build_questionnaire": generate_uuid(),
    "tests_build_clinical": generate_uuid(),
    "tests_build_auth": generate_uuid(),
    "tests_build_convex": generate_uuid(),
    "tests_build_healthkit": generate_uuid(),
    "tests_build_theme": generate_uuid(),
    "tests_build_integration": generate_uuid(),
    # ZoeSleepUITests
    "uitests_target": generate_uuid(),
    "uitests_product": generate_uuid(),
    "uitests_sources_phase": generate_uuid(),
    "uitests_frameworks_phase": generate_uuid(),
    "uitests_resources_phase": generate_uuid(),
    "uitests_dependency": generate_uuid(),
    "uitests_container_proxy": generate_uuid(),
    "uitests_config_list": generate_uuid(),
    "uitests_debug_config": generate_uuid(),
    "uitests_release_config": generate_uuid(),
    "uitests_group": generate_uuid(),
    "uitests_file_main": generate_uuid(),
    "uitests_file_info": generate_uuid(),
    "uitests_build_main": generate_uuid(),
}

# Read the project file
with open(PROJECT_PATH, 'r') as f:
    content = f.read()

# Check if targets already exist
if "ZoeSleepTests" in content:
    print("ZoeSleepTests target already exists!")
    exit(0)

print("Adding test targets to project...")

# Find the main target UUID
main_target_match = re.search(r'(\w{24}) /\* ZoeSleep \*/ = \{[^}]*isa = PBXNativeTarget', content)
if not main_target_match:
    print("Could not find main target!")
    exit(1)
main_target_uuid = main_target_match.group(1)
print(f"Found main target: {main_target_uuid}")

# Find Products group UUID
products_group_match = re.search(r'(\w{24}) /\* Products \*/ = \{', content)
products_group_uuid = products_group_match.group(1) if products_group_match else None

# Find main group UUID
main_group_match = re.search(r'mainGroup = (\w{24})', content)
main_group_uuid = main_group_match.group(1) if main_group_match else None

# 1. Add PBXBuildFile entries (after existing ones)
build_files = f'''
		{UUIDS["tests_build_utilities"]} /* TestUtilities.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_utilities"]} /* TestUtilities.swift */; }};
		{UUIDS["tests_build_questionnaire"]} /* QuestionnaireManagerTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_questionnaire"]} /* QuestionnaireManagerTests.swift */; }};
		{UUIDS["tests_build_clinical"]} /* ClinicalScoringTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_clinical"]} /* ClinicalScoringTests.swift */; }};
		{UUIDS["tests_build_auth"]} /* AuthenticationManagerTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_auth"]} /* AuthenticationManagerTests.swift */; }};
		{UUIDS["tests_build_convex"]} /* ConvexServiceTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_convex"]} /* ConvexServiceTests.swift */; }};
		{UUIDS["tests_build_healthkit"]} /* HealthKitManagerTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_healthkit"]} /* HealthKitManagerTests.swift */; }};
		{UUIDS["tests_build_theme"]} /* ThemeManagerTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_theme"]} /* ThemeManagerTests.swift */; }};
		{UUIDS["tests_build_integration"]} /* IntegrationTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["tests_file_integration"]} /* IntegrationTests.swift */; }};
		{UUIDS["uitests_build_main"]} /* ZoeSleepUITests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {UUIDS["uitests_file_main"]} /* ZoeSleepUITests.swift */; }};
'''

content = content.replace(
    "/* End PBXBuildFile section */",
    build_files + "/* End PBXBuildFile section */"
)

# 2. Add PBXContainerItemProxy entries
container_proxies = f'''
/* Begin PBXContainerItemProxy section */
		{UUIDS["tests_container_proxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 4A5E3B7D2C8E123456789A14 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {main_target_uuid};
			remoteInfo = ZoeSleep;
		}};
		{UUIDS["uitests_container_proxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = 4A5E3B7D2C8E123456789A14 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {main_target_uuid};
			remoteInfo = ZoeSleep;
		}};
/* End PBXContainerItemProxy section */

'''

# Insert after PBXBuildFile section
content = content.replace(
    "/* End PBXBuildFile section */\n\n/* Begin PBXFileReference section */",
    "/* End PBXBuildFile section */\n\n" + container_proxies + "/* Begin PBXFileReference section */"
)

# 3. Add PBXFileReference entries
file_refs = f'''
		{UUIDS["tests_product"]} /* ZoeSleepTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ZoeSleepTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{UUIDS["uitests_product"]} /* ZoeSleepUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ZoeSleepUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{UUIDS["tests_file_utilities"]} /* TestUtilities.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TestUtilities.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_questionnaire"]} /* QuestionnaireManagerTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = QuestionnaireManagerTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_clinical"]} /* ClinicalScoringTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClinicalScoringTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_auth"]} /* AuthenticationManagerTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AuthenticationManagerTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_convex"]} /* ConvexServiceTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ConvexServiceTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_healthkit"]} /* HealthKitManagerTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HealthKitManagerTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_theme"]} /* ThemeManagerTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ThemeManagerTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_integration"]} /* IntegrationTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IntegrationTests.swift; sourceTree = "<group>"; }};
		{UUIDS["tests_file_info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{UUIDS["uitests_file_main"]} /* ZoeSleepUITests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ZoeSleepUITests.swift; sourceTree = "<group>"; }};
		{UUIDS["uitests_file_info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
'''

content = content.replace(
    "/* End PBXFileReference section */",
    file_refs + "/* End PBXFileReference section */"
)

# 4. Add PBXFrameworksBuildPhase entries
frameworks_phases = f'''
		{UUIDS["tests_frameworks_phase"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{UUIDS["uitests_frameworks_phase"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
'''

content = content.replace(
    "/* End PBXFrameworksBuildPhase section */",
    frameworks_phases + "/* End PBXFrameworksBuildPhase section */"
)

# 5. Add PBXGroup entries for test folders
groups = f'''
		{UUIDS["tests_group"]} /* ZoeSleepTests */ = {{
			isa = PBXGroup;
			children = (
				{UUIDS["tests_file_utilities"]} /* TestUtilities.swift */,
				{UUIDS["tests_file_questionnaire"]} /* QuestionnaireManagerTests.swift */,
				{UUIDS["tests_file_clinical"]} /* ClinicalScoringTests.swift */,
				{UUIDS["tests_file_auth"]} /* AuthenticationManagerTests.swift */,
				{UUIDS["tests_file_convex"]} /* ConvexServiceTests.swift */,
				{UUIDS["tests_file_healthkit"]} /* HealthKitManagerTests.swift */,
				{UUIDS["tests_file_theme"]} /* ThemeManagerTests.swift */,
				{UUIDS["tests_file_integration"]} /* IntegrationTests.swift */,
				{UUIDS["tests_file_info"]} /* Info.plist */,
			);
			path = ZoeSleepTests;
			sourceTree = "<group>";
		}};
		{UUIDS["uitests_group"]} /* ZoeSleepUITests */ = {{
			isa = PBXGroup;
			children = (
				{UUIDS["uitests_file_main"]} /* ZoeSleepUITests.swift */,
				{UUIDS["uitests_file_info"]} /* Info.plist */,
			);
			path = ZoeSleepUITests;
			sourceTree = "<group>";
		}};
'''

content = content.replace(
    "/* End PBXGroup section */",
    groups + "/* End PBXGroup section */"
)

# 6. Add test groups to main group
# Find and update the main group to include test groups
main_group_pattern = rf'({main_group_uuid} = \{{\s*isa = PBXGroup;\s*children = \()'
main_group_replacement = rf'\1\n\t\t\t\t{UUIDS["tests_group"]} /* ZoeSleepTests */,\n\t\t\t\t{UUIDS["uitests_group"]} /* ZoeSleepUITests */,'
content = re.sub(main_group_pattern, main_group_replacement, content)

# 7. Add products to Products group
if products_group_uuid:
    products_pattern = rf'({products_group_uuid} /\* Products \*/ = \{{\s*isa = PBXGroup;\s*children = \()'
    products_replacement = rf'\1\n\t\t\t\t{UUIDS["tests_product"]} /* ZoeSleepTests.xctest */,\n\t\t\t\t{UUIDS["uitests_product"]} /* ZoeSleepUITests.xctest */,'
    content = re.sub(products_pattern, products_replacement, content)

# 8. Add PBXNativeTarget entries
native_targets = f'''
		{UUIDS["tests_target"]} /* ZoeSleepTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {UUIDS["tests_config_list"]} /* Build configuration list for PBXNativeTarget "ZoeSleepTests" */;
			buildPhases = (
				{UUIDS["tests_sources_phase"]} /* Sources */,
				{UUIDS["tests_frameworks_phase"]} /* Frameworks */,
				{UUIDS["tests_resources_phase"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{UUIDS["tests_dependency"]} /* PBXTargetDependency */,
			);
			name = ZoeSleepTests;
			productName = ZoeSleepTests;
			productReference = {UUIDS["tests_product"]} /* ZoeSleepTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
		{UUIDS["uitests_target"]} /* ZoeSleepUITests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {UUIDS["uitests_config_list"]} /* Build configuration list for PBXNativeTarget "ZoeSleepUITests" */;
			buildPhases = (
				{UUIDS["uitests_sources_phase"]} /* Sources */,
				{UUIDS["uitests_frameworks_phase"]} /* Frameworks */,
				{UUIDS["uitests_resources_phase"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{UUIDS["uitests_dependency"]} /* PBXTargetDependency */,
			);
			name = ZoeSleepUITests;
			productName = ZoeSleepUITests;
			productReference = {UUIDS["uitests_product"]} /* ZoeSleepUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		}};
'''

content = content.replace(
    "/* End PBXNativeTarget section */",
    native_targets + "/* End PBXNativeTarget section */"
)

# 9. Add targets to project
targets_pattern = r'(targets = \(\s*)'
targets_replacement = rf'\1{UUIDS["tests_target"]} /* ZoeSleepTests */,\n\t\t\t\t{UUIDS["uitests_target"]} /* ZoeSleepUITests */,\n\t\t\t\t'
content = re.sub(targets_pattern, targets_replacement, content)

# 10. Add PBXResourcesBuildPhase entries
resources_phases = f'''
		{UUIDS["tests_resources_phase"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{UUIDS["uitests_resources_phase"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
'''

content = content.replace(
    "/* End PBXResourcesBuildPhase section */",
    resources_phases + "/* End PBXResourcesBuildPhase section */"
)

# 11. Add PBXSourcesBuildPhase entries
sources_phases = f'''
		{UUIDS["tests_sources_phase"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{UUIDS["tests_build_utilities"]} /* TestUtilities.swift in Sources */,
				{UUIDS["tests_build_questionnaire"]} /* QuestionnaireManagerTests.swift in Sources */,
				{UUIDS["tests_build_clinical"]} /* ClinicalScoringTests.swift in Sources */,
				{UUIDS["tests_build_auth"]} /* AuthenticationManagerTests.swift in Sources */,
				{UUIDS["tests_build_convex"]} /* ConvexServiceTests.swift in Sources */,
				{UUIDS["tests_build_healthkit"]} /* HealthKitManagerTests.swift in Sources */,
				{UUIDS["tests_build_theme"]} /* ThemeManagerTests.swift in Sources */,
				{UUIDS["tests_build_integration"]} /* IntegrationTests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{UUIDS["uitests_sources_phase"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{UUIDS["uitests_build_main"]} /* ZoeSleepUITests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
'''

content = content.replace(
    "/* End PBXSourcesBuildPhase section */",
    sources_phases + "/* End PBXSourcesBuildPhase section */"
)

# 12. Add PBXTargetDependency entries
target_deps = f'''
/* Begin PBXTargetDependency section */
		{UUIDS["tests_dependency"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {main_target_uuid} /* ZoeSleep */;
			targetProxy = {UUIDS["tests_container_proxy"]} /* PBXContainerItemProxy */;
		}};
		{UUIDS["uitests_dependency"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {main_target_uuid} /* ZoeSleep */;
			targetProxy = {UUIDS["uitests_container_proxy"]} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

'''

# Insert before XCBuildConfiguration section
content = content.replace(
    "/* Begin XCBuildConfiguration section */",
    target_deps + "/* Begin XCBuildConfiguration section */"
)

# 13. Add XCBuildConfiguration entries for test targets
build_configs = f'''
		{UUIDS["tests_debug_config"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = HA7H8BB975;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ZoeSleepTests/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zoesleep.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ZoeSleep.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ZoeSleep";
			}};
			name = Debug;
		}};
		{UUIDS["tests_release_config"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = HA7H8BB975;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ZoeSleepTests/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zoesleep.app.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ZoeSleep.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/ZoeSleep";
			}};
			name = Release;
		}};
		{UUIDS["uitests_debug_config"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = HA7H8BB975;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ZoeSleepUITests/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zoesleep.app.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_TARGET_NAME = ZoeSleep;
			}};
			name = Debug;
		}};
		{UUIDS["uitests_release_config"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = HA7H8BB975;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = ZoeSleepUITests/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.zoesleep.app.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_TARGET_NAME = ZoeSleep;
			}};
			name = Release;
		}};
'''

content = content.replace(
    "/* End XCBuildConfiguration section */",
    build_configs + "/* End XCBuildConfiguration section */"
)

# 14. Add XCConfigurationList entries
config_lists = f'''
		{UUIDS["tests_config_list"]} /* Build configuration list for PBXNativeTarget "ZoeSleepTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{UUIDS["tests_debug_config"]} /* Debug */,
				{UUIDS["tests_release_config"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{UUIDS["uitests_config_list"]} /* Build configuration list for PBXNativeTarget "ZoeSleepUITests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{UUIDS["uitests_debug_config"]} /* Debug */,
				{UUIDS["uitests_release_config"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
'''

content = content.replace(
    "/* End XCConfigurationList section */",
    config_lists + "/* End XCConfigurationList section */"
)

# Write the modified project file
with open(PROJECT_PATH, 'w') as f:
    f.write(content)

print("✅ Successfully added ZoeSleepTests and ZoeSleepUITests targets!")
print("\nNext steps:")
print("1. Close and reopen the project in Xcode")
print("2. Press Cmd+U to run tests")
