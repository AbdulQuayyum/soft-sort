# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'soft-sort'
  s.version = '0.1.0'
  s.summary = 'A safe, local-first file organization planner'
  s.authors = ['SoftSort contributors']
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.2'
  s.files = Dir['lib/**/*', 'bin/*', 'config/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  s.bindir = 'bin'
  s.executables = ['soft-sort']
  s.require_paths = ['lib']
  s.metadata['rubygems_mfa_required'] = 'true'
end
