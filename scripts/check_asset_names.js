#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const ASSET_EXTENSIONS = [
  '.uasset',
  '.umap',
  '.png',
  '.wav',
];

function loadRules(csvPath) {
  const text = fs.readFileSync(csvPath, 'utf8');
  const lines = text.split(/\r?\n/).filter(l => l.trim() !== '');
  const header = lines.shift().split(',').map(h => h.trim());
  const rows = lines.map(l => {
    const cols = l.split(',');
    const obj = {};
    for (let i = 0; i < header.length; i++) obj[header[i]] = (cols[i] || '').trim();
    return obj;
  });
  return rows.map(r => ({
    name: r['Name'] || '',
    prefix: (r['Prefix'] || '').toString().trim(),
    suffix: (r['Suffix'] || '').toString().trim()
  }));
}

/**
 * Find asset files under the project root.
 *
 * @param {string} root - project root
 * @param {string[] | null} includeDirs - array of directories (relative to root or absolute) to include. If null, defaults to [root/Content, root]
 * @param {string[] | null} excludeDirs - array of directories (relative to root or absolute) to exclude
 * @returns {string[]} list of asset file paths
 */
function findAssets(root, includeDirs = null, excludeDirs = null) {
  const assets = [];

  // Prepare base directories to search
  let bases = [];
  if (includeDirs && includeDirs.length) {
    bases = includeDirs.map(d => path.isAbsolute(d) ? d : path.join(root, d));
  } else {
    bases = [path.join(root, 'Content'), root];
  }

  // Normalize and resolve exclude dirs
  const excludes = (excludeDirs || []).map(d => path.isAbsolute(d) ? path.resolve(d) : path.resolve(root, d));

  for (const base of bases) {
    if (!fs.existsSync(base) || !fs.statSync(base).isDirectory()) continue;
    const stack = [base];
    while (stack.length) {
      const dir = stack.pop();

      // skip excluded directories
      const resolvedDir = path.resolve(dir);
      if (excludes.some(ex => resolvedDir === ex || resolvedDir.startsWith(ex + path.sep))) continue;

      const items = fs.readdirSync(dir);
      for (const it of items) {
        const full = path.join(dir, it);
        const st = fs.statSync(full);
        if (st.isDirectory()) {
          stack.push(full);
        } else if (st.isFile()) {
          const lower = it.toLowerCase();
          if (ASSET_EXTENSIONS.some(ext => lower.endsWith(ext))) {
            // skip files inside excluded dirs as an extra check
            const resolvedFile = path.resolve(full);
            if (excludes.some(ex => resolvedFile === ex || resolvedFile.startsWith(ex + path.sep))) continue;
            assets.push(full);
          }
        }
      }
    }
  }
  return assets;
}

function displayName(filepath) {
  return path.basename(filepath, path.extname(filepath));
}

function matchesRule(name, rule) {
  if (rule.prefix && !name.startsWith(rule.prefix)) return false;
  if (rule.suffix && !name.endsWith(rule.suffix)) return false;
  return true;
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: check_asset_names.js <project_root> <rules_csv>');
    process.exit(2);
  }
  const [root, csvPath] = args;
  if (!fs.existsSync(csvPath)) {
    console.error('Rules CSV not found:', csvPath);
    process.exit(2);
  }
  const rules = loadRules(csvPath);

  // Optional extra args: includeDirs and excludeDirs (comma-separated)
  // Usage: check_asset_names.js <project_root> <rules_csv> [include_dirs] [exclude_dirs]
  const includeArg = args[2] || null;
  const excludeArg = args[3] || null;
  const includeDirs = includeArg ? includeArg.split(',').map(s => s.trim()).filter(Boolean) : null;
  const excludeDirs = excludeArg ? excludeArg.split(',').map(s => s.trim()).filter(Boolean) : null;

  const assets = findAssets(root, includeDirs, excludeDirs);
  const issues = [];
  for (const a of assets) {
    const name = displayName(a);
    let matched = false;
    for (const r of rules) {
      if (matchesRule(name, r)) { matched = true; break; }
    }
    if (!matched) issues.push({ path: a, name });
  }
  if (issues.length) {
    console.log('Asset naming issues found:');
    for (const it of issues) console.log(` - ${it.path} ("${it.name}") does not match any naming rule`);
    process.exit(1);
  }
  console.log('No asset naming issues found.');
}

if (require.main === module) main();
