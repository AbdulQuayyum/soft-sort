# frozen_string_literal: true

module SoftSort
  class SensitiveFileDetector
    PATTERNS = [
      /(^|\.)env(?:\.|$)/i, /password|secret|credential|token|recovery[-_ ]?code/i,
      /private[-_ ]?key|id_rsa|keystore|service[-_ ]?account/i, /\.(pem|p12|p8|key|der)$/i
    ].freeze

    def self.reason(filename)
      PATTERNS.find { |pattern| filename.match?(pattern) } && 'possible sensitive or security credential'
    end
  end
end
