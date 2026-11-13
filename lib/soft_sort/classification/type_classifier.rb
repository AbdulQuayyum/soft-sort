# frozen_string_literal: true

module SoftSort
  class TypeClassifier
    def initialize(config) = @map = config.extension_categories

    def classify(file)
      category, destination = @map[file.extension] || %w[Others Others]
      [category, destination]
    end
  end
end
