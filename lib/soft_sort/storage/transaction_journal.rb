# frozen_string_literal: true

module SoftSort
  class TransactionJournal
    def initialize(root)
      @directory = File.join(File.expand_path(root), '.soft-sort')
      @path = File.join(@directory, 'transactions.jsonl')
      @warnings = []
    end

    attr_reader :warnings

    def create(root, operations)
      record = { 'id' => SecureRandom.uuid, 'root' => File.expand_path(root), 'started_at' => Time.now.utc.iso8601,
                 'completed_at' => nil, 'status' => 'planned', 'operations' => operations }
      append(record)
      record
    end

    def update(record)
      record['completed_at'] = Time.now.utc.iso8601 if %w[completed failed undone partially_undone].include?(record['status'])
      append(record)
      record
    end

    def all
      return [] unless File.file?(@path)

      records = {}
      File.foreach(@path).with_index(1) do |line, line_number|
        begin
          record = JSON.parse(line)
          records[record['id']] = record
        rescue JSON::ParserError => e
          @warnings << "line #{line_number}: malformed journal record (#{e.message})"
        end
      end
      records.values
    end

    private

    def append(record)
      FileUtils.mkdir_p(@directory)
      File.open(@path, File::WRONLY | File::APPEND | File::CREAT, 0o600) do |file|
        file.flock(File::LOCK_EX)
        file.write(JSON.generate(record))
        file.write("\n")
        file.flush
        file.fsync
      ensure
        file&.flock(File::LOCK_UN)
      end
    end
  end
end
