# frozen_string_literal: true

module SoftSort
  class UndoManager
    def initialize(root)
      @root = File.expand_path(root)
      @journal = TransactionJournal.new(@root)
    end

    def undo(transaction_id: nil, dry_run: false)
      return undo_locked(transaction_id: transaction_id, dry_run: dry_run) if dry_run

      RootLock.new(@root).synchronize { undo_locked(transaction_id: transaction_id, dry_run: false) }
    end

    private

    def undo_locked(transaction_id:, dry_run:)
      records = @journal.all.select { |record| record['root'] == @root }
      record = transaction_id ? records.reverse.find { |item| item['id'] == transaction_id } : records.reverse.find { |item| item['status'] == 'completed' }
      raise Error, 'transaction not found' unless record

      results = record['operations'].reverse.map do |op|
        next { 'source' => op['destination'], 'destination' => op['source'], 'status' => 'skipped' } unless op['status'] == 'moved'
        from = File.join(@root, op['destination'])
        to = File.join(@root, op['source'])
        if dry_run
          { 'source' => op['destination'], 'destination' => op['source'], 'status' => 'planned' }
        elsif !File.file?(from) || File.exist?(to) || Digest::SHA256.file(from).hexdigest != op['sha256']
          { 'source' => op['destination'], 'destination' => op['source'], 'status' => 'conflict' }
        else
          raise Error, 'undo source or destination is a symbolic link' if File.symlink?(from) || File.symlink?(to)

          FileUtils.mkdir_p(File.dirname(to))
          File.link(from, to)
          File.unlink(from)
          { 'source' => op['destination'], 'destination' => op['source'], 'status' => 'undone' }
        end
      end
      record['status'] = results.any? { |item| item['status'] == 'conflict' } ? 'partially_undone' : 'undone'
      @journal.update(record) unless dry_run
      results
    end
  end
end
