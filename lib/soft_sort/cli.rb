# frozen_string_literal: true

module SoftSort
  class CLI
    COMMANDS = %w[scan plan organize duplicates history undo recover stats explain watch].freeze

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      return puts help if @argv.empty? || %w[--help -h].include?(@argv.first)
      return puts "SoftSort #{VERSION}" if @argv.first == 'version'

      command = @argv.shift
      raise Error, "unsupported command: #{command}" unless COMMANDS.include?(command)
      options = parse_options
      root = @argv.shift || '.'
      raise Error, "unexpected arguments: #{@argv.join(' ')}" unless @argv.empty?
      config = Configuration.load(options[:config])
      config = override_config(config, options)
      dispatch(command, root, config, options)
    rescue Error, OptionParser::ParseError => e
      warn "soft-sort: #{e.message}"
      1
    end

    def help
      <<~TEXT
        Usage: soft-sort <command> DIRECTORY [options]
          scan, plan, organize, duplicates, history, undo, recover, stats, explain, watch
          --recursive       Include subdirectories
          --apply           Execute approved organization moves
          --dry-run         Preview undo/recovery operations
          --transaction ID  Select a transaction
          --limit NUMBER    Limit history output
          --format FORMAT   Emit text or json
          --config PATH     Use YAML rules
          --date-folders    Add configured date folders to destinations
          --inspect-content Enable bounded local content evidence
          --collision POLICY  Use skip, review, or rename collision handling
          --interval SECONDS  Polling interval for watch mode
      TEXT
    end

    private

    def parse_options
      options = { recursive: false, format: 'text', config: nil, apply: false, dry_run: false, transaction: nil, limit: nil, verbose: false,
                  date_folders: false, inspect_content: false, collision: nil, interval: 5 }
      parser = OptionParser.new do |o|
        o.on('--recursive') { options[:recursive] = true }
        o.on('--apply') { options[:apply] = true }
        o.on('--dry-run') { options[:dry_run] = true }
        o.on('--transaction ID') { |v| options[:transaction] = v }
        o.on('--limit NUMBER', Integer) { |v| options[:limit] = v }
        o.on('--format FORMAT') { |v| options[:format] = v }
        o.on('--config PATH') { |v| options[:config] = v }
        o.on('--verbose') { options[:verbose] = true }
        o.on('--date-folders') { options[:date_folders] = true }
        o.on('--inspect-content') { options[:inspect_content] = true }
        o.on('--collision POLICY') { |v| options[:collision] = v }
        o.on('--interval SECONDS', Integer) { |v| options[:interval] = v }
      end
      parser.parse!(@argv)
      raise Error, 'format must be text or json' unless %w[text json].include?(options[:format])
      options
    end

    def override_config(config, options)
      return config unless options[:date_folders] || options[:inspect_content] || options[:collision]

      data = Marshal.load(Marshal.dump(config.data))
      data['organization'] ||= {}
      data['organization']['date_folders'] = true if options[:date_folders]
      data['organization']['collision_policy'] = options[:collision] if options[:collision]
      data['content_inspection'] ||= {}
      data['content_inspection']['enabled'] = true if options[:inspect_content]
      Configuration.new(data)
    end

    def dispatch(command, root, config, options)
      case command
      when 'scan', 'plan', 'organize', 'stats', 'explain'
        scan = DirectoryScanner.new(root, config: config, recursive: options[:recursive]).scan
        items = OrganizationPlanner.new(root, config).plan(scan[:files])
        return output(scan_report(scan, root, items), options, text: PreviewFormatter.scan(scan_report(scan, root, items))) if command == 'scan'
        return output(plan_report(root, items, scan[:warnings]), options, text: PreviewFormatter.plan(items)) if command == 'plan'
        if command == 'stats'
          duplicates = DuplicateDetector.new(root).find(scan[:files])
          return output(StatisticsReporter.build(scan, items, duplicates: duplicates), options)
        end
        return explain(root, items, options) if command == 'explain'

        record = Executor.new(root).execute(items, apply: options[:apply])
        output(record, options)
      when 'duplicates'
        scan = DirectoryScanner.new(root, config: config, recursive: options[:recursive]).scan
        output(DuplicateDetector.new(root).find(scan[:files]), options)
      when 'history'
        records = TransactionJournal.new(root).all
        records = records.last(options[:limit]) if options[:limit]
        output(records, options)
      when 'recover'
        reports = if options[:apply]
                    RecoveryManager.new(root).apply(transaction_id: options[:transaction])
                  else
                    RecoveryManager.new(root).inspect(transaction_id: options[:transaction])
                  end
        output(reports, options, text: recovery_text(reports, options[:apply]))
      when 'undo'
        result = UndoManager.new(root).undo(transaction_id: options[:transaction], dry_run: options[:dry_run])
        output(result, options)
      when 'watch'
        watcher = DirectoryWatcher.new(root, config: config, recursive: options[:recursive], interval: options[:interval])
        watcher.run(apply: options[:apply]) do |items, apply|
          if apply
            output(Executor.new(root).execute(items, apply: true), options)
          else
            output({ root: File.expand_path(root), files: items }, options, text: PreviewFormatter.plan(items))
          end
        end
      end
    end

    def scan_report(scan, root, items)
      eligible = scan[:files].select(&:eligible)
      { root: File.expand_path(root), total: scan[:files].length, eligible: eligible.length,
        excluded: scan[:files].length - eligible.length, bytes: eligible.sum(&:size), warnings: scan[:warnings],
        categories: items.group_by { |item| item[:type_category] }.transform_values(&:length) }
    end

    def plan_report(root, items, warnings)
      { root: File.expand_path(root), files: items, warnings: warnings }
    end

    def explain(root, items, options)
      item = items.first
      raise Error, 'no eligible files found' unless item
      output(item.merge(root: File.expand_path(root)), options)
    end

    def recovery_text(reports, applied)
      return 'No incomplete transactions require recovery.' if reports.empty?

      lines = ['SoftSort Recovery Preview', '']
      reports.each do |report|
        lines << "Transaction: #{report['transaction']}"
        lines << "Status: #{report['status']}"
        lines << "Completed: #{report['completed']}"
        lines << "Pending: #{report['pending']}"
        lines << "Conflicts: #{report['conflicts']}"
        lines << "Recoverable: #{report['recoverable']}"
      end
      lines << (applied ? 'Recovery actions applied.' : 'No files were modified.')
      lines.join("\n")
    end

    def output(value, options, text: nil)
      if options[:format] == 'json'
        puts JsonReporter.dump(value)
      else
        puts(text || (value.is_a?(Hash) ? value.map { |k, v| "#{k}: #{v}" }.join("\n") : value))
      end
    end
  end
end
