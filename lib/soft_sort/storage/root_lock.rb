# frozen_string_literal: true

module SoftSort
  class RootLock
    def initialize(root)
      @path = File.join(File.expand_path(root), '.soft-sort', 'root.lock')
    end

    def synchronize
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock&.flock(File::LOCK_UN)
      end
    rescue SystemCallError => e
      raise Error, "unable to lock selected root: #{e.message}"
    end
  end
end
