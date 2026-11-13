$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "soft_sort"
require "tmpdir"
require "fileutils"
RSpec.configure { |c| c.example_status_persistence_file_path = ".rspec_status" }
