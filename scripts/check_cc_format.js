#!/usr/bin/env node
'use strict';

// checks C/C++ formatting using clang-format
// Usage: node check_cc_format.js [rootDir]

const { spawnSync } = require('child_process');
const { resolve } = require('path');
const fs = require('fs');

const root = process.argv[2] ? resolve(process.argv[2]) : process.cwd();
// Optional include/exclude args (comma-separated list of directories relative to project root)
const includeArg = process.argv[3] || '';
const excludeArg = process.argv[4] || '';

function parseDirList(arg) {
  if (!arg) return [];
  return arg.split(',').map(s => s.trim()).filter(Boolean);
}

function resolveDirs(dirList) {
  return dirList.map(d => resolve(root, d));
}

function findFiles(dir) {
  const exts = ['.cpp', '.cc', '.c', '.h', '.hpp', '.inl'];
  const results = [];
  (function walk(d) {
    let entries;
    try {
      entries = fs.readdirSync(d, { withFileTypes: true });
    } catch (e) {
      return;
    }
    for (const ent of entries) {
      const p = resolve(d, ent.name);
      if (ent.isDirectory()) {
        // skip node_modules and .git for speed
        if (ent.name === 'node_modules' || ent.name === '.git') continue;
        walk(p);
      } else if (ent.isFile()) {
        if (exts.includes(require('path').extname(ent.name).toLowerCase())) {
          results.push(p);
        }
      }
    }
  })(dir);
  return results;
}

function checkClangFormatAvailable() {
  const which = spawnSync('clang-format', ['--version'], { encoding: 'utf8' });
  return which.status === 0;
}


// --- MAIN ---
if (!checkClangFormatAvailable()) {
  console.log('clang-format not found in PATH. Skipping C/C++ formatting check.');
  process.exit(1);
}

// Prepare include/exclude directories
const includeDirs = resolveDirs(parseDirList(includeArg));
const excludeDirs = resolveDirs(parseDirList(excludeArg));

let files = [];
if (includeDirs.length) {
  // Collect files from each include dir (only if the dir exists)
  for (const d of includeDirs) {
    try {
      const st = fs.statSync(d);
      if (st.isDirectory()) {
        files = files.concat(findFiles(d));
      }
    } catch (e) {
      // ignore missing include dirs
      // console.warn(`Include dir not found: ${d}`);
    }
  }
  // dedupe
  files = Array.from(new Set(files));
} else {
  files = findFiles(root);
}

// Apply exclude filtering
if (excludeDirs.length) {
  files = files.filter(f => {
    for (const ex of excludeDirs) {
      // ensure directory match: ex + path.sep is a prefix of f, or f === ex
      if (f === ex) return false;
      if (f.startsWith(ex + require('path').sep)) return false;
    }
    return true;
  });
}
if (!files.length) {
  console.log('No C/C++ source files found.');
  process.exit(0);
}

const mismatches = [];
for (const f of files) {
  // run clang-format -style=file on the file and compare to the file contents
  const cf = spawnSync('clang-format', ['-style=file', f], { encoding: 'utf8' });
  if (cf.status !== 0) {
    console.error(`clang-format failed on ${f}`);
    mismatches.push({ file: f, reason: 'clang-format exit' });
    continue;
  }
  const formatted = cf.stdout;
  let original;
  try {
    original = fs.readFileSync(f, 'utf8');
  } catch (e) {
    mismatches.push({ file: f, reason: 'read error' });
    continue;
  }
  if (formatted !== original) {
    mismatches.push({ file: f });
  }
}

if (mismatches.length) {
  console.log('C/C++ formatting issues detected (use clang-format -i).');
  for (const m of mismatches) {
    console.log(` - ${m.file}${m.reason ? ' (' + m.reason + ')' : ''}`);
  }
  process.exit(1);
} else {
  console.log('C/C++ files formatted correctly.');
  process.exit(0);
}
