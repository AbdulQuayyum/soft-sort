# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'tmpdir'
require 'rubygems'

gem_path = ARGV.fetch(0)
install_dir = Dir.mktmpdir('soft-sort-installed')
begin
  install = system(Gem.ruby, '-S', 'gem', 'install', '--local', gem_path,
                   '--install-dir', install_dir, '--no-document', out: File::NULL)
  abort 'gem installation failed' unless install
  env = { 'GEM_HOME' => install_dir, 'GEM_PATH' => install_dir,
          'PATH' => "#{File.join(install_dir, 'bin')}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}" }
  Dir.mktmpdir('soft-sort-installed-fixture') do |fixture|
    File.write(File.join(fixture, 'smoke.txt'), 'smoke')
    abort 'installed version command failed' unless system(env, RbConfig.ruby, '-S', 'soft-sort', 'version')
    abort 'installed help command failed' unless system(env, RbConfig.ruby, '-S', 'soft-sort', '--help', out: File::NULL)
    abort 'installed plan command failed' unless system(env, RbConfig.ruby, '-S', 'soft-sort', 'plan', fixture, out: File::NULL)
  end
ensure
  FileUtils.rm_rf(install_dir)
end
