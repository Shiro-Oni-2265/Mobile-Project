const jsonServer = require('json-server');
const { initializeDatabase } = require('./database.cjs');

const port = Number(process.env.PORT || 3000);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535.');
}
const server = jsonServer.create();
server.use(jsonServer.defaults());
server.use(jsonServer.bodyParser);
server.use(jsonServer.router(initializeDatabase()));
server.listen(port, '0.0.0.0', () => {
  console.log(`NauGi API: http://localhost:${port} (backend/runtime/db.json)`);
});
