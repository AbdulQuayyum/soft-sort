# frozen_string_literal: true

module SoftSort
  class Executor
    def initialize(root, journal: TransactionJournal.new(root))
      @root = File.expand_path(root)
      @journal = journal
    end

    def execute(items, apply: false)
      RootLock.new(@root).synchronize do
        operations = items.map { |item| operation(item) }
        record = @journal.create(@root, operations)
        return record unless apply

        record['status'] = 'in_progress'
        @journal.update(record)
        operations.each do |operation|
          move(operation) if operation['action'] == 'move'
          @journal.update(record)
        end
        record['status'] = operations.any? { |op| op['status'] == 'failed' } ? 'failed' : 'completed'
        @journal.update(record)
      end
    rescue SystemCallError => e
      record['status'] = 'failed' if record
      record['error'] = e.message if record
      @journal.update(record) if record
      raise Error, "organization failed: #{e.message}"
    end

    private

    def operation(item)
      source = File.join(@root, item[:source])
      { 'source' => item[:source], 'destination' => item[:destination], 'action' => item[:action],
        'status' => item[:action] == 'move' ? 'pending' : 'skipped', 'sha256' => file_hash(source), 'size' => File.size(source) }
    end

    def move(op)
      source = File.join(@root, op['source'])
      destination = File.join(@root, op['destination'])
      raise Error, 'source changed before move' unless File.file?(source) && file_hash(source) == op['sha256']
      raise Error, 'destination already exists' if File.exist?(destination)
      raise Error, 'destination escapes selected root' unless destination.start_with?(@root + File::SEPARATOR)

      raise Error, 'source or destination is a symbolic link' if File.symlink?(source) || File.symlink?(destination)

      FileUtils.mkdir_p(File.dirname(destination))
      File.link(source, destination)
      File.unlink(source)
      op['status'] = 'moved'
    rescue StandardError => e
      op['status'] = 'failed'
      op['error'] = e.message
    end

    def file_hash(path)
      return nil unless File.file?(path)

      digest = Digest::SHA256.new
      File.open(path, 'rb') { |file| digest.update(file.read(1024 * 1024)) until file.eof? }
      digest.hexdigest
    end
  end
end
