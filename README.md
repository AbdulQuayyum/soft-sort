# SoftSort

SoftSort is a local-first, offline Ruby CLI that scans a user-selected directory and creates a deterministic, read-only organization plan. It classifies files from extensions and filename context, then proposes relative destinations without creating folders, moving files, deleting files, or reading complete file contents.

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
```

`scan` reports discovered, eligible, excluded, categorized, and sized files. `plan` reports source, proposed destination, type, context, rule, confidence, action, and warnings. `--recursive` is opt-in. `--format json` emits only JSON on stdout; diagnostics go to stderr. `--verbose` is accepted for forward-compatible CLI diagnostics.

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

Milestone 0.1.0 is entirely read-only. It never follows symbolic links, leaves the selected root, executes scanned files, unpacks archives, transmits metadata, creates folders, moves or renames files, deletes duplicates, or modifies contents. Existing destination collisions and planned collisions are reported.

This release does not implement file execution, transaction journals, undo, duplicate hashing, content extraction, image metadata, directory watching, or AI classification. Extension/name classification can be wrong and should be reviewed before any future execution milestone.

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
