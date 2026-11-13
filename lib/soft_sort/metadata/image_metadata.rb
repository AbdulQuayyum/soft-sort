# frozen_string_literal: true

module SoftSort
  class ImageMetadata
    def self.read(file, max_bytes: 65_536)
      return nil unless %w[png jpg jpeg].include?(file.extension)

      bytes = File.open(file.absolute_path, 'rb') { |stream| stream.read(max_bytes) }
      return png_metadata(bytes) if file.extension == 'png'

      nil
    rescue SystemCallError
      nil
    end

    def self.png_metadata(bytes)
      signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack('C*')
      return nil unless bytes && bytes.byteslice(0, 8) == signature && bytes.bytesize >= 20

      { width: bytes.byteslice(16, 4).unpack1('N'), height: bytes.byteslice(20, 4).unpack1('N'), capture_time: nil }
    end
    private_class_method :png_metadata
  end
end
