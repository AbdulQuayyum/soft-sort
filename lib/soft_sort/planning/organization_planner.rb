# frozen_string_literal: true

module SoftSort
  class OrganizationPlanner
    def initialize(root, config)
      @root = File.expand_path(root)
      @matcher = RuleMatcher.new(config)
      @protect_existing = config.data.fetch('safety', {}).fetch('protect_existing_project_structures', true)
      @organization = config.organization
    end

    def plan(files)
      results = files.select(&:eligible).map { |file| build(file) }
      apply_collision_policy(results)
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
      destination_root = date_destination(classification.destination, file)
      destination = Pathname.new(File.join(destination_root, file.filename)).cleanpath.to_s
      raise ConfigurationError, 'destination escapes selected root' if destination == '..' || destination.start_with?('../')

      action = if destination == file.relative_path
                 'skip'
               elsif @protect_existing && file.parent_directory != '.'
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
        warning: warning_for(file, classification) }
    end

    def date_destination(destination, file)
      return destination unless @organization.fetch('date_folders', false)

      timestamp = case @organization.fetch('date_source', 'auto')
                  when 'created' then file.created_at
                  when 'modified' then file.modified_at
                  else file.created_at || file.modified_at
                  end
      return destination unless timestamp.respond_to?(:year)

      parts = case @organization.fetch('date_format', 'year_month')
              when 'year' then [timestamp.year]
              when 'year_month_day' then [timestamp.year, format('%02d', timestamp.month), format('%02d', timestamp.day)]
              else [timestamp.year, format('%02d', timestamp.month)]
              end
      File.join(destination, *parts.map(&:to_s))
    end

    def apply_collision_policy(results)
      used = {}
      results.each do |result|
        collision = result[:action] == 'move' && (File.exist?(File.join(@root, result[:destination])) || used.key?(result[:destination].downcase))
        unless collision
          used[result[:destination].downcase] = true
          next
        end

        case @organization.fetch('collision_policy', 'skip')
        when 'rename'
          result[:destination] = available_name(result[:destination], used)
        when 'review'
          result[:action] = 'review'
          result[:warning] = 'destination collision requires review'
        end
        used[result[:destination].downcase] = true
      end
    end

    def available_name(destination, used)
      return destination unless used.key?(destination.downcase) || File.exist?(File.join(@root, destination))

      extension = File.extname(destination)
      stem = destination.delete_suffix(extension)
      index = 1
      candidate = "#{stem} (#{index})#{extension}"
      while used.key?(candidate.downcase) || File.exist?(File.join(@root, candidate))
        index += 1
        candidate = "#{stem} (#{index})#{extension}"
      end
      candidate
    end

    def warning_for(file, classification)
      return file.sensitive_reason if file.sensitive_reason
      return 'existing directory structure protected' if protected_structure?(file)
      return 'classification requires review' if classification.requires_review

      nil
    end

    def protected_structure?(file)
      @protect_existing && file.parent_directory != '.'
    end
  end
end
