const express = require('express');
const lessonRepository = require('../repositories/lessonRepository');
const studentRepository = require('../repositories/studentRepository');

const router = express.Router();

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const STATUSES = ['completed', 'inProgress', 'scheduled', 'canceled', 'noShow'];

/// "2026-09" -> { from: "2026-09-01", to: "2026-09-31" }
/// 말일을 31로 두어도 문자열 비교라 해당 월만 정확히 걸린다.
function monthRange(month) {
  return { from: `${month}-01`, to: `${month}-31` };
}

router.get('/', (req, res) => {
  const { studentId, month } = req.query;
  let { from, to } = req.query;

  if (month) {
    if (!MONTH_RE.test(month)) {
      return res.status(400).json({ error: 'month must be YYYY-MM' });
    }
    ({ from, to } = monthRange(month));
  }
  if (from && !DATE_RE.test(from)) {
    return res.status(400).json({ error: 'from must be YYYY-MM-DD' });
  }
  if (to && !DATE_RE.test(to)) {
    return res.status(400).json({ error: 'to must be YYYY-MM-DD' });
  }

  res.json(lessonRepository.list({ studentId, from, to }));
});

router.get('/:id', (req, res) => {
  const lesson = lessonRepository.getById(req.params.id);
  if (!lesson) return res.status(404).json({ error: 'Lesson not found' });
  res.json(lesson);
});

/// NOT NULL 컬럼을 모두 검사한다. 예전에는 startTime/endTime을 빠뜨리면
/// SQLite 제약 위반이 500으로 새어 나갔다.
function validateLesson(body, { partial = false } = {}) {
  const { studentId, date, startTime, endTime, amount, status } = body;
  if (!partial) {
    if (!studentId || !date || !startTime || !endTime || amount == null) {
      return 'studentId, date, startTime, endTime, amount are required';
    }
  }
  if (studentId !== undefined && !studentRepository.getById(studentId)) {
    return 'Student not found';
  }
  if (date !== undefined && !DATE_RE.test(date)) return 'date must be YYYY-MM-DD';
  if (startTime !== undefined && !TIME_RE.test(startTime)) return 'startTime must be HH:mm';
  if (endTime !== undefined && !TIME_RE.test(endTime)) return 'endTime must be HH:mm';
  if (startTime !== undefined && endTime !== undefined && endTime <= startTime) {
    return 'endTime must be after startTime';
  }
  if (amount !== undefined && (typeof amount !== 'number' || amount < 0)) {
    return 'amount must be a non-negative number';
  }
  if (status !== undefined && !STATUSES.includes(status)) {
    return `status must be one of ${STATUSES.join(', ')}`;
  }
  return null;
}

router.post('/', (req, res) => {
  const error = validateLesson(req.body);
  if (error) return res.status(400).json({ error });

  const { studentId, date, startTime, endTime, note, amount, status } = req.body;
  const lesson = lessonRepository.create({
    studentId, date, startTime, endTime, note, amount, status,
  });
  res.status(201).json(lesson);
});

router.put('/:id', (req, res) => {
  const error = validateLesson(req.body, { partial: true });
  if (error) return res.status(400).json({ error });

  const updated = lessonRepository.update(req.params.id, req.body);
  if (!updated) return res.status(404).json({ error: 'Lesson not found' });
  res.json(updated);
});

router.patch('/:id/settlement', (req, res) => {
  const { settled } = req.body;
  if (typeof settled !== 'boolean') {
    return res.status(400).json({ error: 'settled must be a boolean' });
  }
  const updated = lessonRepository.setSettled(req.params.id, settled);
  if (!updated) return res.status(404).json({ error: 'Lesson not found' });
  res.json(updated);
});

router.delete('/:id', (req, res) => {
  const removed = lessonRepository.remove(req.params.id);
  if (!removed) return res.status(404).json({ error: 'Lesson not found' });
  res.status(204).send();
});

module.exports = router;
module.exports.monthRange = monthRange;
module.exports.validateLesson = validateLesson;
