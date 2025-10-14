#!/usr/bin/env node
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function usageAndExit() {
  console.log('Usage: node check_cs_format.js <ROOT_DIR> [INCLUDE_DIRS] [EXCLUDE_DIRS]');
  console.log('INCLUDE_DIRS / EXCLUDE_DIRS are comma-separated paths relative to ROOT_DIR');
  process.exit(2);
}

const rootDir = process.argv[2];
if (!rootDir) usageAndExit();
const includeDirs = (process.argv[3] || '').split(',').map(s => s.trim()).filter(Boolean);
const excludeDirs = (process.argv[4] || '').split(',').map(s => s.trim()).filter(Boolean);

function normalizeList(list) {
  return list.map(p => path.resolve(rootDir, p));
}

const resolvedIncludes = includeDirs.length ? normalizeList(includeDirs) : [path.resolve(rootDir)];
const resolvedExcludes = normalizeList(excludeDirs);

function isExcluded(filePath) {
  for (const ex of resolvedExcludes) {
    // If the exclude path is a prefix of the file path
    if (filePath === ex || filePath.startsWith(ex + path.sep)) return true;
  }
  return false;
}

function collectCsFiles(startDir) {
  const results = [];
  function walk(dir) {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch (e) {
      return; // ignore missing/unreadable dirs
    }
    for (const ent of entries) {
      const full = path.join(dir, ent.name);
      if (isExcluded(full)) continue;
      if (ent.isDirectory()) {
        walk(full);
      } else if (ent.isFile() && full.endsWith('.cs')) {
        results.push(full);
      }
    }
  }
  walk(startDir);
  return results;
}

// Quick check that dotnet exists
const dotnetCheck = spawnSync('dotnet', ['--version'], { encoding: 'utf8' });
if (dotnetCheck.error) {
  console.error('dotnet not available in PATH. Cannot run C# formatting checks.');
  process.exit(2);
}

let anyFailed = false;
let filesFailed = [];
const seen = new Set();

for (const inc of resolvedIncludes) {
  const files = collectCsFiles(inc);
  for (const file of files) {
    // Avoid duplicates when include dirs overlap
    if (seen.has(file)) continue;
    seen.add(file);

    //console.log('Checking C# formatting for:', path.relative(rootDir, file));

    const args = ['format', 'whitespace', '--verify-no-changes', '--folder', '--include', file];
    const r = spawnSync('dotnet', args, { stdio: 'pipe', cwd: rootDir, encoding: 'utf8' });
    if (r.error) {
      console.error('Failed to run dotnet for file:', file, r.error);
      anyFailed = true;
      filesFailed.push(file);
    } else if (r.status !== 0) {
      anyFailed = true;
      filesFailed.push(file);
    }
  }
}

if (anyFailed) {
  console.error('C# formatting issues detected. Run `dotnet format whitespace --folder --include <file>` or `dotnet format` on the project.');
  for (const f of filesFailed) {
    console.error(' -', path.relative(rootDir, f));
  }
  process.exit(1);
} else {
  console.log('C# files formatted correctly.');
  process.exit(0);
}
