RSpec.describe SoftSort::DirectoryScanner do
  around do |example|
    Dir.mktmpdir('soft-sort-timestamps') do |directory|
      @directory = directory
      example.run
    end
  end

  let(:path) { File.join(@directory, 'note.txt') }
  let(:modified_at) { Time.utc(2024, 2, 3, 12) }
  let(:configuration) { SoftSort::Configuration.load }

  before do
    File.write(path, 'unchanged')
    File.utime(modified_at, modified_at, path)
    @stat = File.lstat(path)
    allow(File).to receive(:lstat).and_call_original
    allow(File).to receive(:lstat).with(path).and_return(@stat)
  end

  [NotImplementedError, Errno::ENOTSUP].each do |error|
    it "keeps scanning when birthtime raises #{error}" do
      allow(@stat).to receive(:birthtime).and_raise(error)

      scan = described_class.new(@directory, config: configuration).scan

      expect(scan[:warnings]).to be_empty
      expect(scan[:files].size).to eq(1)
      expect(scan[:files].first.to_h).to include(
        relative_path: 'note.txt', created_at: nil, modified_at: modified_at,
        size: 9, eligible: true
      )
      expect(File.read(path)).to eq('unchanged')
    end
  end

  it 'preserves a supported birth timestamp' do
    created_at = Time.utc(2023, 12, 31, 12)
    allow(@stat).to receive(:birthtime).and_return(created_at)

    file = described_class.new(@directory, config: configuration).scan[:files].first

    expect(file.created_at).to eq(created_at)
    expect(file.modified_at).to eq(modified_at)
  end

  it 'uses modification time for automatic date folders when birthtime is unavailable' do
    allow(@stat).to receive(:birthtime).and_raise(NotImplementedError)
    configuration.organization['date_folders'] = true
    configuration.organization['date_source'] = 'auto'
    configuration.organization['date_format'] = 'year_month_day'

    files = described_class.new(@directory, config: configuration).scan[:files]
    plan = SoftSort::OrganizationPlanner.new(@directory, configuration).plan(files)

    expect(plan.first).to include(destination: 'Documents/2024/02/03/note.txt', action: 'move')
    expect(Dir.children(@directory)).to eq(['note.txt'])
    expect(File.read(path)).to eq('unchanged')
  end
end
