# SoftSort

SoftSort is a local-first, offline Ruby CLI that scans a selected directory, explains deterministic organization decisions, and—when explicitly requested—moves approved files into generated folders. It never follows symbolic links, silently overwrites files, or deletes files.

## Requirements and installation

Ruby 3.2 or newer is required. SoftSort has no runtime service, database, cloud, or AI dependency.

```sh
git clone <repository>
cd soft-sort
bundle install
bundle exec ruby bin/soft-sort --help
```

The same commands work in macOS/Linux shells and Windows PowerShell (use `ruby bin/soft-sort ...` in place of an installed executable).

## CLI usage

```sh
soft-sort --help
soft-sort version
soft-sort scan ~/Downloads
soft-sort plan ~/Downloads
soft-sort plan ~/Downloads --recursive
soft-sort plan ~/Downloads --format json
soft-sort plan ~/Downloads --config ./rules.yml --verbose
soft-sort organize ~/Downloads --apply
soft-sort duplicates ~/Downloads --recursive --format json
soft-sort history ~/Downloads --limit 20
soft-sort undo ~/Downloads --dry-run
soft-sort stats ~/Downloads --format json
soft-sort explain ~/Downloads/example.pdf
```

`scan` reports discovered, eligible, excluded, categorized, and sized files. `plan` reports source, proposed destination, type, context, rule, confidence, action, and warnings. `organize` previews by default and performs approved moves only with `--apply`. `--recursive` is opt-in. `--format json` emits only JSON on stdout; diagnostics go to stderr.

Example:

```text
MOVE     invoice_2026.pdf -> Finance/Invoices/invoice_2026.pdf (Documents, 0.95)
MOVE     Screenshot_2026.png -> Images/Screenshots/Screenshot_2026.png (Images, 0.95)
REVIEW   mystery.xyz -> Others/mystery.xyz (Others, 0.25)
```

## How classification works

Type classification uses the extension only; it does not claim MIME or content verification. Supported groups include Images, Documents, Spreadsheets, Presentations, Videos, Audio, Archives, Source Code, and Installers. Unknown extensions use `Others` and require review.

Context classification tokenizes case-insensitive filenames using common separators. Rules are ordered by priority. The precedence is contextual rule, file type, then unknown fallback. Equal-priority contextual matches are marked `review` rather than chosen arbitrarily. Confidence is a deterministic evidence score, not a statistical probability.

Default destinations include `Images/Photos`, `Documents`, `Media/Videos`, `Media/Audio`, `Archives`, `Projects/Source`, `Installers`, and contextual destinations such as `Finance/Invoices`, `Images/Screenshots`, and `Documents/Reports`.

## Configuration

Use safe YAML with these top-level sections:

```yaml
version: 1
organization:
  mode: hybrid
  recursive: false
  dry_run: true
safety:
  follow_symlinks: false
  include_hidden: false
categories:
  Documents:
    extensions: [pdf, doc, docx, txt]
    destination: Documents
context_rules:
  - name: invoices
    keywords: [invoice, receipt]
    destination: Finance/Invoices
    priority: 100
exclusions:
  directories: [node_modules]
  extensions: [part, crdownload]
```

Destinations must be relative and cannot contain `..`. Safe YAML loading rejects aliases and invalid configuration. Default exclusions include hidden entries, symlinks, `.git`, `node_modules`, `.venv`, `vendor/bundle`, `__pycache__`, and incomplete-download extensions (`.part`, `.crdownload`, `.download`, `.tmp`).

## Safety guarantees and limitations

SoftSort defaults to a dry run. With `organize --apply`, it creates only required destination folders and moves approved, non-sensitive, non-conflicting files. It verifies SHA-256 identity immediately before each move, refuses existing destinations, records append-only JSONL transactions under `.soft-sort`, and supports verified undo. It never follows symbolic links, leaves the selected root, executes scanned files, unpacks archives, transmits metadata, overwrites or deletes files, or moves protected credentials by default.

Duplicate detection uses size grouping and streamed SHA-256 hashing but never deletes duplicates. Content extraction, image EXIF inspection, watch mode, AI providers, and automatic crash recovery remain disabled until they can be implemented with platform-specific safety guarantees. Extension/name classification can be wrong and should be reviewed.

## Project structure

```text
bin/soft-sort                 CLI executable
lib/soft_sort/scanning        filesystem scanning and metadata
lib/soft_sort/classification  type/context/rule classification
lib/soft_sort/planning        destination and conflict planning
lib/soft_sort/reporting       text and JSON output
config/default_rules.yml      default rules
spec/                         automated tests with temporary fixtures
```

## Testing and development

```sh
bundle exec rspec
bundle exec rubocop
bundle exec ruby bin/soft-sort scan ./test-files
bundle exec ruby bin/soft-sort plan ./test-files --recursive --format json
```

The test suite uses temporary directories rather than personal folders and covers empty/single/nested scans, hidden files, symlinks, exclusions, temporary downloads, missing roots, extension/context classification, priority ambiguity, deterministic planning, already-organized files, configuration safety, CLI output/errors, JSON validity, and read-only behavior.

## Roadmap

Milestone 2 will add an explicit `organize --apply` command, collision-safe moves, journaling, crash recovery, and undo. Milestone 3 will add SHA-256 duplicate detection, date organization, image/document metadata, and improved project recognition. Milestone 4 may add optional automation and user feedback. Milestone 5 covers RubyGems, Homebrew, cross-platform release testing, and an optional desktop interface.

## Contributing and license

Keep the scanner and classifiers free of filesystem mutation, add focused temporary-fixture tests for changes, and run RSpec and RuboCop before submitting a change. SoftSort is released under the MIT License; see [LICENSE](LICENSE).
