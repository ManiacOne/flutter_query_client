#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_query_client.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_query_client'
  s.version          = '0.0.1'
  s.summary          = 'Native connectivity detection for flutter_query_client.'
  s.description      = <<-DESC
Native iOS implementation reporting real internet connectivity via NWPathMonitor.
                       DESC
  s.homepage         = 'https://github.com/ManiacOne/flutter_query_client'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ManiacOne' => 'deepraj@norskhub.no' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
