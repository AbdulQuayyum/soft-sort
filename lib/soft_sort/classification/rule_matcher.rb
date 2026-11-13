# frozen_string_literal: true

module SoftSort
  class RuleMatcher
    def initialize(config)
      @config = config
      @types = TypeClassifier.new(config)
      @contexts = ContextClassifier.new(config)
    end

    def classify(file)
      type, type_dest = @types.classify(file)
      matches = @contexts.matches(file.filename)
      if matches.any?
        top = matches.first
        tied = matches.take_while do |r|
          r.fetch('priority', 0).to_i == top.fetch('priority', 0).to_i
        end
        return ClassificationResult.new(type_category: type,
                                        context_category: tied.length == 1 ? top['name'].to_s.capitalize : 'Review', destination: tied.length == 1 ? top['destination'] : type_dest, matched_rule: tied.length == 1 ? top['name'] : 'ambiguous', confidence: tied.length == 1 ? 0.95 : 0.40, requires_review: tied.length != 1)
      end
      known = @config.extension_categories.key?(file.extension)
      ClassificationResult.new(type_category: type, context_category: nil, destination: type_dest,
                               matched_rule: known ? "file_type_#{file.extension}" : 'unknown_file', confidence: known ? 0.80 : 0.25, requires_review: !known)
    end
  end
end
