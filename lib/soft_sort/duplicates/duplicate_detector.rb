# frozen_string_literal: true

module SoftSort
  class DuplicateDetector
    def initialize(root)
      @root = File.expand_path(root)
    end

    def find(files)
      candidates = files.select(&:eligible).group_by(&:size).select { |_size, group| group.length > 1 }
      candidates.values.flat_map do |group|
        grouped = group.group_by { |file| Digest::SHA256.file(file.absolute_path).hexdigest }
        grouped.values.select { |items| items.length > 1 }.map { |items| { hash: Digest::SHA256.file(items.first.absolute_path).hexdigest, files: items.map(&:relative_path), size: items.first.size } }
      end
    end
  end
end
