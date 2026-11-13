# frozen_string_literal: true

module SoftSort
  module AI
    class DisabledProvider
      def classify(_file)
        nil
      end
    end

    class ProviderInterface
      def classify(_file)
        raise NotImplementedError, 'AI providers must implement #classify'
      end
    end
  end
end
