#!/usr/bin/env node
// Syntax-check a Workflow-tool script by reproducing the harness's wrapping:
// `export const meta` becomes a plain const and the body runs inside an async
// function (which is why top-level `return`/`await` are legal in these files).
const fs = require('node:fs');
const vm = require('node:vm');

const file = process.argv[2];
if (!file) { console.error('usage: check-workflow.js <script.workflow.js>'); process.exit(2); }
const src = fs.readFileSync(file, 'utf8').replace(/^export\s+const\s+meta/m, 'const meta');
try {
  new vm.Script(`(async () => {\n${src}\n})`, { filename: file });
  console.log(`OK ${file}`);
} catch (e) {
  console.error(`SYNTAX ERROR in ${file}: ${e.message}`);
  process.exit(1);
}
