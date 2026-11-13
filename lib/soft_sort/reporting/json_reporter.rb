# frozen_string_literal: true

module SoftSort
  class JsonReporter
    def self.dump(object) = JSON.generate(object)
  end
end
