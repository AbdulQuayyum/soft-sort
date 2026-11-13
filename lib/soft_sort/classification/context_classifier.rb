# frozen_string_literal: true

module SoftSort
  class ContextClassifier
    def initialize(config) = @rules = config.context_rules.sort_by { |r| -r.fetch('priority', 0).to_i }

    def matches(filename)
      tokens = filename.downcase.scan(/[[:alnum:]]+/)
      @rules.select do |r|
        Array(r['keywords']).any? do |k|
          tokens == k.to_s.downcase.scan(/[[:alnum:]]+/) || tokens.include?(k.to_s.downcase)
        end
      end
    end
  end
end
