# frozen_string_literal: true

module SoftSort
  class DirectoryWatcher
    def initialize(root, config:, recursive: false, interval: 5, stability_window: 2)
      @root = root
      @config = config
      @recursive = recursive
      @interval = [interval.to_i, 1].max
      @stability_window = [stability_window.to_i, 1].max
      @seen = {}
    end

    def run(apply: false, iterations: nil)
      cycles = 0
      loop do
        scan = DirectoryScanner.new(@root, config: @config, recursive: @recursive).scan
        stable = scan[:files].select { |file| stable?(file) }
        items = OrganizationPlanner.new(@root, @config).plan(stable)
        yield(items, apply) if block_given?
        cycles += 1
        break if iterations && cycles >= iterations

        sleep @interval
      end
    rescue Interrupt
      nil
    end

    private

    def stable?(file)
      key = file.absolute_path
      current = [file.size, file.modified_at.to_f]
      previous = @seen[key]
      @seen[key] = { signature: current, changed_at: Time.now }
      return false unless previous && previous[:signature] == current

      Time.now - previous[:changed_at] >= @stability_window
    end
  end
end
