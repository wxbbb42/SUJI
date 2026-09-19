#!/usr/bin/env python3
"""Reproducible Xcode app, WidgetKit extension, and native test targets."""
import hashlib, json, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(identifier, isa, **fields):
    key = ident(identifier); objects[key] = dict(isa=isa, **fields); return key
def encode(value, depth=0):
    if isinstance(value, dict): return '{\n' + ''.join('\t'*(depth+1)+json.dumps(str(k))+ ' = '+encode(v,depth+1)+';\n' for k,v in value.items()) + '\t'*depth+'}'
    if isinstance(value, list): return '('+', '.join(encode(v,depth) for v in value)+')'
    return json.dumps(str(value), ensure_ascii=False)
def config_list(name, settings):
    configs = [obj(name+'-'+mode,'XCBuildConfiguration',name=mode,buildSettings={**settings, **({'SWIFT_OPTIMIZATION_LEVEL':'-Onone','ENABLE_TESTABILITY':'YES','ONLY_ACTIVE_ARCH':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG'} if mode=='Debug' else {'SWIFT_OPTIMIZATION_LEVEL':'-O','ONLY_ACTIVE_ARCH':'NO'})}) for mode in ['Debug','Release']]
    return obj(name+'-configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
refs=[]; products=[]; targets=[]
package=obj('package','XCLocalSwiftPackageReference',relativePath='Core')
def phase(name, kind, files): return obj(name,kind,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
def target(name, directory, product_type, extension, settings, resources=(), core=True, dependencies=()):
    source_build=[]; resource_build=[]
    for path in sorted((root/directory).rglob('*.swift')):
        relative=str(path.relative_to(root)); ref=obj(relative,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=relative,sourceTree='SOURCE_ROOT')
        refs.append(ref); source_build.append(obj(name+':'+relative,'PBXBuildFile',fileRef=ref))
    for relative,kind in resources:
        if not (root/relative).exists(): continue
        ref=obj(relative,'PBXFileReference',lastKnownFileType=kind,path=relative,sourceTree='SOURCE_ROOT'); refs.append(ref)
        resource_build.append(obj(name+':'+relative,'PBXBuildFile',fileRef=ref))
    product=obj(name+'-product','PBXFileReference',explicitFileType='wrapper.application' if extension=='app' else 'wrapper.app-extension' if extension=='appex' else 'wrapper.cfbundle',path=name+'.'+extension,sourceTree='BUILT_PRODUCTS_DIR'); products.append(product)
    frameworks=[]; package_dependencies=[]
    if core:
        dep=obj(name+'-core','XCSwiftPackageProductDependency',productName='SujiCore'); package_dependencies.append(dep); frameworks.append(obj(name+'-core-build','PBXBuildFile',productRef=dep))
    phases=[phase(name+'-sources','PBXSourcesBuildPhase',source_build),phase(name+'-frameworks','PBXFrameworksBuildPhase',frameworks),phase(name+'-resources','PBXResourcesBuildPhase',resource_build)]
    tid=obj(name+'-target','PBXNativeTarget',buildConfigurationList=config_list(name, {'PRODUCT_NAME':name,'TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','MARKETING_VERSION':'1.0.0','CURRENT_PROJECT_VERSION':'1', 'CODE_SIGN_IDENTITY[sdk=iphonesimulator*]':'-', **settings}),buildPhases=phases,buildRules=[],dependencies=list(dependencies),name=name,packageProductDependencies=package_dependencies,productName=name,productReference=product,productType='com.apple.product-type.'+product_type)
    targets.append(tid); return tid,product
widget,widget_product=target('SujiWidget','Widget','app-extension','appex',{'PRODUCT_BUNDLE_IDENTIFIER':'app.suji.native.widget','INFOPLIST_FILE':'Widget/Info.plist','GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_ENTITLEMENTS':'Widget/Suji.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@executable_path/../../Frameworks']},core=False)
widget_dependency=obj('widget-dependency','PBXTargetDependency',target=widget)
app,app_product=target('Suji','App','application','app',{'PRODUCT_BUNDLE_IDENTIFIER':'app.suji.native','INFOPLIST_FILE':'App/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'App/Suji.entitlements','CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]':'App/Simulator.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','SWIFT_EMIT_LOC_STRINGS':'YES','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks']},resources=[('Resources/mingli.js','sourcecode.javascript'),('Resources/ThirdPartyNotices.txt','text'),('Resources/Assets.xcassets','folder.assetcatalog'),('Resources/PublicConfig.plist','text.plist.xml'),('Resources/Fonts/NotoSerifSC.ttf','file'),('Resources/Fonts/OFL.txt','text')],dependencies=[widget_dependency])
embed_build=obj('embed-widget-build','PBXBuildFile',fileRef=widget_product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
embed=obj('embed-widget','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[embed_build],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
objects[app]['buildPhases'].append(embed)
app_dependency=obj('app-dependency','PBXTargetDependency',target=app)
uitest,_=target('SujiUITests','UITests','bundle.ui-testing','xctest',{'PRODUCT_BUNDLE_IDENTIFIER':'app.suji.native.uitests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'Suji'},core=False,dependencies=[app_dependency])
apptest,_=target('SujiTests','AppTests','bundle.unit-test','xctest',{'PRODUCT_BUNDLE_IDENTIFIER':'app.suji.native.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Suji.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Suji','BUNDLE_LOADER':'$(TEST_HOST)'},dependencies=[app_dependency])
product_group=obj('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
main=obj('main','PBXGroup',children=refs+[product_group],sourceTree='<group>')
project=obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2660'},buildConfigurationList=config_list('project',{'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'18.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','DEBUG_INFORMATION_FORMAT':'dwarf'}),compatibilityVersion='Xcode 15.0',developmentRegion='zh-Hans',hasScannedForEncodings=0,knownRegions=['zh-Hans','en','Base'],mainGroup=main,packageReferences=[package],productRefGroup=product_group,projectDirPath='',projectRoot='',targets=targets)
project_dir=root/'Suji.xcodeproj'; project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(dict(archiveVersion=1,classes={},objectVersion=60,objects=objects,rootObject=project))+'\n')
scheme=project_dir/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
def reference(tid,name,extension): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tid}" BuildableName="{name}.{extension}" BlueprintName="{name}" ReferencedContainer="container:Suji.xcodeproj"/>'
ref=reference(app,'Suji','app')
tests=''.join(f'<TestableReference skipped="NO">{reference(t,n,"xctest")}</TestableReference>' for t,n in [(apptest,'SujiTests'),(uitest,'SujiUITests')])
(scheme/'Suji.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{tests}</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(f'Generated {project_dir}: app, widget, app tests and UI tests.')
