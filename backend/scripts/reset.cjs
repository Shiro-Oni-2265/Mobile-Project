const fs = require('node:fs');
const { runtimePath, seedPath } = require('./database.cjs');
const path = require('node:path');

if (!process.argv.includes('--reset')) {
  console.error('Reset replaces runtime data. Stop the API, then run npm run reset.');
  process.exitCode = 1;
} else {
  fs.mkdirSync(path.dirname(runtimePath), { recursive: true });
  fs.copyFileSync(seedPath, runtimePath);
  console.log('Explicit reset: runtime database restored from seed.json.');
}
