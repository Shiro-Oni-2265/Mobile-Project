const fs = require('node:fs');
const path = require('node:path');

const backendRoot = path.resolve(__dirname, '..');
const seedPath = path.join(backendRoot, 'seed.json');
const runtimePath = path.join(backendRoot, 'runtime', 'db.json');

function initializeDatabase(destination = runtimePath) {
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  try {
    // Exclusive copy: a normal restart never replaces user edits.
    fs.copyFileSync(seedPath, destination, fs.constants.COPYFILE_EXCL);
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
  }
  return destination;
}

module.exports = { initializeDatabase, runtimePath, seedPath };
