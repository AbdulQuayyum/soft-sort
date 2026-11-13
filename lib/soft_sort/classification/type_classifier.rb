# frozen_string_literal: true

module SoftSort
  class TypeClassifier
    def initialize(config)
      @map = config.extension_categories
      @filename_rules = config.data.fetch('filename_types', [])
    end

    def classify(file)
      return signature_match(file) || filename_match(file) if file.extension.empty? || !@map.key?(file.extension)

      @map.fetch(file.extension)
    end

    def known?(file)
      return true if @map.key?(file.extension)

      return true if signature_match(file)

      @filename_rules.any? do |item|
        File.basename(file.filename).match?(Regexp.new(item['pattern'], Regexp::IGNORECASE))
      rescue RegexpError
        false
      end
    end

    private

    def signature_match(file)
      return unless file.absolute_path && File.file?(file.absolute_path)

      header = File.open(file.absolute_path, 'rb') { |stream| stream.read(32) }
      return %w[Documents Documents] if header&.start_with?('%PDF-')
      return %w[Archives Archives] if header&.start_with?("PK\x03\x04")
      return ['Development Scripts', 'Projects/Source/Scripts'] if header&.start_with?('#!')

      nil
    rescue SystemCallError
      nil
    end

    def filename_match(file)
      rule = @filename_rules.find do |item|
        File.basename(file.filename).match?(Regexp.new(item['pattern'], Regexp::IGNORECASE))
      end
      return [rule['category'], rule['destination']] if rule

      @map.fetch('', %w[Others Others])
    rescue RegexpError
      %w[Others Others]
    end
  end
end
