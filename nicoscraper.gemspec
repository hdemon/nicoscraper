# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{nicoscraper}
  s.version = "0.2.15.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Masami Yonehara}]
  s.date = %q{2011-11-12}
  s.description = %q{It scrape movies and mylists of Niconico douga.
  }
  s.email = %q{zeitdiebe@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "index.html",
    "lib/classes/connector.rb",
    "lib/classes/converter.rb",
    "lib/classes/movie.rb",
    "lib/classes/mylist.rb",
    "lib/classes/parser.rb",
    "lib/classes/searcher.rb",
    "lib/classes/tools.rb",
    "lib/config/header.rb",
    "lib/config/mylist.rb",
    "lib/config/wait.rb",
    "lib/nicoscraper.rb",
    "nicoscraper.gemspec",
    "test/movie_getinfo_spec.rb",
    "test/mylist_gethtmlinfo_spec.rb",
    "test/mylist_spec.rb",
    "test/searcher_spec.rb"
  ]
  s.homepage = %q{http://github.com/hdemon/nicoscraper}
  s.licenses = [%q{MIT}]
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.8}
  s.summary = %q{The scraper for Niconico douga.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<libxml-ruby>, [">= 2.2.2"])
      s.add_development_dependency(%q<rake>, "= 12.3.3")
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
    else
      s.add_dependency(%q<libxml-ruby>, [">= 2.2.2"])
      s.add_dependency(%q<rake>, "= 12.3.3")
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<rcov>, [">= 0"])
    end
  else
    s.add_dependency(%q<libxml-ruby>, [">= 2.2.2"])
    s.add_dependency(%q<rake>, "= 12.3.3")
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<rcov>, [">= 0"])
  end
end

