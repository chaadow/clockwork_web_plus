require_relative "lib/clockwork_web_plus/version"

Gem::Specification.new do |spec|
  spec.name          = "clockwork_web_plus"
  spec.version       = ClockworkWebPlus::VERSION
  spec.summary       = "A modern web interface for Clockwork with search, run-now & health checks"
  spec.homepage      = "https://github.com/chedli/clockwork_web_plus"
  spec.license       = "MIT"

  spec.authors       = ["Andrew Kane", "Chedli Bourguiba"]
  spec.email         = ["bourguiba.chedli@gmail.com"]

  spec.files         = Dir["*.{md,txt}", "{app,config,lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "clockwork", ">= 3"
  spec.add_dependency "safely_block", ">= 0.4"
  spec.add_dependency "railties", ">= 6.1"
end
