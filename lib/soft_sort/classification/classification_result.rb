# frozen_string_literal: true

module SoftSort
  ClassificationResult = Struct.new(:type_category, :context_category, :destination, :matched_rule, :confidence,
                                    :requires_review, keyword_init: true)
end
