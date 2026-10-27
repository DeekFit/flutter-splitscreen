Pod::Spec.new do |s|
  s.name = 'split_screen'
  s.version = '2.0.0-dev.1'
  s.summary = 'Hinge readings and fold-aware Flutter layouts.'
  s.description = 'Android and iOS foldable support with view-scoped Duo observation.'
  s.homepage = 'https://github.com/DeekFit/flutter-splitscreen'
  s.license = { :file => '../LICENSE' }
  s.author = { 'Split Screen contributors' => 'https://github.com/DeekFit/flutter-splitscreen' }
  s.source = { :path => '.' }
  s.source_files = 'split_screen/Sources/split_screen/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.test_spec 'ProviderTests' do |test|
    test.source_files = 'split_screen/Tests/split_screenTests/**/*.swift'
    test.requires_app_host = true
  end
end
