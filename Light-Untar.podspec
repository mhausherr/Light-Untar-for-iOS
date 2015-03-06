#
# Be sure to run `pod spec lint Light-Untar.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# To learn more about the attributes see http://docs.cocoapods.org/specification.html
#
Pod::Spec.new do |s|
  s.name         = "Light-Untar"
  s.version      = "0.3.0"
  s.summary      = "Extract files and directories created with the tar -cf command."
  s.homepage     = "https://github.com/mhausherr/Light-Untar-for-iOS"
  s.license      = 'BSD'
  s.author       = { "Mathieu Hausherr" => "mhausherr@gmail.com" }
  s.source       = { :git => "https://github.com/mhausherr/Light-Untar-for-iOS.git", :tag => "0.3.0" }
  s.platform     = :ios, '5.0'
  s.source_files = 'Light-Untar/*.{h,m}'
  s.requires_arc = true
end
