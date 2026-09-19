#!/usr/bin/env python3
"""Generate a deterministic, dependency-free Xcode project and required plists."""
import hashlib
import json
import os
import pathlib
import plistlib
import struct
import zlib
import math

ROOT = pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
objects = {}

def uid(label):
    return hashlib.sha1(label.encode()).hexdigest()[:24].upper()

def obj(label, **fields):
    key = uid(label)
    objects[key] = fields
    return key

def emit(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t'*(depth+1) + json.dumps(str(k)) + ' = ' + emit(v, depth+1) + ';\n' for k, v in value.items()) + '\t'*depth + '}'
    if isinstance(value, list):
        return '(' + ', '.join(emit(v, depth) for v in value) + ')'
    return json.dumps(str(value), ensure_ascii=False)

def write_plist(path, value):
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'wb') as handle:
        plistlib.dump(value, handle, fmt=plistlib.FMT_XML, sort_keys=True)

common_info = {
    'CFBundleDevelopmentRegion': 'zh_CN', 'CFBundleExecutable': '$(EXECUTABLE_NAME)',
    'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': '$(PRODUCT_NAME)', 'CFBundleShortVersionString': '1.2.0',
    'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True,
}
write_plist('Resources/App-Info.plist', dict(common_info, **{
    'CFBundleDisplayName': 'MyResearch', 'CFBundlePackageType': 'APPL',
    'UILaunchScreen': {}, 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False},
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'CFBundleURLTypes': [{'CFBundleURLName': 'com.dandibbert.MyResearch', 'CFBundleURLSchemes': ['myresearch']}],
}))
write_plist('Resources/Share-Info.plist', dict(common_info, **{
    'CFBundleDisplayName': 'MyResearch', 'CFBundlePackageType': 'XPC!',
    'NSExtension': {
        'NSExtensionPointIdentifier': 'com.apple.share-services',
        'NSExtensionPrincipalClass': '$(PRODUCT_MODULE_NAME).ShareViewController',
        'NSExtensionAttributes': {'NSExtensionJavaScriptPreprocessingFile': 'Selection', 'NSExtensionActivationRule': {
            'NSExtensionActivationSupportsText': True, 'NSExtensionActivationSupportsWebURLWithMaxCount': 10,
            'NSExtensionActivationSupportsWebPageWithMaxCount': 1,
        }},
    },
}))
# Both targets need the same first access group after signing, with the real prefix.
write_plist('Resources/Shared.entitlements', {
    'keychain-access-groups': ['$(AppIdentifierPrefix)com.dandibbert.MyResearch.shared'],
})
write_plist('Resources/Probe-Info.plist', dict(common_info, **{
    'CFBundleDisplayName': 'Share Probe', 'CFBundlePackageType': 'APPL', 'UILaunchScreen': {},
    'CFBundleURLTypes': [{'CFBundleURLName': 'share-probe', 'CFBundleURLSchemes': ['myresearch-probe']}],
}))
write_plist('Resources/PrivacyInfo.xcprivacy', {
    'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [], 'NSPrivacyCollectedDataTypes': [],
    'NSPrivacyAccessedAPITypes': [{'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults', 'NSPrivacyAccessedAPITypeReasons': ['CA92.1']}],
})

# Original artwork, rasterized offline with the Python standard library.
def icon():
    size = 1024
    scanlines = bytearray()
    segments = [(552, 584, 729, 760, 31), (347, 486, 474, 359, 19),
                (356, 359, 474, 359, 19), (474, 359, 474, 478, 19)]
    for y in range(size):
        scanlines.append(0)
        for x in range(size):
            blend = (x + y) / (2 * size)
            base = (round(99 - 40*blend), round(121 - 51*blend), round(236 - 31*blend))
            ring = abs(math.hypot(x-413, y-432) - 190)
            alpha = max(0.0, min(1.0, 26.5-ring))
            for ax, ay, bx, by, radius in segments:
                t = max(0, min(1, ((x-ax)*(bx-ax)+(y-ay)*(by-ay))/((bx-ax)**2+(by-ay)**2)))
                distance = math.hypot(x-(ax+t*(bx-ax)), y-(ay+t*(by-ay)))
                alpha = max(alpha, max(0.0, min(1.0, radius+0.5-distance)))
            scanlines.extend(round(c+(255-c)*alpha) for c in base)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(scanlines, 9)) + chunk(b'IEND', b'')
    path = pathlib.Path('Resources/Assets.xcassets/AppIcon.appiconset')
    path.mkdir(parents=True, exist_ok=True)
    (path/'AppIcon.png').write_bytes(png)
    (path/'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
    (path.parent/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')

icon()
core = sorted(str(p) for p in pathlib.Path('Core').glob('*.swift'))
app = sorted(str(p) for p in pathlib.Path('App').glob('*.swift'))
share = sorted(str(p) for p in pathlib.Path('Share').glob('*.swift'))
shared = sorted(str(p) for p in pathlib.Path('Shared').glob('*.swift'))
probe = sorted(str(p) for p in pathlib.Path('ShareProbe').glob('*.swift'))
tests = sorted(str(p) for p in pathlib.Path('UITests').glob('*.swift'))
resources = ['Resources/Assets.xcassets', 'Resources/PrivacyInfo.xcprivacy']
all_paths = sorted(set(core+app+share+shared+probe+tests+resources+["Share/Selection.js"]))
refs = {}
for path in all_paths:
    kind = 'sourcecode.swift' if path.endswith('.swift') else ('folder.assetcatalog' if path.endswith('.xcassets') else ('sourcecode.javascript' if path.endswith('.js') else 'text.xml'))
    refs[path] = obj('file:'+path, isa='PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')
products = {
    'MyResearchShareProbe': obj('product:probe', isa='PBXFileReference', explicitFileType='wrapper.application', path='MyResearchShareProbe.app', sourceTree='BUILT_PRODUCTS_DIR'),
    'MyResearch': obj('product:app', isa='PBXFileReference', explicitFileType='wrapper.application', path='MyResearch.app', sourceTree='BUILT_PRODUCTS_DIR'),
    'MyResearchShare': obj('product:share', isa='PBXFileReference', explicitFileType='wrapper.app-extension', path='MyResearchShare.appex', sourceTree='BUILT_PRODUCTS_DIR'),
    'MyResearchUITests': obj('product:tests', isa='PBXFileReference', explicitFileType='wrapper.cfbundle', path='MyResearchUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR'),
}
groups = []
for name, paths in [('App',app),('Core',core),('Share',share+['Share/Selection.js']),('Shared',shared),('ShareProbe',probe),('UITests',tests),('Resources',resources)]:
    groups.append(obj('group:'+name, isa='PBXGroup', children=[refs[p] for p in paths], name=name, sourceTree='<group>'))
groups.append(obj('group:products', isa='PBXGroup', children=list(products.values()), name='Products', sourceTree='<group>'))
main_group = obj('group:root', isa='PBXGroup', children=groups, sourceTree='<group>')
common_settings = {
    'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SWIFT_VERSION': '5.0',
    'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'SWIFT_STRICT_CONCURRENCY': 'minimal',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'TARGETED_DEVICE_FAMILY': '1,2', 'CODE_SIGN_STYLE': 'Automatic',
    'MARKETING_VERSION': '1.2.0', 'CURRENT_PROJECT_VERSION': os.environ.get('GITHUB_RUN_NUMBER','1'),
    'PRODUCT_NAME': '$(TARGET_NAME)', 'SWIFT_EMIT_LOC_STRINGS': 'NO',
}

def configurations(name, extra):
    values = []
    for mode in ['Debug','Release']:
        settings = dict(common_settings, **extra)
        settings.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode=='Debug' else '-O',
                         'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode=='Debug' else 'dwarf-with-dsym'})
        if mode=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        values.append(obj('config:'+name+mode, isa='XCBuildConfiguration', buildSettings=settings, name=mode))
    return obj('configlist:'+name, isa='XCConfigurationList', buildConfigurations=values, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')

def phase(name, kind, paths):
    files=[]
    for path in paths:
        files.append(obj('buildfile:'+name+path, isa='PBXBuildFile', fileRef=refs[path]))
    return obj('phase:'+name, isa=kind, buildActionMask='2147483647', files=files, runOnlyForDeploymentPostprocessing='0')

def dependency(name, target):
    proxy=obj('proxy:'+name, isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType='1', remoteGlobalIDString=uid('target:'+target), remoteInfo=target)
    return obj('dependency:'+name, isa='PBXTargetDependency', target=uid('target:'+target), targetProxy=proxy)

for name, sources, res, kind, settings in [
    ('MyResearch', core+app+shared, resources, 'com.apple.product-type.application', {'PRODUCT_BUNDLE_IDENTIFIER':'com.dandibbert.MyResearch','CODE_SIGN_ENTITLEMENTS':'Resources/Shared.entitlements','INFOPLIST_FILE':'Resources/App-Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks']}),
    ('MyResearchShare', core+share+shared+['App/Visuals.swift','App/SearchField.swift','App/Suggestions.swift'], ['Resources/PrivacyInfo.xcprivacy','Share/Selection.js'], 'com.apple.product-type.app-extension', {'PRODUCT_BUNDLE_IDENTIFIER':'com.dandibbert.MyResearch.Share','CODE_SIGN_ENTITLEMENTS':'Resources/Shared.entitlements','INFOPLIST_FILE':'Resources/Share-Info.plist','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@executable_path/../../Frameworks']}),
    ('MyResearchShareProbe', probe, [], 'com.apple.product-type.application', {'PRODUCT_BUNDLE_IDENTIFIER':'com.dandibbert.MyResearch.ShareProbe','INFOPLIST_FILE':'Resources/Probe-Info.plist'}),
    ('MyResearchUITests', tests, [], 'com.apple.product-type.bundle.ui-testing', {'PRODUCT_BUNDLE_IDENTIFIER':'com.dandibbert.MyResearch.UITests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'MyResearch'}),
]:
    phases=[phase(name+':sources','PBXSourcesBuildPhase',sources),phase(name+':frameworks','PBXFrameworksBuildPhase',[]),phase(name+':resources','PBXResourcesBuildPhase',res)]
    dependencies=[]
    if name=='MyResearch':
        embed=obj('embed:share', isa='PBXBuildFile', fileRef=products['MyResearchShare'], settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
        phases.append(obj('phase:embed', isa='PBXCopyFilesBuildPhase', buildActionMask='2147483647', dstPath='', dstSubfolderSpec='13', files=[embed], name='Embed App Extensions', runOnlyForDeploymentPostprocessing='0'))
        dependencies=[dependency('app-share','MyResearchShare')]
    elif name=='MyResearchUITests': dependencies=[dependency('tests-app','MyResearch'), dependency('tests-probe','MyResearchShareProbe')]
    obj('target:'+name, isa='PBXNativeTarget', buildConfigurationList=configurations(name,settings), buildPhases=phases, buildRules=[], dependencies=dependencies, name=name, productName=name, productReference=products[name], productType=kind)

obj('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1640','TargetAttributes':{uid('target:MyResearchUITests'):{'TestTargetID':uid('target:MyResearch')}}}, buildConfigurationList=configurations('project',{}), compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans', hasScannedForEncodings='0', knownRegions=['zh-Hans','en','Base'], mainGroup=main_group, productRefGroup=uid('group:products'), projectDirPath='', projectRoot='', targets=[uid('target:'+n) for n in products])
project=pathlib.Path('MyResearch.xcodeproj')
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+emit({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':uid('project')})+'\n')

def build_ref(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{"app" if name in ["MyResearch", "MyResearchShareProbe"] else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:MyResearch.xcodeproj"/>'
app_ref=build_ref('MyResearch'); test_ref=build_ref('MyResearchUITests'); probe_ref=build_ref('MyResearchShareProbe')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{probe_ref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir=project/'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True,exist_ok=True)
(scheme_dir/'MyResearch.xcscheme').write_text(scheme)
print(f'Generated MyResearch.xcodeproj: {len(app)} app, {len(core)} core, {len(share)} extension and {len(tests)} UI test sources.')
