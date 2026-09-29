const express = require('express');
const cors = require('cors');

require('./db');
const { seedIfEmpty } = require('./seed');
const studentsRouter = require('./routes/students');
const lessonsRouter = require('./routes/lessons');

seedIfEmpty();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/students', studentsRouter);
app.use('/api/lessons', lessonsRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: err.message });
});

module.exports = app;
