# frozen_string_literal: true

module SoftSort
  class ContentClassifier
    RULES = [
      { name: 'invoice_content', keywords: %w[invoice billing amount due], destination: 'Finance/Invoices', category: 'Documents' },
      { name: 'research_content', keywords: %w[research methodology references abstract], destination: 'Documents/Education/Research', category: 'Documents' },
      { name: 'contract_content', keywords: %w[agreement contract parties obligations], destination: 'Finance/Contracts', category: 'Documents' }
    ].freeze

    def initialize(config)
      settings = config.data.fetch('content_inspection', {})
      @enabled = settings.fetch('enabled', false)
      @max_bytes = settings.fetch('max_bytes', 1_048_576)
      @min_signals = settings.fetch('min_signals', 2)
    end

    def classify(file)
      return nil unless @enabled && readable_format?(file) && !file.sensitive_reason

      content = File.open(file.absolute_path, 'rb') { |stream| stream.read(@max_bytes) }.to_s.force_encoding(Encoding::UTF_8).scrub.downcase
      match = RULES.map { |rule| [rule, rule[:keywords].count { |keyword| content.include?(keyword) }] }
                   .select { |_rule, signals| signals >= @min_signals }.max_by(&:last)
      return nil unless match

      rule, signals = match
      { category: rule[:category], destination: rule[:destination], name: rule[:name], confidence: [0.70 + (signals * 0.05), 0.90].min.round(2) }
    rescue SystemCallError, ArgumentError
      nil
    end

    private

    def readable_format?(file)
      %w[txt md markdown csv json pdf].include?(file.extension)
    end
  end
end
