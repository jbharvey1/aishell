#!/usr/bin/env python3
"""Generate AlfredChat.xcodeproj/project.pbxproj"""
import pathlib

# Fixed UUIDs
PROJ        = "AA000001000000000000001A"
TARGET_APP  = "AA000002000000000000001B"
TARGET_REF  = "AA000012000000000000001B"
GROUP_ROOT  = "AA000003000000000000001C"
GROUP_SRC   = "AA000004000000000000001D"
CFG_LIST_P  = "AA000005000000000000001E"
CFG_LIST_T  = "AA000006000000000000001F"
CFG_DEBUG   = "AA000007000000000000001A"
CFG_RELEASE = "AA000008000000000000001B"
PHASE_SRC   = "AA000009000000000000001C"
PHASE_RES   = "AA000010000000000000001D"
PHASE_FW    = "AA000011000000000000001E"

# Asset catalog UUIDs
ASSETS_REF   = "BB000060000000000000001A"
ASSETS_BUILD = "BB000061000000000000001B"

SOURCES = [
    ("AlfredChatApp.swift", "AA000020000000000000001A", "AA000030000000000000001A"),
    ("ContentView.swift",   "AA000021000000000000001B", "AA000031000000000000001B"),
    ("MCPClient.swift",     "AA000022000000000000001C", "AA000032000000000000001C"),
    ("SettingsView.swift",  "AA000023000000000000001D", "AA000033000000000000001D"),
    ("Models.swift",        "AA000024000000000000001E", "AA000034000000000000001E"),
]
# name, file_uuid, build_uuid

BUNDLE_ID = "com.jbharvey.AlfredChat"
APP_NAME  = "AlfredChat"

NL = "\n"

build_file_lines = NL.join(
    f"\t\t{buid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fuid} /* {name} */; }};"
    for name, fuid, buid in SOURCES
)

file_ref_lines = NL.join(
    f'\t\t{fuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'
    for name, fuid, buid in SOURCES
)

group_children_lines = NL.join(
    f"\t\t\t\t{fuid} /* {name} */,"
    for name, fuid, buid in SOURCES
)

source_build_lines = NL.join(
    f"\t\t\t\t{buid} /* {name} in Sources */,"
    for name, fuid, buid in SOURCES
)

pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_file_lines}
\t\t{ASSETS_BUILD} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS_REF} /* Assets.xcassets */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_ref_lines}
\t\t{ASSETS_REF} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
\t\t{TARGET_REF} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{PHASE_FW} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{GROUP_ROOT} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{GROUP_SRC} /* {APP_NAME} */,
\t\t\t\t{TARGET_REF} /* {APP_NAME}.app */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{GROUP_SRC} /* {APP_NAME} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_lines}
\t\t\t\t{ASSETS_REF} /* Assets.xcassets */,
\t\t\t);
\t\t\tpath = {APP_NAME};
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{TARGET_APP} /* {APP_NAME} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CFG_LIST_T} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */;
\t\t\tbuildPhases = (
\t\t\t\t{PHASE_SRC} /* Sources */,
\t\t\t\t{PHASE_FW} /* Frameworks */,
\t\t\t\t{PHASE_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {APP_NAME};
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = {APP_NAME};
\t\t\tproductReference = {TARGET_REF} /* {APP_NAME}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{PROJ} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{TARGET_APP} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {CFG_LIST_P} /* Build configuration list for PBXProject "{APP_NAME}" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {GROUP_ROOT};
\t\t\tminimumXcodeVersion = 14.0;
\t\t\tproductRefGroup = {GROUP_ROOT};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{TARGET_APP} /* {APP_NAME} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{PHASE_RES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ASSETS_BUILD} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{PHASE_SRC} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{source_build_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{CFG_DEBUG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tINFOPLIST_FILE = "{APP_NAME}/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{CFG_RELEASE} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tINFOPLIST_FILE = "{APP_NAME}/Info.plist";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{CFG_LIST_P} /* Build configuration list for PBXProject "{APP_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{CFG_DEBUG} /* Debug */,
\t\t\t\t{CFG_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{CFG_LIST_T} /* Build configuration list for PBXNativeTarget "{APP_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{CFG_DEBUG} /* Debug */,
\t\t\t\t{CFG_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {PROJ} /* Project object */;
}}
"""

out = pathlib.Path("AlfredChat.xcodeproj")
out.mkdir(exist_ok=True)
(out / "project.pbxproj").write_text(pbxproj)
print("Generated AlfredChat.xcodeproj/project.pbxproj")
