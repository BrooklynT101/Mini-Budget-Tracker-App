// this file will be for serving the Node/Express server iteself, serving api routes
// for database interactions (using pg) for routes like /transactions

const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (_req, res) => res.send('Hello from API VM'));
app.get('/health', (_req, res) => res.json({ ok: true }));

app.listen(port, () => console.log(`API listening on :${port}`));
