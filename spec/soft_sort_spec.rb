RSpec.describe SoftSort do
  def config(data = nil)
    data ? SoftSort::Configuration.new(data) : SoftSort::Configuration.load
  end

  def with_directory
    Dir.mktmpdir('soft-sort-spec') { |dir| yield dir }
  end

  it 'scans empty and single-file directories without changing them' do
    with_directory do |dir|
      expect(SoftSort::DirectoryScanner.new(dir, config: config).scan[:files]).to be_empty
      path = File.join(dir, 'invoice_2026.PDF')
      File.write(path, 'x')
      scan = SoftSort::DirectoryScanner.new(dir, config: config).scan
      expect(scan[:files].first.size).to eq(1)
      expect(File.read(path)).to eq('x')
    end
  end

  it 'supports opt-in recursion and excludes hidden, temporary, and configured directories' do
    with_directory do |dir|
      FileUtils.mkdir_p(File.join(dir, 'nested', 'node_modules'))
      File.write(File.join(dir, 'nested', 'notes.txt'), 'x')
      File.write(File.join(dir, 'nested', 'node_modules', 'ignored.js'), 'x')
      File.write(File.join(dir, '.hidden.txt'), 'x')
      File.write(File.join(dir, 'download.part'), 'x')
      scan = SoftSort::DirectoryScanner.new(dir, config: config, recursive: true).scan
      expect(scan[:files].map(&:relative_path)).to include('nested/notes.txt')
      expect(scan[:files].find { |f| f.relative_path == 'nested/node_modules/ignored.js' }.eligible).to be(false)
      expect(scan[:files].find { |f| f.relative_path == '.hidden.txt' }.eligible).to be(false)
      expect(scan[:files].find { |f| f.relative_path == 'download.part' }.exclusion_reason).to include('temporary')
    end
  end

  it 'does not follow symbolic links' do
    with_directory do |dir|
      File.write(File.join(dir, 'real.txt'), 'x')
      File.symlink(File.join(dir, 'real.txt'), File.join(dir, 'link.txt'))
      file = SoftSort::DirectoryScanner.new(dir, config: config).scan[:files].find { |f| f.filename == 'link.txt' }
      expect(file.eligible).to be(false)
      expect(file.exclusion_reason).to eq('symbolic link')
    end
  end

  it 'classifies extensions case-insensitively and flags unknown files for review' do
    with_directory do |dir|
      %w[PHOTO.JPG mystery.xyz].each { |name| File.write(File.join(dir, name), 'x') }
      files = SoftSort::DirectoryScanner.new(dir, config: config).scan[:files]
      results = files.to_h { |file| [file.filename, SoftSort::RuleMatcher.new(config).classify(file)] }
      expect(results['PHOTO.JPG'].type_category).to eq('Images')
      expect(results['mystery.xyz'].requires_review).to be(true)
    end
  end

  it 'recognizes documentation, scripts, configuration, development, design, and database formats' do
    with_directory do |dir|
      names = %w[guide.md deploy.sh settings.toml app.sql model.dwg icon.svg font.woff book.epub]
      names.each { |name| File.write(File.join(dir, name), 'x') }
      files = SoftSort::DirectoryScanner.new(dir, config: config).scan[:files]
      results = files.to_h { |file| [file.extension, SoftSort::RuleMatcher.new(config).classify(file)] }
      expect(results['md'].type_category).to eq('Documentation')
      expect(results['sh'].type_category).to eq('Development Scripts')
      expect(results['toml'].type_category).to eq('Configuration')
      expect(results['sql'].type_category).to eq('Development')
      expect(results['dwg'].type_category).to eq('CAD')
      expect(results['woff'].type_category).to eq('Fonts')
      expect(results['epub'].type_category).to eq('Documents')
    end
  end

  it 'groups configured project files into project type subfolders' do
    custom = YAML.safe_load(File.read(File.expand_path('../config/default_rules.yml', __dir__)))
    custom['projects'] = { 'civicwatch' => { 'aliases' => ['civicwatch'], 'destination' => 'Projects/CivicWatch',
                                              'destinations' => { 'Development Scripts' => 'Projects/CivicWatch/Development/Scripts' } } }
    file = SoftSort::FileMetadata.new(filename: 'CivicWatch-deployment.sh', extension: 'sh', parent_directory: '.')
    result = SoftSort::RuleMatcher.new(config(custom)).classify(file)
    expect(result.destination).to eq('Projects/CivicWatch/Development/Scripts')
  end

  it 'protects sensitive files and established recursive project structures' do
    with_directory do |dir|
      FileUtils.mkdir_p(File.join(dir, 'ExistingProject', 'lib'))
      File.write(File.join(dir, '.env.production'), 'secret')
      File.write(File.join(dir, 'ExistingProject', 'lib', 'app.rb'), 'puts 1')
      files = SoftSort::DirectoryScanner.new(dir, config: config, recursive: true).scan[:files]
      plan = SoftSort::OrganizationPlanner.new(dir, config).plan(files)
      expect(plan.find { |item| item[:source] == 'ExistingProject/lib/app.rb' }[:action]).to eq('skip')
      expect(plan).not_to include(a_hash_including(source: '.env.production'))
    end
  end

  it 'resolves contextual rules by priority and marks equal priorities ambiguous' do
    custom = {
      'categories' => { 'Documents' => { 'extensions' => ['txt'], 'destination' => 'Documents' } },
      'context_rules' => [
        { 'name' => 'high', 'keywords' => ['invoice'], 'destination' => 'Finance', 'priority' => 100 },
        { 'name' => 'low', 'keywords' => ['invoice'], 'destination' => 'Other', 'priority' => 10 }
      ]
    }
    file = SoftSort::FileMetadata.new(filename: 'invoice.txt', extension: 'txt')
    expect(SoftSort::RuleMatcher.new(config(custom)).classify(file).destination).to eq('Finance')
    custom['context_rules'][1]['priority'] = 100
    result = SoftSort::RuleMatcher.new(config(custom)).classify(file)
    expect(result.requires_review).to be(true)
    expect(result.matched_rule).to eq('ambiguous')
  end

  it 'plans deterministic destinations and skips already-organized files' do
    with_directory do |dir|
      FileUtils.mkdir_p(File.join(dir, 'Documents'))
      File.write(File.join(dir, 'invoice.txt'), 'a')
      File.write(File.join(dir, 'Documents', 'already.txt'), 'c')
      files = SoftSort::DirectoryScanner.new(dir, config: config, recursive: true).scan[:files]
      first = SoftSort::OrganizationPlanner.new(dir, config).plan(files)
      second = SoftSort::OrganizationPlanner.new(dir, config).plan(files)
      expect(first).to eq(second)
      expect(first.find { |item| item[:source] == 'Documents/already.txt' }[:action]).to eq('skip')
    end
  end

  it 'rejects invalid configuration destinations and missing roots' do
    expect { config('categories' => { 'x' => { 'destination' => '../outside' } }) }
      .to raise_error(SoftSort::ConfigurationError)
    expect { SoftSort::DirectoryScanner.new('/no/such/soft-sort-root', config: config) }
      .to raise_error(SoftSort::ScanError)
  end

  it 'supports CLI help, version, scan, plan, and machine-readable JSON' do
    with_directory do |dir|
      File.write(File.join(dir, 'report.pdf'), 'x')
      expect { expect(SoftSort::CLI.new(['--help']).run).to be_nil }.to output(/Usage/).to_stdout
      expect { expect(SoftSort::CLI.new(['version']).run).to be_nil }.to output(/1\.0\.0/).to_stdout
      expect { expect(SoftSort::CLI.new(['scan', dir]).run).to be_nil }.to output(/Eligible: 1/).to_stdout
      expect { expect(SoftSort::CLI.new(['plan', dir, '--format', 'json']).run).to be_nil }
        .to output(/"files"/).to_stdout
    end
  end

  it 'returns nonzero CLI errors and does not move files' do
    with_directory do |dir|
      path = File.join(dir, 'file.txt')
      File.write(path, 'unchanged')
      expect(SoftSort::CLI.new(['scan', File.join(dir, 'missing')]).run).to eq(1)
      expect(File.read(path)).to eq('unchanged')
    end
  end

  it 'organizes approved files, protects sensitive files, records history, and undoes safely' do
    with_directory do |dir|
      File.write(File.join(dir, 'invoice.txt'), 'invoice')
      File.write(File.join(dir, '.env.production'), 'secret')
      expect(SoftSort::CLI.new(['organize', dir, '--apply']).run).to be_nil
      expect(File).to exist(File.join(dir, 'Finance', 'Invoices', 'invoice.txt'))
      expect(File).to exist(File.join(dir, '.env.production'))
      expect(SoftSort::TransactionJournal.new(dir).all.last['status']).to eq('completed')
      SoftSort::UndoManager.new(dir).undo
      expect(File).to exist(File.join(dir, 'invoice.txt'))
    end
  end

  it 'detects duplicates by size and streamed SHA-256 hashing' do
    with_directory do |dir|
      File.write(File.join(dir, 'one.txt'), 'same')
      File.write(File.join(dir, 'two.txt'), 'same')
      files = SoftSort::DirectoryScanner.new(dir, config: config).scan[:files]
      groups = SoftSort::DuplicateDetector.new(dir).find(files)
      expect(groups.length).to eq(1)
      expect(groups.first[:files]).to contain_exactly('one.txt', 'two.txt')
    end
  end

  it 'rejects undo when a moved file was changed or its original path is occupied' do
    with_directory do |dir|
      File.write(File.join(dir, 'invoice.txt'), 'invoice')
      scan = SoftSort::DirectoryScanner.new(dir, config: config).scan
      plan = SoftSort::OrganizationPlanner.new(dir, config).plan(scan[:files])
      SoftSort::Executor.new(dir).execute(plan, apply: true)
      File.write(File.join(dir, 'invoice.txt'), 'new user file')
      result = SoftSort::UndoManager.new(dir).undo
      expect(result.first['status']).to eq('conflict')
    end
  end

  it 'reconciles a move completed before the journal could be finalized' do
    with_directory do |dir|
      source = File.join(dir, 'invoice.txt')
      destination = File.join(dir, 'Finance', 'Invoices', 'invoice.txt')
      File.write(source, 'invoice')
      hash = Digest::SHA256.file(source).hexdigest
      operation = { 'source' => 'invoice.txt', 'destination' => 'Finance/Invoices/invoice.txt', 'action' => 'move',
                    'status' => 'pending', 'sha256' => hash, 'size' => 7 }
      journal = SoftSort::TransactionJournal.new(dir)
      record = journal.create(dir, [operation])
      record['status'] = 'in_progress'
      journal.update(record)
      FileUtils.mkdir_p(File.dirname(destination))
      File.rename(source, destination)
      preview = SoftSort::RecoveryManager.new(dir).inspect
      expect(preview.first['completed']).to eq(1)
      applied = SoftSort::RecoveryManager.new(dir).apply
      expect(applied.first['status']).to eq('recovered')
    end
  end

  it 'reports malformed journal lines without discarding valid history' do
    with_directory do |dir|
      journal = SoftSort::TransactionJournal.new(dir)
      journal.create(dir, [])
      File.open(File.join(dir, '.soft-sort', 'transactions.jsonl'), 'a') { |file| file.write('{truncated\n') }
      expect(journal.all.length).to eq(1)
      expect(journal.warnings).to include(match(/malformed journal record/))
    end
  end
end
