# Runner regression only: the fake xcodebuild models the scheme names reported
# by Xcode for this package. This does not compile Swift or run native fixtures.
require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class NativeTestRunnerTests < Minitest::Test
  def test_swiftpm_reaches_test_action_using_the_package_scheme
    Dir.mktmpdir('native runner ') do |temporary|
      sdk = File.join(temporary, 'Flutter SDK')
      framework = File.join(sdk, 'bin/cache/artifacts/engine/ios/Flutter.xcframework')
      FileUtils.mkdir_p(framework)
      bin = File.join(temporary, 'bin')
      FileUtils.mkdir_p(bin)
      invocation = File.join(temporary, 'invocation.json')
      xcodebuild = File.join(bin, 'xcodebuild')
      File.write(xcodebuild, <<~RUBY)
        #!#{RbConfig.ruby}
        require 'json'
        # `xcodebuild -list -json` reports split_screen, not split-screen.
        unless ARGV[ARGV.index('-scheme').to_i + 1] == 'split_screen'
          abort 'The workspace does not contain the requested scheme'
        end
        File.write(ENV.fetch('NATIVE_RUNNER_INVOCATION'), JSON.generate(ARGV))
      RUBY
      FileUtils.chmod(0755, xcodebuild)
      root = File.expand_path('..', __dir__)
      output, status = Open3.capture2e(
        { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'NATIVE_RUNNER_INVOCATION' => invocation },
        RbConfig.ruby, File.join(__dir__, 'native_tests.rb'), sdk, 'fixture-simulator', 'swiftpm'
      )
      assert status.success?, output
      args = JSON.parse(File.read(invocation))
      assert_includes args, 'test'
      assert_equal 'id=fixture-simulator', args[args.index('-destination') + 1]
      staging = output.lines.find { |line| line.start_with?('Generated test artifacts: ') }
                      .delete_prefix('Generated test artifacts: ').strip
      assert staging.start_with?(File.join(root, 'build', 'native-swiftpm-'))
      assert_equal File.join(staging, 'SwiftPM.xcresult'), args[args.index('-resultBundlePath') + 1]
      assert_equal framework, File.readlink(File.join(staging, 'FlutterFramework/Flutter.xcframework'))
      # The staging package must test the checked-in sources without patching APIs.
      source = 'Sources/split_screen/Providers.swift'
      assert_equal File.read(File.join(root, 'ios/split_screen', source)),
                   File.read(File.join(staging, 'split_screen', source))
    ensure
      if staging && staging.start_with?(File.join(root, 'build', 'native-swiftpm-')) && File.directory?(staging)
        FileUtils.remove_entry(staging)
      end
    end
  end
end
