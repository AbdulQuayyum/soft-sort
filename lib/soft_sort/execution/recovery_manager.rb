# frozen_string_literal: true

module SoftSort
  class RecoveryManager
    def initialize(root)
      @root = File.expand_path(root)
      @journal = TransactionJournal.new(@root)
    end

    def inspect(transaction_id: nil)
      records = @journal.all.select { |record| record['root'] == @root && recoverable_transaction?(record) }
      records = records.select { |record| record['id'] == transaction_id } if transaction_id
      records.filter_map { |record| reconcile(record) }
    end

    def apply(transaction_id: nil)
      RootLock.new(@root).synchronize do
        inspect(transaction_id: transaction_id).map do |report|
          recovered = retry_recoverable(report)
          record = @journal.all.find { |item| item['id'] == report['transaction'] }
          if record
            recovered['operations'].each do |operation|
              journal_operation = record['operations'].find { |item| item['source'] == operation['source'] }
              journal_operation['status'] = 'moved' if journal_operation && operation['state'] == 'completed'
            end
            record['status'] = recovered['conflicts'].zero? ? 'recovered' : 'recovery_required'
            @journal.update(record)
            recovered['status'] = record['status']
          end
          recovered
        end
      end
    end

    private

    def recoverable_transaction?(record)
      %w[planned prepared in_progress interrupted failed recovery_required partially_undone].include?(record['status'])
    end

    def reconcile(record)
      states = record['operations'].map { |operation| reconcile_operation(operation) }
      { 'transaction' => record['id'], 'status' => record['status'], 'operations' => states,
        'completed' => states.count { |item| item['state'] == 'completed' },
        'pending' => states.count { |item| item['state'] == 'pending' },
        'conflicts' => states.count { |item| item['state'] == 'conflict' },
        'recoverable' => states.count { |item| item['state'] == 'recoverable' } }
    end

    def reconcile_operation(operation)
      return operation.merge('state' => 'skipped') unless operation['action'] == 'move'

      source = File.join(@root, operation['source'])
      destination = File.join(@root, operation['destination'])
      return operation.merge('state' => 'unsafe') if File.symlink?(source) || File.symlink?(destination)
      source_exists = File.file?(source)
      destination_exists = File.file?(destination)
      if source_exists && !destination_exists
        return operation.merge('state' => Digest::SHA256.file(source).hexdigest == operation['sha256'] ? 'recoverable' : 'conflict')
      end
      return operation.merge('state' => 'completed') if !source_exists && destination_exists && hash(destination) == operation['sha256']
      return operation.merge('state' => 'conflict') if source_exists && destination_exists

      operation.merge('state' => 'recovery_required')
    end

    def retry_recoverable(report)
      report['operations'].each do |operation|
        next unless operation['state'] == 'recoverable'

        source = File.join(@root, operation['source'])
        destination = File.join(@root, operation['destination'])
        FileUtils.mkdir_p(File.dirname(destination))
        File.link(source, destination)
        File.unlink(source)
        operation['state'] = 'completed'
      end
      report
    end

    def hash(path)
      Digest::SHA256.file(path).hexdigest
    rescue SystemCallError
      nil
    end
  end
end
