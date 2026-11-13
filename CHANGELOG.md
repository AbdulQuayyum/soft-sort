# Changelog

## 1.0.0 - 2026-11-13

- Expanded YAML-driven file recognition across development, documentation,
  configuration, design, font, CAD, database, e-book, and media formats.
- Added bounded extensionless filename/signature recognition without execution.
- Added project type subfolders and recursive protection for established trees.
- Added regression coverage for CivicWatch-style project scripts, sensitive
  files, unknown formats, and recursive safety.
- Added explicit dry-run and `organize --apply` execution.
- Added protected-file detection, SHA-256 pre-move validation, no-overwrite moves, and required-folder creation.
- Added durable JSONL transaction history and verified undo support.
- Added duplicate detection, statistics, and explainability commands.
- Added expanded safety, execution, duplicate, and undo tests.
- Documented intentionally disabled content, EXIF, AI, watch, and automatic recovery features.
- Added root-scoped locking, synchronized/fsynced JSONL journal writes, per-operation progress persistence, and filesystem reconciliation for interrupted moves.
- Added read-only and apply-mode `recover` command with hash-verified recovery reporting.
- Hardened moves and undo with same-filesystem no-replace hard-link/unlink operations and symlink rejection.
- Added configurable year, year/month, and year/month/day destination folders.
- Added opt-in bounded local content evidence for text, Markdown, CSV, JSON, and PDF files.
- Added explicit `skip`, `review`, and deterministic `rename` collision policies.
- Added advanced classification and collision regression coverage.
- Added polling-based, stability-aware `watch` mode with preview-only defaults.
- Added disabled-by-default AI provider interfaces and bounded PNG metadata support.
- Added GitHub Actions CI for Ruby/RSpec/RuboCop, CLI smoke tests, gem builds,
  and macOS/Linux/Windows runner coverage.
- Added isolated installed-gem smoke verification and release support documentation.

## 0.1.0 - 2026-10-16

- Added read-only scanning, hybrid classification, planning, text output, and JSON reporting.
