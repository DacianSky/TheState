Pod::Spec.new do |s|
  s.name                = "TheState"
  s.version             = "0.1.0"
  s.summary             = "iOS状态管理"
  s.homepage            = "https://github.com/DacianSky/TheState"
  s.license             = { :type => "MIT", :file => "LICENSE" }
  s.author              = { "TheMe" => "sdqvsqiu@gmail.com" }
  s.platform            = :ios, "8.0"
  s.source              = { :git => "https://github.com/DacianSky/TheState.git", :tag => "#{s.version}" }
  s.source_files        = "TheState", "TheState/**/*.{h,m}"
  s.public_header_files = "TheState/**/*.h"
  s.frameworks          = "Foundation"
  s.requires_arc        = true
end
