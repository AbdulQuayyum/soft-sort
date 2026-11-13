# frozen_string_literal: true

module SoftSort
  class StatisticsReporter
    def self.build(scan, plan, duplicates: [])
      { total_files: scan[:files].length, eligible_files: scan[:files].count(&:eligible), total_bytes: scan[:files].select(&:eligible).sum(&:size),
        planned_moves: plan.count { |item| item[:action] == 'move' }, conflicts: plan.count { |item| item[:action] == 'conflict' },
        reviews: plan.count { |item| item[:action] == 'review' }, duplicate_groups: duplicates.length,
        categories: scan[:files].select(&:eligible).group_by(&:extension).transform_values(&:length) }
    end
  end
end
