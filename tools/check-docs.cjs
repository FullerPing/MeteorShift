#!/usr/bin/env node
'use strict';
/*
 * check-docs.cjs — documentation reference checker for MeteorShift (phase A2).
 *
 * Node CommonJS, no npm dependencies (fs/path only), no build step.
 *
 * What it checks, in README.md, CLAUDE.md and every .md under docs/
 * (recursively; anything under docs/ is skipped if it lives under
 * docs/archive/, which may or may not exist yet):
 *
 *   A. markdown links: every `](target)` destination that is relative.
 *   B. backticked paths: inline code spans, plus fenced code blocks, whose
 *      content is a repo-relative path under src/, tests/, tools/, docs/ or assets/.
 *
 * Output: one line per broken reference
 *   file:line: <kind> <raw> -> <resolved path> (missing)
 * Exit code 1 if anything is broken, 0 if clean. Internal errors also exit 1
 * (never a false green). Paths are reported relative to the repo root.
 *
 * Judgement calls baked into the parser (deliberate, keep in mind when triaging):
 *
 *  - Whitespace rule for Check B: a span only counts as a path candidate when the
 *    whole span contains NO whitespace. This is what keeps prose like
 *    `Shared.RefineryLayout.compute(height, width)` or backticked sentences from
 *    being treated as paths. Because of it, in fenced code blocks we treat each
 *    whitespace-separated token (after unwrapping any literal backticks) as a
 *    span, so `git add src/foo.luau tests/foo.spec.luau` lines are still checked.
 *  - Line-suffix rule: one trailing line reference is stripped before qualifying:
 *    `:12`, `:12-15`, or comma-joined ranges like `:26-42,50-69,105-135`, so
 *    `docs/native-ui.md:12` checks `docs/native-ui.md`. Only one suffix is
 *    stripped, and only when every part after the colon is numeric.
 *  - Also skipped by Check B: spans containing glob or placeholder metacharacters
 *    (* ? [ ] { } < >), e.g. `assets/native-ui/*.rbxmx` or `tests/<Name>.spec.luau`
 *    — patterns/templates, not one concrete path; and spans with leading/trailing
 *    quotes, e.g. "src/foo.luau" from code samples.
 *  - Check A skips: empty targets, `#anchor`-only targets, absolute paths
 *    (leading /), protocol-relative //, anything with a URI scheme
 *    (http:, https:, mailto:, data:, ...), a markdown link title after the path
 *    (first whitespace token wins; <angle-wrapped> targets are unwrapped), and a
 *    trailing #fragment or ?query. Backslashes are converted to forward slashes
 *    before resolving. Links inside fenced code blocks are ignored (they are
 *    example markdown, not real links).
 *  - Inline code span parsing is a simplified single-line version of the
 *    CommonMark rule (runs of ` that balance on the same line). Good enough for
 *    these docs; exotic multi-backtick spans may be missed, never invented.
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const PREFIXES = ['src/', 'tests/', 'tools/', 'docs/', 'assets/'];
const SCHEME_RE = /^[A-Za-z][A-Za-z0-9+.-]*:/; // http:, mailto:, data:, ...

// Collect the markdown files to scan: README.md, CLAUDE.md, every .md under docs/
// recursively, minus anything under docs/archive.
function collectFiles() {
  const files = [];
  for (const top of ['README.md', 'CLAUDE.md']) {
    if (fs.existsSync(path.join(ROOT, top))) files.push(top);
    else console.warn(`check-docs: warning: ${top} not found, skipped`);
  }
  const docsDir = path.join(ROOT, 'docs');
  if (fs.existsSync(docsDir) && fs.statSync(docsDir).isDirectory()) {
    const walk = (absDir) => {
      const entries = fs.readdirSync(absDir, { withFileTypes: true })
        .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
      for (const ent of entries) {
        const abs = path.join(absDir, ent.name);
        if (ent.isDirectory()) {
          if (path.relative(ROOT, abs).split(path.sep).join('/') === 'docs/archive') continue;
          walk(abs);
        } else if (ent.isFile() && ent.name.toLowerCase().endsWith('.md')) {
          files.push(path.relative(ROOT, abs).split(path.sep).join('/'));
        }
      }
    };
    walk(docsDir);
  }
  return files;
}

/** True when a line opens/closes a fenced code block (``` or ~~~, indented up to 3 spaces ok). */
function isFenceMarker(line) {
  return /^ {0,3}(`{3,}|~{3,})/.test(line);
}

/** Simplified inline code spans on one line: balanced runs of backticks. */
function inlineSpans(line) {
  const spans = [];
  const re = /(`+)([^`]*)\1(?!`)/g;
  let m;
  while ((m = re.exec(line)) !== null) spans.push(m[2]);
  return spans;
}

/** Candidate spans from a line inside a fence: unwrap literal backticks, split on whitespace. */
function fenceTokens(line) {
  return line.replace(/(`+)([^`]*)\1/g, '$2').split(/\s+/).filter(Boolean);
}

function relFromRoot(abs) {
  const rel = path.relative(ROOT, abs).split(path.sep).join('/');
  return rel === '' || rel.startsWith('..') ? abs.split(path.sep).join('/') : rel;
}

/** Check A: one markdown link destination. Returns a finding or null. */
function checkLink(file, lineNo, rawTarget) {
  let t = rawTarget.trim();
  if (t === '') return null;
  if (/^<.*>$/.test(t)) t = t.slice(1, -1);
  else if (/\s/.test(t)) t = t.split(/\s+/)[0]; // drop ` "title"` style tails
  const cut = t.search(/[?#]/); // strip trailing ?query / #fragment
  if (cut !== -1) t = t.slice(0, cut);
  if (t === '') return null; // pure anchor or query-only link
  if (SCHEME_RE.test(t) || t.startsWith('//') || t.startsWith('/')) return null;
  t = t.split('\\').join('/'); // backslash -> forward slash
  const resolved = path.resolve(path.join(ROOT, path.dirname(file)), t);
  if (fs.existsSync(resolved)) return null;
  return { file, line: lineNo, kind: 'link', raw: rawTarget, resolved: relFromRoot(resolved) };
}

/** Check B: one code span / fence token. Returns a finding or null. */
function checkCodePath(file, lineNo, span) {
  if (/\s/.test(span)) return null; // whitespace => prose or call, not a path candidate
  const lineRef = /:\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$/; // one trailing :12 / :12-15 / :26-42,50-69 suffix
  const stripped = span.replace(lineRef, '');
  const candidate = stripped.length > 0 ? stripped : span;
  if (!PREFIXES.some((p) => candidate.startsWith(p))) return null;
  if (/[?*<>\[\]{}]/.test(candidate)) return null; // glob pattern or <placeholder>, not a concrete path
  if (/^["']|["']$/.test(candidate)) return null; // quoted string from a code sample
  const resolved = path.resolve(ROOT, candidate);
  if (fs.existsSync(resolved)) return null;
  return { file, line: lineNo, kind: 'path', raw: span, resolved: relFromRoot(resolved) };
}

function scanFile(file) {
  const findings = [];
  const seen = new Set();
  const add = (f) => {
    const key = `${f.file}:${f.line}:${f.kind}:${f.raw}`;
    if (!seen.has(key)) {
      seen.add(key);
      findings.push(f);
    }
  };
  let text;
  try {
    text = fs.readFileSync(path.join(ROOT, file), 'utf8');
  } catch (err) {
    console.warn(`check-docs: warning: cannot read ${file}: ${err.message}`);
    return findings;
  }
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1); // strip BOM
  const lines = text.split(/\r\n|\r|\n/);
  let inFence = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNo = i + 1;
    if (isFenceMarker(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      for (const tok of fenceTokens(line)) {
        const f = checkCodePath(file, lineNo, tok);
        if (f) add(f);
      }
      continue;
    }
    // Check A: markdown links (images use the same syntax, so they are covered).
    const linkRe = /\]\(([^)]*)\)/g;
    let m;
    while ((m = linkRe.exec(line)) !== null) {
      const f = checkLink(file, lineNo, m[1]);
      if (f) add(f);
    }
    // Check B: inline code spans.
    for (const span of inlineSpans(line)) {
      const f = checkCodePath(file, lineNo, span);
      if (f) add(f);
    }
  }
  return findings;
}

function main() {
  const files = collectFiles();
  const findings = [];
  for (const file of files) findings.push(...scanFile(file));
  findings.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line || a.kind.localeCompare(b.kind));
  for (const f of findings) {
    console.log(`${f.file}:${f.line}: ${f.kind} ${f.raw} -> ${f.resolved} (missing)`);
  }
  if (findings.length === 0) {
    console.log(`check-docs: OK — ${files.length} file(s) scanned, no broken references`);
    process.exit(0);
  }
  console.log(`check-docs: ${findings.length} broken reference(s) across ${new Set(findings.map((f) => f.file)).size} file(s)`);
  process.exit(1);
}

try {
  main();
} catch (err) {
  console.error(`check-docs: internal error: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
}
