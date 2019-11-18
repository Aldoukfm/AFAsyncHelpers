Pod::Spec.new do |spec|

  spec.name         = "AFAsyncHelpers"
  spec.version      = "0.0.1"
  spec.summary      = "Async helper classes."

  spec.homepage     = "https://github.com/Aldoukfm/AFAsyncHelpers"
  
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "Aldo Fuentes" => "aldo.k.fuentes@gmail.com" }

  spec.platform     = :ios, "13.0"

  spec.source       = { :git => "https://github.com/Aldoukfm/AFAsyncHelpers.git", :tag => "#{spec.version}" }

  spec.source_files  = "AFAsyncHelpers/**/*.{h,m}"
  
  # s.dependency "JSONKit", "~> 1.4"
  # s.resources = "RWPickFlavor/**/*.{png,jpeg,jpg,storyboard,xib,xcassets}"

  s.swift_version = "5"

end
