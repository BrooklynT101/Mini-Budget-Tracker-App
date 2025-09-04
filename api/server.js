// this file will be for serving the Node/Express server iteself, serving api routes
// for database interactions (using pg) for routes like /transactions

// Express api for transactions
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const app = express();
const port = process.env.PORT || 3000;

// allow browser from web VM via localhost:8080
app.use(cors({ origin: ['http://localhost:8080'] }));
app.use(express.json()); // for parsing application/json bodies

// DB config (Host only default, might look into override via system env vars)
const pool = new Pool({
	host: process.env.DB_HOST || '10.10.10.10',
	user: process.env.DB_USER || 'user',
	password: process.env.DB_PASSWORD || 'supersecretpassword',
	database: process.env.DB_NAME || 'budget'
});

app.get('/health', (_req, res) => res.json({ ok: true }));

// GET /transactions -> list latest
app.get('/transactions', async (_req, res) => {
	try {
		const r = await pool.query(
			'SELECT id, occurred_at, description, amount_cents FROM transactions ORDER BY occurred_at DESC'
		);
		res.json(r.rows);
	} catch (e) {
		console.error(e);
		res.status(500).json({ error: 'db_query_failed' });
	}
});


// POST /transactions -> create
app.post('/transactions', async (req, res) => {
	try {
		const { description, amount_cents } = req.body;
		if (typeof description !== 'string' || !Number.isInteger(amount_cents)) {
			return res.status(400).json({ error: 'bad_request' });
		}
		const r = await pool.query(
			'INSERT INTO transactions(description, amount_cents) VALUES ($1,$2) RETURNING id, occurred_at, description, amount_cents',
			[description, amount_cents]
		);
		res.status(201).json(r.rows[0]);
	} catch (e) {
		console.error(e);
		res.status(500).json({ error: 'db_insert_failed' });
	}
});

app.listen(port, () => console.log(`API listening on :${port}`));
