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
    def exclusions = data.fetch('exclusions', {})

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
    end

    def safe_destination?(value)
      !value.empty? && !Pathname.new(value).absolute? && value.split(%r{[\\/]}).none? { |part| part == '..' }
    end
  end
end
