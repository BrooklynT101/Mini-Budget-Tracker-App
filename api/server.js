// this file will be for serving the Node/Express server iteself, serving api routes
// for database interactions (using pg) for routes like /transactions

import express from 'express';
import pkg from 'pg';
import fs from 'node:fs';
const { Pool } = pkg;

import dotenv from 'dotenv';
dotenv.config({ path: '../env/prod.api.env' });     // shared

const app = express();
app.use(express.json());

// Use a connection pool, client didn't work well with multiple requests
const pool = new Pool({
	host: process.env.DB_HOST,
	user: process.env.DB_USER,
	password: process.env.DB_PASS || process.env.DB_PASSWORD,
	database: process.env.DB_NAME,
	// CGPT suggested to add this to solve a Aurora SSL connection issue:
	port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 5432,
	ssl: {
		ca: fs.readFileSync('/etc/ssl/certs/rds-combined-ca-bundle.pem').toString(),
		rejectUnauthorized: true
	}
});

// Simple health check endpoint - checks if server is running
app.get('/health', (req, res) => res.json({ ok: true }));

// Transactions endpoints (gets all from database)
app.get('/transactions', async (req, res) => {
	try {
		const query = `
      SELECT
        id,
        occurred_at,
        COALESCE(name, description) AS name,
        description,
        amount_cents
      FROM transactions
      ORDER BY occurred_at DESC, id DESC
    `;
		const { rows } = await pool.query(query);
		res.json(rows);
	} catch (e) {
		console.error('GET /transactions failed:', e);
		res.status(500).json({ error: 'db_error' });
	}
});

// Create a new transaction
app.post('/transactions', async (req, res) => {
	const { name, description, amount_cents, occurred_at } = req.body || {};

	// Basic validation
	// Name Check
	if (!name || typeof name !== 'string' || name.length > 100) {
		return res.status(400).json({ error: 'invalid name' });
	}

	// Description Check - description can be null
	if (description != null && (typeof description !== 'string' || description.length > 500)) {
		return res.status(400).json({ error: 'invalid description' });
	}

	// Amount Check - must be an integer in cents
	if (typeof amount_cents !== 'number' || !Number.isInteger(amount_cents)) {
		return res.status(400).json({ error: 'invalid amount_cents' });
	}

	// Occurred At Check - can be null, defaults to NOW() in DB
	if (occurred_at != null && isNaN(Date.parse(occurred_at))) {
		return res.status(400).json({ error: 'invalid occurred_at' });
	}

	try {
		const occurredAt = occurred_at ? new Date(occurred_at) : null;
		const query = `
      INSERT INTO transactions (name, description, amount_cents, occurred_at)
      VALUES ($1, $2, $3, COALESCE($4, NOW()))
      RETURNING id, occurred_at, name, description, amount_cents
    `;
		const parameters = [name, description, amount_cents, occurredAt];
		const { rows } = await pool.query(query, parameters);
		res.status(201).json(rows[0]);
	} catch (e) {
		console.error('POST /transactions failed:', e);
		res.status(500).json({ error: 'db_error: insertion failed' });
	}
});

// Delete transaction
app.delete('/transactions/:id', async (req, res) => {
	const id = Number(req.params.id);
	// Basic validation
	if (!Number.isInteger(id)) return res.status(400).json({ error: 'invalid_id' });

	const { rowCount } = await pool.query('DELETE FROM transactions WHERE id = $1', [id]);
	if (rowCount === 0) return res.status(404).json({ error: 'not_found' });
	res.status(204).end();
});

// Start the server
const PORT = process.env.PORT || 3000;
// previous line: app.listen(PORT, '192.168.56.11', () => console.log(`API listening on ${PORT}`));
app.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));


// error handling: don't crash the process; surface errors in logs.
process.on('unhandledRejection', err => console.error('unhandledRejection', err));
process.on('uncaughtException', err => console.error('uncaughtException', err));
process.on('warning', err => console.warn('warning', err));
