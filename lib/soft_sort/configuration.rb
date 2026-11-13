# frozen_string_literal: true

module SoftSort
  class Configuration
    attr_reader :data

    def initialize(data)
      @data = data
      validate!
    end

    def self.load(path = nil)
      file = path || File.expand_path('../../config/default_rules.yml', __dir__)
      new(YAML.safe_load_file(file, permitted_classes: [], aliases: false) || {})
    rescue Psych::Exception, Errno::ENOENT => e
      raise ConfigurationError, "invalid configuration: #{e.message}"
    end

    def categories = data.fetch('categories', {})
    def context_rules = Array(data['context_rules'])
    def projects = data.fetch('projects', {})
    def exclusions = data.fetch('exclusions', {})
    def organization = data.fetch('organization', {})

    def extension_categories
      categories.each_with_object({}) do |(name, cfg), h|
        Array(cfg['extensions']).each do |e|
          h[e.downcase] = [name, cfg['destination']]
        end
      end
    end

    def validate!
      raise ConfigurationError, 'configuration must be a mapping' unless data.is_a?(Hash)

      categories.each_value do |cfg|
        unless cfg.is_a?(Hash) && safe_destination?(cfg['destination'].to_s)
          raise ConfigurationError, 'category destination is invalid'
        end
      end
      context_rules.each do |r|
        unless r.is_a?(Hash) && r['name'] && Array(r['keywords']).any? && safe_destination?(r['destination'].to_s)
          raise ConfigurationError, 'context rule is invalid'
        end
      end
      projects.each_value do |project|
        unless project.is_a?(Hash) && Array(project['aliases']).any? && safe_destination?(project['destination'].to_s)
          raise ConfigurationError, 'project rule is invalid'
        end
      end
      validate_organization!
    end

    def validate_organization!
      date_format = organization.fetch('date_format', 'year_month')
      date_source = organization.fetch('date_source', 'auto')
      collision = organization.fetch('collision_policy', 'skip')
      raise ConfigurationError, 'invalid date format' unless %w[year year_month year_month_day].include?(date_format)
      raise ConfigurationError, 'invalid date source' unless %w[auto modified created captured].include?(date_source)
      raise ConfigurationError, 'invalid collision policy' unless %w[skip review rename].include?(collision)
      inspection = data.fetch('content_inspection', {})
      limit = inspection.fetch('max_bytes', 1_048_576)
      raise ConfigurationError, 'invalid content inspection size limit' unless limit.is_a?(Integer) && limit.positive?
      ai = data.fetch('ai', {})
      raise ConfigurationError, 'AI must be disabled or specify a provider' if ai.fetch('enabled', false) && ai.fetch('provider', 'none') == 'none'
    end

    def safe_destination?(value)
      !value.empty? && !Pathname.new(value).absolute? && value.split(%r{[\\/]}).none? { |part| part == '..' }
    end
  end
end
