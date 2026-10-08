#!/usr/bin/env python3
"""Generate a dependency-free macOS Xcode project from checked-in Swift sources."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
project = root / "TopMovies.xcodeproj"
project.mkdir(exist_ok=True)
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_name, **value):
    key = uid(object_name); objects[key] = value; return key
sources = sorted((root / "TopMovies").rglob("*.swift"))
resources = [root / "TopMovies/Resources/TMDB.png", root / "TopMovies/Resources/AppIcon.icns"]
refs, source_builds, resource_builds = [], [], []
for file in sources + resources:
    path = str(file.relative_to(root))
    ref = add(path, isa="PBXFileReference", lastKnownFileType="sourcecode.swift" if file.suffix == ".swift" else ("image.icns" if file.suffix == ".icns" else "image.png"), path=path, sourceTree="<group>")
    refs.append(ref)
    build = add("build:" + path, isa="PBXBuildFile", fileRef=ref)
    (source_builds if file.suffix == ".swift" else resource_builds).append(build)
product = add("product", isa="PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0, path="TopMovies.app", sourceTree="BUILT_PRODUCTS_DIR")
products = add("products", isa="PBXGroup", children=[product], name="Products", sourceTree="<group>")
main = add("main", isa="PBXGroup", children=refs + [products], sourceTree="<group>")
sp = add("sources", isa="PBXSourcesBuildPhase", buildActionMask=2147483647, files=source_builds, runOnlyForDeploymentPostprocessing=0)
rp = add("resources", isa="PBXResourcesBuildPhase", buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)
fp = add("frameworks", isa="PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
common = {"MACOSX_DEPLOYMENT_TARGET":"14.0", "SDKROOT":"macosx", "SWIFT_VERSION":"6.0", "CLANG_ENABLE_MODULES":"YES", "ENABLE_USER_SCRIPT_SANDBOXING":"YES"}
app = {"PRODUCT_NAME":"TopMovies", "PRODUCT_BUNDLE_IDENTIFIER":"com.topmovies.mac", "GENERATE_INFOPLIST_FILE":"YES", "INFOPLIST_KEY_LSApplicationCategoryType":"public.app-category.entertainment", "INFOPLIST_KEY_CFBundleDisplayName":"TopMovies", "INFOPLIST_KEY_CFBundleIconFile":"AppIcon", "INFOPLIST_KEY_NSHumanReadableCopyright":"Copyright © 2026 TopMovies contributors", "MARKETING_VERSION":"0.1.0", "CURRENT_PROJECT_VERSION":"1", "CODE_SIGN_STYLE":"Automatic", "ENABLE_APP_SANDBOX":"YES", "CODE_SIGN_ENTITLEMENTS":"TopMovies/Resources/TopMovies.entitlements", "COMBINE_HIDPI_IMAGES":"YES", "SWIFT_EMIT_LOC_STRINGS":"YES", "INFOPLIST_KEY_CFBundleDevelopmentRegion":"en"}
def configs(name, settings):
    values=[]
    for mode in ["Debug", "Release"]:
        value=settings.copy(); value["SWIFT_OPTIMIZATION_LEVEL"]="-Onone" if mode=="Debug" else "-O"
        if mode=="Debug": value["DEBUG_INFORMATION_FORMAT"]="dwarf"; value["SWIFT_ACTIVE_COMPILATION_CONDITIONS"]="DEBUG"
        values.append(add(name+mode, isa="XCBuildConfiguration", buildSettings=value, name=mode))
    return add(name+"configs", isa="XCConfigurationList", buildConfigurations=values, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
pc=configs("project",common); tc=configs("target",app)
target=add("target", isa="PBXNativeTarget", buildConfigurationList=tc, buildPhases=[sp,fp,rp], buildRules=[], dependencies=[], name="TopMovies", productName="TopMovies", productReference=product, productType="com.apple.product-type.application")
pid=add("project", isa="PBXProject", attributes={"LastUpgradeCheck":"2620", "TargetAttributes": {target: {"CreatedOnToolsVersion":"26.2"}}}, buildConfigurationList=pc, compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en","Base"], mainGroup=main, productRefGroup=products, projectDirPath="", projectRoot="", targets=[target])
def serialize(v):
    if isinstance(v,dict): return "{ " + " ".join(json.dumps(k)+" = "+serialize(val)+";" for k,val in v.items()) + " }"
    if isinstance(v,list): return "( " + ", ".join(serialize(x) for x in v) + ", )" if v else "()"
    if isinstance(v,int): return str(v)
    return json.dumps(v)
(project/"project.pbxproj").write_text("// !$*UTF8*$!\n"+serialize({"archiveVersion":1,"classes":{},"objectVersion":56,"objects":objects,"rootObject":pid})+"\n")
schemes=project/"xcshareddata/xcschemes"; schemes.mkdir(parents=True,exist_ok=True)
(schemes/"TopMovies.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2620" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="TopMovies.app" BlueprintName="TopMovies" ReferencedContainer="container:TopMovies.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="TopMovies.app" BlueprintName="TopMovies" ReferencedContainer="container:TopMovies.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f"Generated {project} ({len(sources)} Swift files)")
