Gem::Specification.new do |s|
  s.name        = 'bing_translator'
  s.version     = '0.1.0'
  s.date        = '2013-07-20'
  s.homepage    = 'https://www.github.com/shuhong/bing_translator'
  s.summary     = "Translate using the Bing HTTP API"
  s.description = "Translate strings using the Bing HTTP API. Requires that you have a Client ID and Secret. See README.md for information."
  s.authors     = ["Ricky Elrod", "Shuhong"]
  s.email       = 'shuhong@roomorama.com'
  s.files       = ["lib/bing_translator.rb"]
  s.add_dependency "nokogiri", "~> 1.5.4"
  s.add_dependency "json", "~> 1.7.7"
end
