# Generates an isolated iOS XCTest host or a standalone SwiftPM staging package.
# Usage: ruby tool/native_tests.rb FLUTTER_SDK SIMULATOR_UDID cocoapods|swiftpm
require 'fileutils'
require 'tmpdir'

root = File.expand_path('..', __dir__)
sdk, simulator, mode = ARGV
abort 'Usage: ruby tool/native_tests.rb FLUTTER_SDK SIMULATOR_UDID cocoapods|swiftpm' unless
  sdk && simulator && %w[cocoapods swiftpm].include?(mode)
sdk = File.expand_path(sdk)
framework = File.join(sdk, 'bin/cache/artifacts/engine/ios/Flutter.xcframework')
abort 'Run this SDK\'s flutter precache --ios first' unless File.directory?(framework)
FileUtils.mkdir_p(File.join(root, 'build'))
work = Dir.mktmpdir("native-#{mode}-", File.join(root, 'build'))
puts "Generated test artifacts: #{work}"
def run!(*args)
  abort "Failed: #{args.join(' ')}" unless system(*args)
end

if mode == 'swiftpm'
  # Stage an exact copy, so ../FlutterFramework resolves without changing sources.
  FileUtils.cp_r(File.join(root, 'ios/split_screen'), File.join(work, 'split_screen'))
  flutter = File.join(work, 'FlutterFramework')
  FileUtils.mkdir_p(flutter)
  FileUtils.ln_s(framework, File.join(flutter, 'Flutter.xcframework'))
  File.write(File.join(flutter, 'Package.swift'), <<~SWIFT)
    // swift-tools-version: 5.9
    import PackageDescription
    let package = Package(name: "FlutterFramework", platforms: [.iOS("15.0")],
      products: [.library(name: "FlutterFramework", targets: ["FlutterFramework"])],
      targets: [.target(name: "FlutterFramework", dependencies: ["Flutter"]),
                .binaryTarget(name: "Flutter", path: "Flutter.xcframework")])
  SWIFT
  FileUtils.mkdir_p(File.join(flutter, 'Sources/FlutterFramework'))
  File.write(File.join(flutter, 'Sources/FlutterFramework/FlutterFramework.swift'), "@_exported import Flutter\n")
  Dir.chdir(File.join(work, 'split_screen')) do
    run!('xcodebuild', '-scheme', 'split-screen', '-destination', "id=#{simulator}",
         '-resultBundlePath', File.join(work, 'SwiftPM.xcresult'), 'test', 'CODE_SIGNING_ALLOWED=NO')
  end
else
  require 'xcodeproj' # Bundled with CocoaPods.
  flutter = File.join(work, 'Flutter')
  FileUtils.mkdir_p(flutter)
  FileUtils.ln_s(framework, File.join(flutter, 'Flutter.xcframework'))
  File.write(File.join(flutter, 'Flutter.podspec'), <<~RUBY)
    Pod::Spec.new do |s|
      s.name = 'Flutter'
      s.version = '1.0.0'
      s.summary = 'Local Flutter engine for native plugin fixtures.'
      s.homepage = 'https://flutter.dev'
      s.license = { :type => 'BSD' }
      s.author = 'Flutter Authors'
      s.source = { :path => '.' }
      s.platform = :ios, '15.0'
      s.vendored_frameworks = 'Flutter.xcframework'
    end
  RUBY
  File.write(File.join(work, 'TestHost.swift'), <<~SWIFT)
    import UIKit
    @main class TestHost: UIResponder, UIApplicationDelegate {}
    class TestSceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?
      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
      }
    }
  SWIFT
  Xcodeproj::Plist.write_to_path({
    'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleExecutable' => '$(EXECUTABLE_NAME)',
    'CFBundleName' => 'TestHost', 'CFBundlePackageType' => 'APPL',
    'CFBundleVersion' => '1', 'CFBundleShortVersionString' => '1.0',
    'UILaunchScreen' => {},
    'UIApplicationSceneManifest' => {
      'UIApplicationSupportsMultipleScenes' => false,
      'UISceneConfigurations' => {'UIWindowSceneSessionRoleApplication' => [{
        'UISceneClassName' => 'UIWindowScene', 'UISceneConfigurationName' => 'Tests',
        'UISceneDelegateClassName' => '$(PRODUCT_MODULE_NAME).TestSceneDelegate'
      }]}
    }
  }, File.join(work, 'Info.plist'))
  project = Xcodeproj::Project.new(File.join(work, 'NativeTests.xcodeproj'))
  app = project.new_target(:application, 'TestHost', :ios, '15.0')
  app.add_file_references([project.main_group.new_file('TestHost.swift')])
  tests = project.new_target(:unit_test_bundle, 'SplitScreenTests', :ios, '15.0')
  tests.add_dependency(app)
  sources = Dir[File.join(root, 'ios/split_screen/Tests/split_screenTests/*.swift')]
  tests.add_file_references(sources.map { |source| project.main_group.new_file(source) })
  [app, tests].each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "dev.split-screen.#{target.name}"
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['ENABLE_TESTABILITY'] = 'YES'
    end
  end
  app.build_configurations.each { |c| c.build_settings['INFOPLIST_FILE'] = 'Info.plist' }
  tests.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/TestHost.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TestHost'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  end
  project.save
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(app)
  scheme.add_build_target(tests)
  scheme.add_test_target(tests)
  scheme.set_launch_target(app)
  scheme.save_as(project.path, 'NativeTests', true)
  File.write(File.join(work, 'Podfile'), <<~RUBY)
    platform :ios, '15.0'
    project 'NativeTests.xcodeproj'
    use_frameworks!
    target 'TestHost' do
      pod 'Flutter', :path => #{flutter.dump}
      pod 'split_screen', :path => #{File.join(root, 'ios').dump}
      target 'SplitScreenTests' do
        inherit! :complete
      end
    end
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each { |c| c.build_settings['ENABLE_TESTABILITY'] = 'YES' }
      end
    end
  RUBY
  Dir.chdir(work) do
    run!('pod', 'install')
    run!('xcodebuild', '-workspace', 'NativeTests.xcworkspace', '-scheme', 'NativeTests',
         '-destination', "id=#{simulator}", '-resultBundlePath', File.join(work, 'CocoaPods.xcresult'),
         'test', 'CODE_SIGNING_ALLOWED=NO')
  end
end
