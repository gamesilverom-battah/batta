'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createBoard, nextRefresh, weekKey } = require('../src/leaderboard');

const H = 3600e3;
// الأحد 15 نوفمبر 2026، الساعة 10 الصبح بتوقيت الخليج (6 الصبح UTC)
const SUN_10AM = Date.UTC(2026, 10, 15, 6);

test('the list only changes every 3 hours (gulf time)', () => {
  assert.strictEqual(nextRefresh(SUN_10AM), Date.UTC(2026, 10, 15, 8)); // 12 الظهر بتوقيت الخليج
  assert.strictEqual(nextRefresh(Date.UTC(2026, 10, 15, 20, 30)), Date.UTC(2026, 10, 15, 23)); // 12:30 بالليل -> 3 الفجر
  let t = SUN_10AM;
  const b = createBoard({ now: () => t });
  b.update('AAAAAA', { name: 'سالم', char: 'aslam', xpDay: 100, xpWeek: 300 });
  b.refresh();
  b.update('BBBBBB', { name: 'ريم', char: 'fares', xpDay: 250, xpWeek: 250 });
  assert.deepStrictEqual(b.view('BBBBBB').day.map((e) => e.name), ['سالم']); // ريم تطلع مع التحديث الجاي بس
  b.refresh();
  const v = b.view('BBBBBB');
  assert.deepStrictEqual(v.day.map((e) => [e.name, e.value]), [['ريم', 250], ['سالم', 100]]);
  assert.deepStrictEqual(v.week.map((e) => [e.name, e.value]), [['سالم', 300], ['ريم', 250]]);
  assert.deepStrictEqual(v.me, { day: 1, week: 2 });
  assert.strictEqual(v.day[0].fc, undefined); // أكواد اللاعبين ما تنرسل
});

test('a new day empties the day list, a new week (sunday) empties both', () => {
  let t = SUN_10AM + 4 * 24 * H; // الخميس
  const b = createBoard({ now: () => t });
  b.update('AAAAAA', { name: 'سالم', xpDay: 80, xpWeek: 500 });
  t += 24 * H; // الجمعة
  const v = (b.refresh(), b.view('AAAAAA'));
  assert.deepStrictEqual(v.day, []);
  assert.strictEqual(v.week[0].value, 500);
  t += 2 * 24 * H; // الأحد: أسبوع جديد
  assert.notStrictEqual(weekKey(t), weekKey(t - 24 * H));
  b.refresh();
  assert.deepStrictEqual(b.view('AAAAAA').week, []);
});

test('saved to a file and read back after a restart', async () => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'lb-')), 'leaderboard.json');
  const t = SUN_10AM;
  const a = createBoard({ file, now: () => t });
  a.update('AAAAAA', { name: 'سالم', char: 'aslam', xpDay: 40, xpWeek: 40 });
  a.refresh();
  await new Promise((r) => setTimeout(r, 5300)); // الحفظ بعد 5 ثواني
  const b = createBoard({ file, now: () => t });
  assert.strictEqual(b.view('AAAAAA').day[0].name, 'سالم');
  assert.strictEqual(b.view('AAAAAA').me.day, 1);
});
