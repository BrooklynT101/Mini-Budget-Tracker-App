// this file will be for serving the Node/Express server iteself, serving api routes
// for database interactions (using pg) for routes like /transactions

const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (_req, res) => res.send('Hello from API VM'));
app.get('/health', (_req, res) => res.json({ ok: true }));
app.get('/getTransactions', (_req, res) => {
    // Here I will eventually fetch data from a database
    res.json([
        { id: 1, amount: 100, description: 'Test Transaction 1' },
        { id: 2, amount: 200, description: 'Test Transaction 2' }
    ]);
});
app.post('/addTransaction', (req, res) => {
    const newTransaction = req.body;
    // Here I will eventually save the new transaction to a database
    res.status(201).json(newTransaction);
});

app.listen(port, () => console.log(`API listening on :${port}`));
