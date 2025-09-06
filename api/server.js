// this file will be for serving the Node/Express server iteself, serving api routes
// for database interactions (using pg) for routes like /transactions

const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

// Use a connection pool, client didn't work well with multiple requests
const pool = new Pool({
  host: process.env.DB_HOST || '192.168.56.13',
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASS || 'appsecret',
  database: process.env.DB_NAME || 'budget',
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Simple health check endpoint
app.get('/health', (req, res) => res.json({ ok: true }));

// Transactions endpoints (gets all from database)
app.get('/transactions', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, occurred_at, description, amount_cents FROM transactions ORDER BY occurred_at DESC'
    );
    res.json(rows);
  } catch (e) {
    console.error('GET /transactions failed:', e);
    res.status(500).json({ error: 'db_error' });
  }
});

// Create a new transaction
app.post('/transactions', async (req, res) => {
  const { description, amount_cents } = req.body || {};
  if (!description || typeof amount_cents !== 'number') {
    return res.status(400).json({ error: 'bad_request' });
  }
  try {
    const { rows } = await pool.query(
      'INSERT INTO transactions(description, amount_cents) VALUES($1,$2) RETURNING id, occurred_at, description, amount_cents',
      [description, amount_cents]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    console.error('POST /transactions failed:', e);
    res.status(500).json({ error: 'db_error' });
  }
});

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`API listening on ${PORT}`));

// error handling: don't crash the process; surface errors in logs.
process.on('unhandledRejection', err => console.error('unhandledRejection', err));
process.on('uncaughtException', err => console.error('uncaughtException', err));
process.on('warning', err => console.warn('warning', err));
