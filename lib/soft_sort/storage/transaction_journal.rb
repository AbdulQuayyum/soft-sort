# frozen_string_literal: true

module SoftSort
  class TransactionJournal
    def initialize(root)
      @directory = File.join(File.expand_path(root), '.soft-sort')
      @path = File.join(@directory, 'transactions.jsonl')
    end

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
      File.foreach(@path) do |line|
        begin
          record = JSON.parse(line)
          records[record['id']] = record
        rescue JSON::ParserError
          next
        end
      end
      records.values
    end

    private

    def append(record)
      FileUtils.mkdir_p(@directory)
      File.open(@path, 'a', 0o600) { |file| file.puts(JSON.generate(record)) }
    end
  end
end
