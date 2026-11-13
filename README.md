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
soft-sort recover ~/Downloads
soft-sort recover ~/Downloads --apply
soft-sort stats ~/Downloads --format json
soft-sort explain ~/Downloads/example.pdf
soft-sort plan ~/Downloads --date-folders --inspect-content
soft-sort organize ~/Downloads --collision rename --apply
soft-sort watch ~/Downloads --interval 5
```

`scan` reports discovered, eligible, excluded, categorized, and sized files. `plan` reports source, proposed destination, type, context, rule, confidence, action, and warnings. `organize` previews by default and performs approved moves only with `--apply`. `--recursive` is opt-in. `--format json` emits only JSON on stdout; diagnostics go to stderr.

Recovery is read-only by default. It reconciles unfinished journal transactions against the actual source and destination files using stored SHA-256 identities. Use `recover --apply` only after reviewing the preview. Recovery refuses symlinks, missing identities, collisions, modified files, and operations outside the selected root.

Example:

```text
MOVE     invoice_2026.pdf -> Finance/Invoices/invoice_2026.pdf (Documents, 0.95)
MOVE     Screenshot_2026.png -> Images/Screenshots/Screenshot_2026.png (Images, 0.95)
REVIEW   mystery.xyz -> Others/mystery.xyz (Others, 0.25)
```

## How classification works

Type classification is YAML-driven and covers documents/e-books, images/graphics, spreadsheets, presentations, video, audio, archives, installers, fonts, design, CAD, databases, development languages, documentation, shell scripts, and configuration. It recognizes Markdown (`md`, `markdown`), shell scripts (`sh`, `bash`, `zsh`, `fish`), development formats (`rb`, `py`, `go`, `js`, `jsx`, `ts`, `tsx`, `sql`), configuration (`json`, `yaml`, `yml`, `toml`, `xml`, `plist`, `ini`, `conf`, `env`), and common format extensions. Extensionless files can use safe filename rules or a bounded signature read for PDF, ZIP, and shebang headers; SoftSort never executes them. Unknown extensions use `Others` and require review.

Context classification tokenizes case-insensitive filenames using common separators. Rules are ordered by priority. The precedence is contextual rule, file type, then unknown fallback. Equal-priority contextual matches are marked `review` rather than chosen arbitrarily. Confidence is a deterministic evidence score, not a statistical probability.

Projects are configured with aliases and optional type destinations. For example, a `CivicWatch-deployment.sh` file can resolve to `Projects/CivicWatch/Development/Scripts/`. Recursive mode protects files already inside an established directory tree by default, so existing project source and manifests are not scattered.

Date folders are disabled by default and can be enabled with `--date-folders` or YAML. Supported formats are `year`, `year_month`, and `year_month_day`; the default date source is a reliable available timestamp, falling back to modification time. Collision handling defaults to conservative review/conflict behavior. Set `organization.collision_policy` to `rename` only when deterministic `(1)`, `(2)` suffixes are desired.

Bounded local content evidence is disabled by default. `--inspect-content` enables small, offline reads for plain text, Markdown, CSV, JSON, and PDF text; protected files are never inspected. The implementation does not execute documents, extract arbitrary archives, or upload content.

`watch` uses polling and is preview-only unless `--apply` is supplied. It waits for files to remain size/timestamp-stable before planning them and inherits all scanner, project, sensitive-file, lock, collision, and journal safeguards. Stop it with Ctrl-C. The optional AI provider interface is disabled by default (`ai.enabled: false`) and has no network implementation; deterministic classification remains the only active fallback.

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
projects:
  civicwatch:
    aliases: [civicwatch, civic-watch]
    destination: Projects/CivicWatch
    destinations:
      Development Scripts: Projects/CivicWatch/Development/Scripts
      Development: Projects/CivicWatch/Development
exclusions:
  directories: [node_modules]
  extensions: [part, crdownload]
```

Destinations must be relative and cannot contain `..`. Safe YAML loading rejects aliases and invalid configuration. Default exclusions include hidden entries, symlinks, `.git`, `node_modules`, `.venv`, `vendor/bundle`, `__pycache__`, and incomplete-download extensions (`.part`, `.crdownload`, `.download`, `.tmp`).

## Safety guarantees and limitations

SoftSort defaults to a dry run. With `organize --apply`, it creates only required destination folders and moves approved, non-sensitive, non-conflicting files. It verifies SHA-256 identity immediately before each move, uses a same-filesystem no-replace hard-link/unlink operation, refuses existing destinations, records append-only JSONL transactions under `.soft-sort`, and supports verified undo and recovery. It never follows symbolic links, leaves the selected root, executes scanned files, unpacks archives, transmits metadata, overwrites or deletes files, or moves protected credentials by default.

Duplicate detection uses size grouping and streamed SHA-256 hashing but never deletes duplicates. Journal recovery is supported for interrupted move transactions; power-loss durability remains subject to the host filesystem's fsync guarantees. Image metadata currently provides bounded PNG dimensions only; full EXIF, HEIC/WebP capture dates, DOCX extraction, OCR, and remote/local model execution remain disabled until they can be implemented with platform-specific safety guarantees. Extension/name classification can be wrong and should be reviewed.

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
gem build soft-sort.gemspec
ruby script/installed_gem_smoke.rb soft-sort-1.0.0.gem
```

The test suite uses temporary directories rather than personal folders and covers empty/single/nested scans, hidden files, symlinks, exclusions, temporary downloads, missing roots, extension/context classification, priority ambiguity, deterministic planning, already-organized files, configuration safety, CLI output/errors, JSON validity, read-only behavior, execution, undo, recovery reconciliation, malformed journals, date folders, collision renaming, bounded content evidence, PNG metadata, and disabled AI fallback.

## Platform support and release status

SoftSort requires Ruby 3.2 or newer. The source is designed for macOS, Linux, and Windows; hosted CI is configured for Ruby 3.2 and 3.3 on Ubuntu, macOS, and Windows. Local verification has been performed on macOS Apple Silicon. Hosted CI results must be checked before claiming a platform-specific release guarantee.

Same-filesystem organization uses no-replace hard-link/unlink operations. Cross-filesystem moves are rejected rather than copied and deleted. Locking, timestamp precision, symlink behavior, hard-link permissions, and power-loss durability depend on the host filesystem. Watch mode is polling-based and preview-only unless `--apply` is supplied.

The release artifact is built with `gem build soft-sort.gemspec`. The installed-gem smoke test verifies the executable outside the source load path. No publishing workflow is included; publishing requires explicit manual authorization.

## Contributing and license

Keep the scanner and classifiers free of filesystem mutation, add focused temporary-fixture tests for changes, and run RSpec and RuboCop before submitting a change. SoftSort is released under the MIT License; see [LICENSE](LICENSE).
