# frozen_string_literal: true

module SoftSort
  class OrganizationPlanner
    def initialize(root, config)
      @root = File.expand_path(root)
      @matcher = RuleMatcher.new(config)
    end

    def plan(files)
      results = files.select(&:eligible).map { |file| build(file) }
      destinations = results.group_by { |item| item[:destination] }.transform_values(&:length)
      results.each do |result|
        result[:action] = 'conflict' if destinations[result[:destination]] > 1 || existing_destination?(result)
      end
      results
    end

    private

    def existing_destination?(result)
      File.exist?(File.join(@root, result[:destination])) && result[:source] != result[:destination]
    end

    def build(file)
      classification = @matcher.classify(file)
      destination = Pathname.new(File.join(classification.destination, file.filename)).cleanpath.to_s
      raise ConfigurationError, 'destination escapes selected root' if destination == '..' || destination.start_with?('../')

      action = if destination == file.relative_path
                 'skip'
               elsif file.sensitive_reason
                 'review'
               elsif classification.requires_review
                 'review'
               else
                 'move'
               end
      { source: file.relative_path, destination: destination, type_category: classification.type_category,
        context_category: classification.context_category, matched_rule: classification.matched_rule,
        confidence: classification.confidence, action: action,
        warning: file.sensitive_reason || (classification.requires_review ? 'classification requires review' : nil) }
    end
  end
end
