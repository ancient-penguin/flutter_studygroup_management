const express = require('express');
const studentRepository = require('../repositories/studentRepository');

const router = express.Router();

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

router.get('/', (req, res) => {
  res.json(studentRepository.listAll());
});

router.get('/:id', (req, res) => {
  const student = studentRepository.getById(req.params.id);
  if (!student) return res.status(404).json({ error: 'Student not found' });
  res.json(student);
});

/// 주간 반복 규칙 배열 검증. weekday는 1=월 ... 7=일.
function validateSchedules(schedules) {
  if (schedules === undefined) return null;
  if (!Array.isArray(schedules)) return 'schedules must be an array';
  for (const s of schedules) {
    if (!Number.isInteger(s.weekday) || s.weekday < 1 || s.weekday > 7) {
      return 'schedules[].weekday must be an integer 1-7';
    }
    if (typeof s.startTime !== 'string' || !TIME_RE.test(s.startTime)) {
      return 'schedules[].startTime must be HH:mm';
    }
    if (!Number.isInteger(s.durationMin) || s.durationMin <= 0) {
      return 'schedules[].durationMin must be a positive integer';
    }
  }
  return null;
}

/// students 테이블의 NOT NULL 컬럼을 모두 검사한다.
function validateStudent(body, { partial = false } = {}) {
  const { name, initial, school, grade, subject, hourlyRate, schedules } = body;
  if (!partial) {
    if (!name || !subject || hourlyRate == null) {
      return 'name, subject, hourlyRate are required';
    }
    if (initial == null || school == null || grade == null) {
      return 'initial, school, grade are required';
    }
  }
  if (hourlyRate !== undefined && (typeof hourlyRate !== 'number' || hourlyRate < 0)) {
    return 'hourlyRate must be a non-negative number';
  }
  return validateSchedules(schedules);
}

router.post('/', (req, res) => {
  const error = validateStudent(req.body);
  if (error) return res.status(400).json({ error });

  const { name, initial, school, grade, subject, hourlyRate, schedules } = req.body;
  const student = studentRepository.create({
    name, initial, school, grade, subject, hourlyRate, schedules,
  });
  res.status(201).json(student);
});

router.put('/:id', (req, res) => {
  const error = validateStudent(req.body, { partial: true });
  if (error) return res.status(400).json({ error });

  const updated = studentRepository.update(req.params.id, req.body);
  if (!updated) return res.status(404).json({ error: 'Student not found' });
  res.json(updated);
});

router.delete('/:id', (req, res) => {
  const removed = studentRepository.remove(req.params.id);
  if (!removed) return res.status(404).json({ error: 'Student not found' });
  res.status(204).send();
});

module.exports = router;
module.exports.validateSchedules = validateSchedules;
module.exports.validateStudent = validateStudent;
