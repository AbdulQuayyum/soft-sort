# frozen_string_literal: true

module SoftSort
  class PreviewFormatter
    def self.scan(report)
      "Files: #{report[:total]} | Eligible: #{report[:eligible]} | Excluded: #{report[:excluded]} | Size: #{report[:bytes]} bytes\n" + report[:categories].map { |k, v|
        "  #{k}: #{v}"
      }.join("\n")
    end

    def self.plan(items)
      items.map do |i|
        "#{i[:action].upcase.ljust(8)} #{i[:source]} -> #{i[:destination]} (#{i[:type_category]}, #{i[:confidence]})"
      end.join("\n")
    end
  end
end
