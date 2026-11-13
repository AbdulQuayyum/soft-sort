# frozen_string_literal: true

module SoftSort
  class DirectoryScanner
    DEFAULT_EXCLUDED = %w[.git node_modules .venv vendor/bundle __pycache__ .soft-sort].freeze
    DEFAULT_TEMP = %w[part crdownload download tmp].freeze
    attr_reader :root

    def initialize(root, config:, recursive: false)
      expanded = root.to_s.start_with?('~') ? File.expand_path(root) : root.to_s
      @root = File.expand_path(expanded)
      raise ScanError, "directory does not exist: #{root}" unless File.exist?(@root)
      raise ScanError, "not a directory: #{root}" unless File.directory?(@root)

      @config = config
      @recursive = recursive
    end

    def scan
      files = []
      warnings = []
      paths = @recursive ? Dir.glob(File.join(@root, '**', '*'), File::FNM_DOTMATCH) : Dir.children(@root).map { |n| File.join(@root, n) }
      paths.each do |path|
        next unless File.file?(path) || File.symlink?(path)

        rel = Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
        begin
          reason = exclusion_reason(rel, path)
          stat = File.lstat(path)
          files << FileMetadata.new(absolute_path: path, relative_path: rel, filename: File.basename(path),
                                    extension: File.extname(path).delete_prefix('.').downcase, size: stat.file? ? stat.size : 0, modified_at: stat.mtime, created_at: begin
                                      stat.birthtime
                                    rescue StandardError
                                      nil
                                    end, parent_directory: File.dirname(rel), eligible: reason.nil?, exclusion_reason: reason,
                                    sensitive_reason: SensitiveFileDetector.reason(File.basename(path)))
        rescue SystemCallError => e
          warnings << "#{rel}: #{e.message}"
        end
      end
      { files: files, warnings: warnings }
    rescue SystemCallError => e
      raise ScanError, "unable to scan #{@root}: #{e.message}"
    end

    private

    def exclusion_reason(rel, path)
      return 'symbolic link' if File.symlink?(path)

      parts = rel.split(File::SEPARATOR)
      return 'hidden file or directory' if !@config.data.dig('safety', 'include_hidden') && parts.any? do |p|
        p.start_with?('.')
      end

      dirs = DEFAULT_EXCLUDED + Array(@config.exclusions['directories'])
      return 'excluded directory' if parts[0...-1].any? { |p| dirs.include?(p) }
      if (Array(@config.exclusions['extensions']).map(&:downcase) + DEFAULT_TEMP).include?(File.extname(path).delete_prefix('.').downcase)
        return 'temporary or incomplete download'
      end

      nil
    end
  end
end
