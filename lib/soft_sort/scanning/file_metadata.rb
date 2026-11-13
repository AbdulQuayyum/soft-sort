# frozen_string_literal: true

module SoftSort
  FileMetadata = Struct.new(:absolute_path, :relative_path, :filename, :extension, :size, :modified_at, :created_at,
                            :parent_directory, :eligible, :exclusion_reason, :sensitive_reason, keyword_init: true)
end
