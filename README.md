# SoftSort

[![RubyGems version](https://img.shields.io/gem/v/soft-sort.svg)](https://rubygems.org/gems/soft-sort)
[![RubyGems downloads](https://img.shields.io/gem/dt/soft-sort.svg)](https://rubygems.org/gems/soft-sort)
[![CI](https://github.com/AbdulQuayyum/soft-sort/actions/workflows/ci.yml/badge.svg)](https://github.com/AbdulQuayyum/soft-sort/actions/workflows/ci.yml)
[![Ruby compatibility](https://img.shields.io/badge/Ruby-%3E%3D%203.2-CC342D?logo=ruby)](https://rubygems.org/gems/soft-sort)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

SoftSort is a local-first intelligent file organizer built with Ruby. It classifies files using configurable rules, project names, filename context, and filesystem metadata, then proposes folders or moves files when you explicitly request it.

**Current release: 1.0.0 · Ruby 3.2 or newer · MIT**

## Why SoftSort?

Downloads and shared work folders collect invoices, screenshots, archives, scripts, and project documents. SoftSort helps turn that clutter into a reviewable organization plan without a cloud service, account, database, or mandatory AI dependency.

Processing stays on your computer and works offline after installation. You choose the directory, review proposed destinations, and decide when to apply them. YAML rules let you adapt folders and project associations to your workflow. Transaction history, undo, and recovery support routine reversals and some interrupted operations; they do not replace backups.

## Features

- **Classification:** 122 unique file extensions in the default rules; file-type categories; project aliases; filename/context matching; YAML destinations; extensionless filename rules; bounded PDF, ZIP, and shebang signature checks; optional local content evidence.
- **Organization:** preview-first execution, explicit `--apply`, configurable folders, date folders, collision policies, opt-in recursion, sensitive-filename review, and preservation of existing directory structures.
- **Filesystem operations:** SHA-256 checks, transaction history, undo, recovery, advisory root-scoped locking, and same-filesystem hard-link/unlink moves that refuse an existing destination.
- **Duplicate detection:** size grouping and streamed SHA-256 hashing, without automatic duplicate deletion.
- **Automation:** polling-based watch mode, consecutive-poll stability checks that provide basic debouncing, preview output by default, and optional `watch --apply`.
- **Developer workflows:** JSON output, Ruby 3.2+ support, CI on Ubuntu/macOS/Windows, and a disabled AI provider interface. Model-based AI classification is not implemented.

Default categories cover documents/e-books, images, video, audio, spreadsheets, presentations, archives, installers, development files, configuration, fonts, design, CAD, and databases.

See [Known limitations](#known-limitations) before applying changes to important files.

## Installation

Install the published gem from [RubyGems](https://rubygems.org/gems/soft-sort):

```sh
gem install soft-sort
soft-sort version
soft-sort --help
```

Version output for this release:

```text
SoftSort 1.0.0
```

Ruby **3.2 or newer** is required. To install this release explicitly, use `gem install soft-sort -v 1.0.0`. Installation needs access to RubyGems; normal organization needs no network connection.

### Install from source

```sh
git clone https://github.com/AbdulQuayyum/soft-sort.git
cd soft-sort
bundle install
bundle exec ruby bin/soft-sort version
```

When working from the checkout, replace `soft-sort` in the examples below with `bundle exec ruby bin/soft-sort`. The CLI also runs in Windows PowerShell; use a quoted Windows path, such as `"$HOME\Downloads"`, instead of `~/Downloads`.

## macOS and rbenv troubleshooting

A successful gem installation can still leave the executable unavailable:

```text
Successfully installed soft-sort-1.0.0
zsh: command not found: soft-sort
```

Check that RubyGems and rbenv are using the same active Ruby, then refresh executable shims:

```sh
which ruby
which gem
rbenv version
gem env home
rbenv rehash
which soft-sort
soft-sort version
```

The published gem has been installed and tested on macOS with Ruby 3.3.4 and rbenv. If your active Ruby differs from the one used for installation, select the intended Ruby environment and install the gem there.

### A stale temporary shim prevents rehashing

You may see this error with the default rbenv location:

```text
rbenv: cannot rehash: ~/.rbenv/shims/.rbenv-shim exists
```

The `.rbenv-shim` file also acts as a lock during rehashing. Follow these steps only when it is stale:

1. Check for another rbenv, rehash, or gem installation/update process. Wait for any active process to finish. On macOS, inspect Activity Monitor or run `pgrep -fl 'rbenv|gem (install|update)'`.
2. Run `rbenv root` and confirm the location. For the default root, inspect the exact temporary file with `ls -l "$HOME/.rbenv/shims/.rbenv-shim"`.
3. Only after confirming that the file is stale and no process is using it, remove that single file. For the default root:

   ```sh
   rm -i "$HOME/.rbenv/shims/.rbenv-shim"
   ```

4. Run `rbenv rehash`.
5. Open a fresh terminal, or refresh command lookup with `hash -r` in Bash or `rehash` in Zsh.
6. Run `which soft-sort` and `soft-sort version` again.

If `rbenv root` reports a custom location, use its exact `shims/.rbenv-shim` path instead. Do not delete the shims directory or unrelated Ruby installations. See [rbenv's rehash implementation](https://github.com/rbenv/rbenv/blob/master/libexec/rbenv-rehash) for how this temporary lock is used.

## Quick start

Begin with a plan that does not write organization metadata or move files:

```sh
soft-sort plan ~/Downloads
```

Preview an organization transaction:

```sh
soft-sort organize ~/Downloads
```

Review the destinations, then explicitly apply a fresh plan:

```sh
soft-sort organize ~/Downloads --apply
```

Inspect history and preview a reversal:

```sh
soft-sort history ~/Downloads
soft-sort undo ~/Downloads --dry-run
```

`MOVE` in preview output means a **proposed action**. It does not mean that a file has moved:

```text
MOVE     invoice_2026.pdf -> Finance/Invoices/invoice_2026.pdf (Documents, 0.95)
MOVE     Screenshot_2026.png -> Images/Screenshots/Screenshot_2026.png (Images, 0.95)
REVIEW   mystery.xyz -> Others/mystery.xyz (Others, 0.25)
```

`plan` is read-only. `organize` without `--apply` leaves user files in place but creates/updates `.soft-sort` lock and transaction metadata. Each invocation replans the directory; applying is not approval of a saved preview. Test on disposable copies before organizing important files.

## CLI reference

Use `soft-sort --help` to list commands and options. Directory arguments default to the current directory when omitted. Quote paths containing spaces.

| Command and example | Purpose | Filesystem changes |
| --- | --- | --- |
| `soft-sort scan ~/Downloads` | Count discovered/eligible/excluded files, categories, and eligible bytes. | None. |
| `soft-sort plan ~/Downloads --format json` | Propose destinations, rules, confidence, actions, and warnings. | None. |
| `soft-sort organize ~/Downloads` | Record a proposed transaction. Add `--apply` to execute moves and create required folders. | Transaction/lock metadata even in preview; user files move only with `--apply`. |
| `soft-sort duplicates ~/Downloads --recursive` | Group eligible files with identical sizes and SHA-256 hashes. | None; duplicates are not deleted. |
| `soft-sort history ~/Downloads --limit 10` | Show the latest recorded state of each transaction. | None. |
| `soft-sort undo ~/Downloads --dry-run` | Preview reversal of the latest completed transaction. | None with `--dry-run`; otherwise restores eligible moved files and updates history. |
| `soft-sort recover ~/Downloads` | Compare incomplete transactions with current files. | None by default; `--apply` retries recoverable moves and updates history. |
| `soft-sort stats ~/Downloads --format json` | Summarize categories, planned moves, reviews, conflicts, and duplicate groups. | None. |
| `soft-sort explain ~/Downloads --format json` | Explain the first eligible planned entry in a directory. | None. |
| `soft-sort watch ~/Downloads --interval 5` | Repeatedly plan files that pass polling stability checks. | None by default; `--apply` executes organization transactions. |
| `soft-sort version` | Print the application version. | None. |

In v1.0.0, `explain` accepts a **directory**, not an individual file path. Inspect `plan --format json` for decisions about every eligible file.

### Options and their effective scope

| Option | Used by | Behavior |
| --- | --- | --- |
| `--recursive` | `scan`, `plan`, `organize`, `duplicates`, `stats`, `explain`, `watch` | Include files in subdirectories; off by default. Nested files remain protected from relocation by default. |
| `--apply` | `organize`, `recover`, `watch` | Perform the corresponding filesystem changes. |
| `--dry-run` | `undo` | Preview restoration instead of executing it. Recovery previews when `--apply` is omitted. |
| `--transaction ID` | `undo`, `recover` | Select a transaction ID from history. |
| `--limit NUMBER` | `history` | Show only the most recent NUMBER transactions; use a positive integer. |
| `--format text\|json` | Commands other than `version` | Choose report format; defaults to `text`. |
| `--config PATH` | Scanning/planning/classification commands and `watch` | Load a custom YAML file in place of the bundled rules. |
| `--date-folders` | `scan`, `plan`, `organize`, `stats`, `explain`, `watch` | Enable date folders using configured date settings. |
| `--inspect-content` | `scan`, `plan`, `organize`, `stats`, `explain`, `watch` | Enable bounded local document evidence. |
| `--collision skip\|review\|rename` | `scan`, `plan`, `organize`, `stats`, `explain`, `watch` | Override the configured collision policy. |
| `--interval SECONDS` | `watch` | Polling interval; defaults to 5 seconds. Use at least 2 seconds with the current stability check. |

Options are parsed together, but a command only uses the relevant options above. `--dry-run` does not cancel `--apply` on organization, recovery, or watch commands. `--verbose` is accepted but currently adds no output. There is no `--apply` requirement for undo: omit `--dry-run` only when you intend to restore files.

JSON reports go to stdout and ordinary CLI errors go to stderr. Watch emits one JSON object per reported polling cycle rather than one JSON array for the entire session. Inspect per-operation statuses for execution/recovery failures; a successful process exit alone does not establish that all operations completed.

## Organization examples

For a directory containing:

```text
Downloads/
├── CivicWatch-deployment.sh
├── invoice-november.pdf
├── README.md
├── project-notes.md
├── image.png
└── report.csv
```

The bundled rules can propose this layout when date folders are disabled and there are no collisions:

```text
Downloads/
├── Documents/
│   ├── Documentation/
│   │   ├── README.md
│   │   └── project-notes.md
│   └── Reports/
│       └── report.csv
├── Finance/Invoices/
│   └── invoice-november.pdf
├── Images/Photos/
│   └── image.png
└── Projects/CivicWatch/Development/Scripts/
    └── CivicWatch-deployment.sh
```

These are illustrative results from configured rules, not a guarantee of semantic understanding. Project grouping depends on aliases and type-specific destinations; the bundled rules include CivicWatch and Giffy examples. Replace them with your own projects. A loose `README.md` at the selected root may be organized; files already in subdirectories are skipped by default.

### How decisions are made

Extensions are case-insensitive. Filename tokens are matched without case sensitivity; the highest-priority contextual or project rule wins. Project rules default to priority 85. Equal top-priority matches require review. If no filename/project rule matches, enabled content evidence is considered, then the type destination is used. Unrecognized files without other evidence use `Others` and require review.

Filename rules recognize names such as `README`, `LICENSE`, `Makefile`, `Dockerfile`, and `Procfile`. For unknown/extensionless files, signature inspection reads at most 32 bytes to recognize PDF, ZIP, or a shebang. Extension recognition is not content-based MIME validation.

Confidence values are deterministic evidence scores, not calibrated probabilities. Recognized types normally score 0.80, single contextual matches 0.95, ambiguous matches 0.40, and unknown fallbacks 0.25.

## Configuration

Use `--config` to select a YAML file:

```sh
soft-sort plan ~/Downloads --config ./rules.yml
```

Start from [config/default_rules.yml](config/default_rules.yml) to retain all bundled categories. A custom file **replaces** the defaults; it is not merged into them. CLI `--date-folders`, `--inspect-content`, and `--collision` override their corresponding YAML settings.

YAML is loaded with safe parsing and aliases disabled. Date formats, date sources, collision policies, and positive content-read limits are checked; validation is not a complete schema for every field.

This complete, intentionally smaller example shows the supported structure. It recognizes only the extensions listed here:

```yaml
version: 1
organization:
  mode: hybrid
  recursive: false
  dry_run: true
  date_folders: false
  date_format: year_month
  date_source: auto
  collision_policy: skip

safety:
  follow_symlinks: false
  include_hidden: false
  overwrite: false
  protect_existing_project_structures: true

categories:
  Images:
    extensions: [jpg, jpeg, png]
    destination: Images/Photos
  Documents:
    extensions: [pdf, docx, txt]
    destination: Documents
  Spreadsheets:
    extensions: [csv, xlsx]
    destination: Documents/Spreadsheets
  Documentation:
    extensions: [md, markdown]
    destination: Documents/Documentation
  Development Scripts:
    extensions: [sh, bash, zsh, fish]
    destination: Projects/Source/Scripts
  Configuration:
    extensions: [json, yaml, yml, toml, xml, plist, ini, conf, env]
    destination: Projects/Source/Configuration

context_rules:
  - name: invoices
    keywords: [invoice, receipt]
    destination: Finance/Invoices
    priority: 100
  - name: screenshots
    keywords: [screenshot]
    destination: Images/Screenshots
    priority: 90

projects:
  civicwatch:
    aliases: [civicwatch, civic-watch]
    priority: 85
    destination: Projects/CivicWatch
    destinations:
      Development Scripts: Projects/CivicWatch/Development/Scripts
      Documentation: Projects/CivicWatch/Documentation
      Images: Projects/CivicWatch/Images
      Configuration: Projects/CivicWatch/Development/Configuration

filename_types:
  - pattern: '^README(?:\.|$)'
    category: Documentation
    destination: Documents/Documentation
  - pattern: '^(Makefile|Dockerfile|Procfile)$'
    category: Development Scripts
    destination: Projects/Source/Scripts

exclusions:
  directories: [.git, node_modules, .venv, __pycache__, vendor]
  extensions: [part, crdownload, download, tmp]

content_inspection:
  enabled: false
  max_bytes: 1048576
  min_signals: 2

ai:
  enabled: false
  provider: none
```

Use relative destinations inside the selected root, such as `Finance/Invoices`. Category/context destinations are checked for absolute paths and `..` traversal. Use the same restrictions for project destinations and filename rules; validation does not cover every nested field, so use trusted configurations and inspect the plan.

Some accepted settings are descriptive rather than CLI controls in v1.0.0: use `--recursive` to enable recursion and `--apply` to execute organization. YAML `organization.recursive` and `organization.dry_run` do not control those CLI decisions. Keep `follow_symlinks: false` and `overwrite: false`; setting them to true does not enable supported symlink traversal or overwriting.

Sensitive-file detection is built in rather than a configurable YAML pattern list. Hidden files are excluded by default. Visible filenames suggesting credentials, secrets, private keys, recovery codes, or certain certificate extensions require review and are not selected for automatic moves. `protect_existing_project_structures: true` currently skips relocation of **all** nested files, not only detected software projects.

For project grouping, add a `destinations` entry for each category you want grouped; a missing category mapping falls back to that file type's general destination. Context rules can outrank a project rule. Where an extension appears in several categories, the last category definition wins.

Collision policies never authorize overwriting:

| `collision_policy` | Behavior |
| --- | --- |
| `skip` (default) | Leave colliding files in place; the plan reports conflicts. |
| `review` | Request review rather than rename; existing or shared destination conflicts can still be reported as `conflict`. |
| `rename` | Propose an unused suffix such as `report (1).pdf`, preserving the extension. A collision introduced after planning still causes the move to fail. |

## Date-based organization

Enable folders for a preview:

```sh
soft-sort plan ~/Downloads --date-folders
```

In your rules file, configure the layout:

```yaml
organization:
  date_folders: true
  date_format: year_month_day
  date_source: modified
```

This is a section to edit in your full configuration, not a replacement rules file.

| `date_format` | Example destination |
| --- | --- |
| `year` | `Images/Photos/2026/photo.jpg` |
| `year_month` | `Images/Photos/2026/11/photo.jpg` |
| `year_month_day` | `Images/Photos/2026/11/13/photo.jpg` |

| `date_source` | v1.0.0 behavior |
| --- | --- |
| `auto` | Use filesystem birth time when available, otherwise modification time. |
| `modified` | Use modification time. |
| `created` | Use birth time; if unavailable, do not append a date folder. |
| `captured` | Accepted, but currently uses the same birth-time/modification-time fallback as `auto`. |

Full EXIF capture-date extraction is not implemented. Dates use the timezone of the timestamp Ruby receives from the filesystem; there is no timezone option. Date folders also work after a configured project destination, for example `Projects/CivicWatch/Images/2026/11/photo.jpg`. They are applied to eligible categories generally, not just images.

## Content inspection

Content evidence is disabled by default. Enable it for a preview:

```sh
soft-sort plan ~/Downloads --inspect-content
```

Supported extensions are `txt`, `md`, `markdown`, `csv`, `json`, and limited `pdf` text. The reader inspects at most `content_inspection.max_bytes` per file (default **1 MiB**) locally and skips files flagged as sensitive. It does not upload contents, execute embedded scripts, unpack archives, or modify documents.

The current implementation matches text signals for invoices, research, and contracts. At least two configured signal hits are required by default; these built-in content rules are not a general document-understanding engine. Filename/context rules take precedence over content evidence.

PDF support is a bounded raw-byte text check, **not a full PDF parser**. Compressed, encoded, encrypted, and scanned PDFs may yield no useful evidence. DOCX content extraction and OCR are unavailable; recognizing `.docx` as a document does not imply reading its contents. PNG dimension reading exists internally, but full image metadata and capture dates are not integrated into classification.

## Watch mode

Preview stable files using polling:

```sh
soft-sort watch ~/Downloads
soft-sort watch ~/Downloads --recursive --interval 5
```

To execute organization transactions, explicitly opt in:

```sh
soft-sort watch ~/Downloads --apply --interval 5
```

Test apply mode on a disposable directory first. Stop watching with **Ctrl-C**.

The watcher compares size and modification time between consecutive polls. Its fixed internal stability threshold is 2 seconds; the CLI defaults to a 5-second interval. Keep `--interval` at 2 or higher: shorter intervals do not accumulate stability time in the current implementation. There is no YAML watch section or CLI stability-window option.

These checks provide basic debouncing, not proof that a writer has finished. Temporary extensions such as `.part`, `.crdownload`, `.download`, and `.tmp` are excluded. Hidden SoftSort metadata is excluded, and default nested-file protection prevents recursive relocation of generated folder contents.

Unchanged files can be reported again on later polls. There is no persistent event queue or completed-event deduplication. Keep the default structure protection enabled; avoid watching directories that other processes can rename or restructure during apply operations.

## Undo and recovery

Transactions are stored in `DIRECTORY/.soft-sort/transactions.jsonl`. Writes append JSON records, flush, and call `fsync`. History displays the latest state per transaction; retain this metadata if you want to undo or reconcile operations.

### History and undo

```sh
soft-sort history ~/Downloads --limit 10
soft-sort undo ~/Downloads --dry-run
soft-sort undo ~/Downloads
```

**Undo executes by default.** It selects the latest `completed` transaction unless an ID is supplied:

```sh
soft-sort undo ~/Downloads --transaction TRANSACTION_ID --dry-run
soft-sort undo ~/Downloads --transaction TRANSACTION_ID
```

Replace `TRANSACTION_ID` with an ID from history. Undo checks the current destination's SHA-256 before restoring it and refuses an occupied original path. Missing or changed files produce conflicts. The dry-run preview lists proposed restorations but does not perform all execution-time checks. Empty organization folders are left in place.

Recovered or otherwise non-`completed` transactions require an explicit transaction ID for undo. Inspect their operation states first; partial or interrupted undo is not comprehensively reconciled.

### Recovery after interruption

Start with a read-only inspection after a terminal interruption, restart, or failed move:

```sh
soft-sort recover ~/Downloads
soft-sort recover ~/Downloads --format json
soft-sort recover ~/Downloads --transaction TRANSACTION_ID
```

Only after inspecting the individual operations, request changes:

```sh
soft-sort recover ~/Downloads --transaction TRANSACTION_ID --apply
```

`soft-sort recover ~/Downloads --apply` processes all eligible incomplete transactions. This includes planned transactions recorded by `organize` previews, so it can execute moves that have not previously been applied. Prefer selecting a reviewed transaction.

Recovery compares source/destination presence and stored SHA-256 hashes. An unchanged source with a missing destination can be retried; a missing source with a matching destination can be recognized as moved. If both paths exist—including an interrupted hard-link/unlink move—they remain a conflict requiring manual inspection. Do not delete either path merely because filenames or contents appear to match.

Missing files, unexpected symlinks, corrupted journals, and interrupted undo may need manual handling. Preserve a copy of the journal and affected files before attempting repairs. The reader preserves valid records around malformed JSON lines, but CLI diagnostics do not expose every journal warning. Review per-operation states rather than relying solely on the transaction summary.

## Safety and privacy

- **Local operation:** no network classification, telemetry, cloud uploads, or mandatory AI service is implemented. Reports and the journal contain file paths, hashes, and metadata; treat them as private.
- **Preview behavior:** `plan` and watch preview leave files untouched. Organization previews also record local transaction metadata. `undo` needs `--dry-run` for a preview.
- **Sensitive-file review:** built-in filename patterns flag likely credentials and keys. Detection is heuristic, not a scan for all secrets. Hashing/reporting can still inspect or disclose metadata about eligible files.
- **No-replace movement:** execution rechecks source content and uses hard-link creation followed by source unlink. Existing destinations are refused; duplicate detection never deletes files.
- **Symlink and root checks:** scanning excludes symlink entries; execution checks leaf symlinks and destination paths. These checks do not establish complete protection against symlinked parent directories or concurrent path substitution.
- **Concurrency:** advisory locks serialize cooperating SoftSort mutation commands for a root and journal writes. They do not stop other applications from modifying files or directories.
- **Recovery records:** journaling and SHA-256 checks assist undo/reconciliation. They do not guarantee recovery after every interruption or power loss.

Use trusted rules and an ordinary directory on a filesystem supporting hard links and file locks. Avoid applying operations inside trees containing symlinked parent paths or while other processes restructure the directory. Cross-filesystem link attempts fail instead of falling back to copy-and-delete.

## Platform support

The [v1.0.0 CI run](https://github.com/AbdulQuayyum/soft-sort/actions/runs/43429177237) passed all six jobs:

| Platform | Ruby 3.2 | Ruby 3.3 |
| --- | --- | --- |
| Ubuntu CI | Passed | Passed |
| macOS CI | Passed | Passed |
| Windows CI | Passed | Passed |

The published gem has also been installed and tested on macOS using Ruby 3.3.4 with rbenv.

CI covers the hosted runner configurations, not every filesystem or OS setup. Hard-link permissions, advisory locking, symlinks, filename rules, case sensitivity, timestamps, and `fsync` behavior vary. Network mounts, removable media, or restricted filesystems may reject operations. Ruby versions newer than this matrix satisfy the gem requirement but are not established as tested by this run.

## Known limitations

- No full PDF parser, DOCX extraction, OCR, or archive-content inspection.
- No full EXIF extraction or HEIC/WebP metadata/capture-date support; image metadata is limited to internal PNG dimensions.
- AI is interface-only and disabled by default. Enabling a provider name does not supply a model or working classification integration.
- `explain` reports only the first eligible entry of a directory.
- Recursive protection skips all nested files by default; it is broader than software-project detection.
- Watch stability is based on consecutive samples; it cannot perfectly detect active writers, and repeated reports are possible.
- Full subprocess crash-boundary and concurrency testing remains incomplete. Recovery does not automatically resolve the both-paths-present hard-link case or every interrupted undo.
- Some recovery summary states and process exit codes do not expose all unresolved per-file conditions. Inspect detailed reports and verify files.
- Parent-directory symlink substitution and concurrent path races are not comprehensively eliminated.
- Journal synchronization does not include a complete directory/power-loss durability protocol. Durability depends on the operating system and filesystem.
- Cross-filesystem moves are rejected through hard-link failure, with no copy/delete fallback.
- Classification uses rules and limited evidence, so destinations can be wrong. There is no generic YAML schema enforcement for every accepted field.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
gem build soft-sort.gemspec
ruby script/installed_gem_smoke.rb soft-sort-1.0.0.gem
```

RSpec uses temporary fixtures rather than personal directories. Tests cover scanning/exclusions, unsupported birth timestamps, classification, configured projects, sensitive files, deterministic plans, collisions, normal organization/undo, selected recovery behavior, malformed journal records, dates, bounded content evidence, PNG dimensions, and watch previews.

[GitHub Actions](.github/workflows/ci.yml) runs RSpec, RuboCop, CLI help/version checks, gem builds, and isolated installed-gem smoke tests on Ruby 3.2/3.3 across Ubuntu, macOS, and Windows. The smoke test installs the built gem into a temporary gem environment.

The main components are:

```text
bin/soft-sort                 executable CLI
lib/soft_sort/scanning        traversal and filesystem metadata
lib/soft_sort/classification  type, context, content, and project rules
lib/soft_sort/planning        destinations, dates, and collisions
lib/soft_sort/execution       organization, undo, and recovery
lib/soft_sort/storage         JSONL journal and root locking
lib/soft_sort/watching        polling watcher
lib/soft_sort/reporting       text and JSON reports
config/default_rules.yml      bundled YAML rules
spec/                        temporary-fixture tests
```

## Contributing

1. Fork [the repository](https://github.com/AbdulQuayyum/soft-sort).
2. Create a feature branch.
3. Implement a focused change and update documentation or tests as appropriate.
4. Run `bundle exec rspec` and `bundle exec rubocop`.
5. Open a pull request describing behavior, validation, and any filesystem safety implications.

Keep classification independent of mutation, use disposable fixtures for filesystem tests, and preserve journal/configuration compatibility where safe.

## License

SoftSort is available under the [MIT License](LICENSE).

## Links

- [GitHub repository](https://github.com/AbdulQuayyum/soft-sort)
- [RubyGems package](https://rubygems.org/gems/soft-sort)
- [Releases](https://github.com/AbdulQuayyum/soft-sort/releases)
- [Issues](https://github.com/AbdulQuayyum/soft-sort/issues)
- [Changelog](CHANGELOG.md)
