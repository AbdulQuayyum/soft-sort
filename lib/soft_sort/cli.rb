# frozen_string_literal: true

module SoftSort
  class CLI
    def initialize(argv) = @argv = argv.dup

    def run
      return puts help if @argv.empty? || @argv.first == '--help' || @argv.first == '-h'
      return puts "SoftSort #{VERSION}" if @argv.first == 'version'

      command = @argv.shift
      raise Error, "unsupported command: #{command}" unless %w[scan plan].include?(command)

      options = { recursive: false, format: 'text', config: nil, verbose: false }
      parser = OptionParser.new do |o|
        o.on('--recursive') { options[:recursive] = true }
        o.on('--format FORMAT') { |v| options[:format] = v }
        o.on('--config PATH') { |v| options[:config] = v }
        o.on('--verbose') { options[:verbose] = true }
        o.on('--help') do
          puts o
          exit
        end
      end
      parser.parse!(@argv)

      root = @argv.shift || '.'
      raise Error, "unexpected arguments: #{@argv.join(' ')}" unless @argv.empty?
      unless %w[text json].include?(options[:format])
        raise Error,
              'format must be text or json'
      end

      config = Configuration.load(options[:config])

      scan = DirectoryScanner.new(root, config: config, recursive: options[:recursive]).scan
      if command == 'scan'
        categories = Hash.new(0)
        scan[:files].select(&:eligible).each { |f| categories[f.extension.empty? ? 'Others' : f.extension] += 1 }
        report = { root: File.expand_path(root), total: scan[:files].length, eligible: scan[:files].count(&:eligible), excluded: scan[:files].count do |f|
          !f.eligible
        end, bytes: scan[:files].select(&:eligible).sum(&:size), categories: categories, warnings: scan[:warnings] }
      else
        items = OrganizationPlanner.new(root, config).plan(scan[:files])

        report = { root: File.expand_path(root), files: items, warnings: scan[:warnings] }
      end
      puts(if options[:format] == 'json'
             JsonReporter.dump(report)
           else
             (command == 'scan' ? PreviewFormatter.scan(report) : PreviewFormatter.plan(report[:files]))
           end)
    rescue Error, OptionParser::ParseError => e
      warn "soft-sort: #{e.message}"
      1
    end

    def help
      "Usage: soft-sort <scan|plan|version> DIRECTORY [options]\n  --recursive  Include subdirectories\n  --format json  Emit JSON\n  --config PATH  Use YAML rules\n  --verbose  Show diagnostics"
    end
  end
end
