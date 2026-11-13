# frozen_string_literal: true

module SoftSort
  class ContextClassifier
    def initialize(config)
      projects = config.projects.map do |name, project|
        { 'name' => "project_#{name}", 'keywords' => project['aliases'],
          'destination' => project['destination'], 'project_destinations' => project['destinations'],
          'priority' => project.fetch('priority', 85) }
      end
      @rules = (config.context_rules + projects).sort_by { |r| -r.fetch('priority', 0).to_i }
    end

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
