const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { once } = require('node:events');
const { test } = require('node:test');
const jsonServer = require('json-server');
const { initializeDatabase, seedPath } = require('../scripts/database.cjs');

test('seed has complete recipes and valid ingredient references', () => {
  const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  assert.ok(seed.recipes.length >= 20);
  const ids = new Set(seed.ingredients.map((ingredient) => ingredient.id));
  assert.equal(ids.size, seed.ingredients.length);
  assert.equal(new Set(seed.recipes.map((recipe) => recipe.id)).size, seed.recipes.length);
  for (const recipe of seed.recipes) {
    assert.ok(recipe.name && recipe.steps.length > 0 && recipe.items.length > 0);
    for (const item of recipe.items) assert.ok(ids.has(item.ingredientId), `${recipe.id}: ${item.ingredientId}`);
  }
});

test('initialization preserves existing data across restarts', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'naugi-init-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const database = path.join(directory, 'runtime', 'db.json');
  initializeDatabase(database);
  assert.equal(fs.readFileSync(database, 'utf8'), fs.readFileSync(seedPath, 'utf8'));
  const edited = JSON.stringify({ recipes: [{ id: 'student-edit' }], ingredients: [] });
  fs.writeFileSync(database, edited);
  initializeDatabase(database);
  assert.equal(fs.readFileSync(database, 'utf8'), edited);
});

test('real json-server GET POST PUT DELETE contract on an isolated database', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'naugi-api-'));
  const database = initializeDatabase(path.join(directory, 'db.json'));
  const app = jsonServer.create();
  app.use(jsonServer.defaults({ logger: false }));
  app.use(jsonServer.bodyParser);
  app.use(jsonServer.router(database));
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const response = await fetch(`${base}/recipes`);
  assert.equal(response.status, 200);
  const recipes = await response.json();
  assert.ok(recipes.length >= 20);
  const ingredientResponse = await fetch(`${base}/ingredients`);
  assert.equal(ingredientResponse.status, 200);
  assert.ok((await ingredientResponse.json()).length > 0);

  const payload = { ...recipes[0], id: 'contract-student-recipe', name: 'Contract recipe', sample: false };
  const request = (method, body) => ({ method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const created = await fetch(`${base}/recipes`, request('POST', payload));
  assert.equal(created.status, 201);
  assert.deepEqual(await created.json(), payload);
  const updated = { ...payload, name: 'Edited recipe' };
  const saved = await fetch(`${base}/recipes/${payload.id}`, request('PUT', updated));
  assert.equal(saved.status, 200);
  assert.deepEqual(await saved.json(), updated);
  const persisted = JSON.parse(fs.readFileSync(database, 'utf8'));
  assert.equal(persisted.recipes.find((recipe) => recipe.id === payload.id).name, updated.name);
  const removed = await fetch(`${base}/recipes/${payload.id}`, { method: 'DELETE' });
  assert.equal(removed.status, 200);
  assert.equal((await fetch(`${base}/recipes/${payload.id}`)).status, 404);
});
