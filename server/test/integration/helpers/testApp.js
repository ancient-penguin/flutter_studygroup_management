process.env.DB_PATH = ':memory:';

const app = require('../../../src/app');
const db = require('../../../src/db');

function resetDb() {
  db.exec('DELETE FROM lessons; DELETE FROM student_schedules; DELETE FROM students;');
}

module.exports = { app, db, resetDb };
