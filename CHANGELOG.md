# Changelog

## 1.0.2 — 2026-11-07

- Render standalone local images from Windows paths, file URLs and document-relative paths, with proportional resizing and missing-file messages.
- Expand tables to the document width with readable empty cells, consistent padding and alternating row colors.
- Render `[TOC]` as clickable heading links, including duplicate headings.
- Recognize YAML front matter and display it in a metadata panel.
- Display footnote and link definitions separately, preserve empty placeholders, and resolve explicit reference links and footnote jumps.
- Add offline display math (`$$`) for letters, primes, scripts, fractions, square roots and common symbols. Unsupported TeX commands display their source with a notice.

Validation: 42 isolated Godot 4.7 editor checks passed; rendered screenshots inspected. The addon remains read-only. Full LaTeX, remote/inline images, automatic footnote numbering and shortcut reference links are not supported.

## 1.0.1 — 2026-11-07

- Align bullet and numbered list markers with the first line of item text.
- Render bold and italic emphasis around inline code correctly.
- Keep unindented continuation lines within the preceding list item.

Validated with Godot 4.7 on Windows using parser checks and actual editor rendering.
