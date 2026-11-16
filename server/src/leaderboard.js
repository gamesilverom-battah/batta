'use strict';
// المتصدرين: قائمة لليوم وقائمة للأسبوع، بالخبرة من المباريات أونلاين (نفس خبرة المستوى).
// كل لاعب (بكود الصداقة حقه) يرسل خبرته باليوم والأسبوع، والقائمة نفسها تنحسب كل 3 ساعات بس
// (12، 3، 6، 9... بتوقيت الخليج)، وتنحفظ بملف عشان ما تضيع لو السيرفر انعاد تشغيله.
const fs = require('fs');
const path = require('path');

const TZ_HOURS = 4; // توقيت الخليج (عمان والإمارات)
const REFRESH_HOURS = 3;
const TOP = 100; // كم لاعب ينرسل بالقائمة

// اليوم والأسبوع بتوقيت الخليج (الأسبوع يبدأ الأحد، مثل التحديات بالتطبيق)
function gulf(now) { return new Date(now + TZ_HOURS * 3600e3); }
function dayKey(now) { const d = gulf(now); return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`; }
function weekKey(now) { const d = gulf(now); return dayKey(now - d.getUTCDay() * 86400e3); }

/// وقت التحديث الجاي (كل 3 ساعات بتوقيت الخليج)
function nextRefresh(now) {
  const slot = REFRESH_HOURS * 3600e3;
  const local = now + TZ_HOURS * 3600e3;
  return Math.floor(local / slot) * slot + slot - TZ_HOURS * 3600e3;
}

function createBoard({ file, now = () => Date.now() } = {}) {
  let players = {}; // fc -> { name, char, day, week, dayKey, weekKey }
  let snap = { at: 0, day: [], week: [], rank: { day: {}, week: {} } };
  let saveTimer = null;

  if (file) {
    try {
      const data = JSON.parse(fs.readFileSync(file, 'utf8'));
      players = data.players || {};
      if (data.snap) snap = data.snap;
    } catch { /* أول مرة: ما فيه ملف */ }
  }

  function save() {
    if (!file || saveTimer) return;
    saveTimer = setTimeout(() => {
      saveTimer = null;
      try {
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file + '.tmp', JSON.stringify({ players, snap }));
        fs.renameSync(file + '.tmp', file);
      } catch (e) { console.error('leaderboard save failed', e.message); }
    }, 5000);
    saveTimer.unref?.();
  }

  /// خبرة لاعب وصلت من التطبيق (مع الدخول أو بعد كل مباراة)
  function update(fc, { name, char, xpDay, xpWeek }) {
    if (!fc || !name) return;
    const t = now();
    const p = players[fc] || {};
    players[fc] = {
      name, char: char || p.char || null,
      day: Number.isFinite(xpDay) ? xpDay : 0, dayKey: dayKey(t),
      week: Number.isFinite(xpWeek) ? xpWeek : 0, weekKey: weekKey(t),
    };
    save();
  }

  /// نحسب القائمة من جديد (كل 3 ساعات)
  function refresh() {
    const t = now(), d = dayKey(t), w = weekKey(t);
    for (const [fc, p] of Object.entries(players)) if (p.weekKey !== w) delete players[fc]; // أسبوع قديم
    const list = (field, key, cur) => Object.entries(players)
      .filter(([, p]) => p[key] === cur && p[field] > 0)
      .sort((a, b) => b[1][field] - a[1][field] || a[1].name.localeCompare(b[1].name));
    const day = list('day', 'dayKey', d), week = list('week', 'weekKey', w);
    snap = {
      at: t,
      day: day.slice(0, TOP).map(([, p]) => ({ name: p.name, char: p.char, value: p.day })),
      week: week.slice(0, TOP).map(([, p]) => ({ name: p.name, char: p.char, value: p.week })),
      rank: {
        day: Object.fromEntries(day.map(([fc], i) => [fc, i + 1])),
        week: Object.fromEntries(week.map(([fc], i) => [fc, i + 1])),
      },
    };
    save();
    return snap;
  }

  /// اللي ينرسل للاعب: القائمتين، وترتيبه هو، ومتى التحديث الجاي
  function view(fc) {
    const t = now();
    return {
      t: 'leaderboard', at: snap.at, next: nextRefresh(t),
      day: snap.day, week: snap.week,
      me: { day: snap.rank.day[fc] ?? null, week: snap.rank.week[fc] ?? null },
    };
  }

  /// يحدّث القائمة الحين، وبعدها بكل 3 ساعات بالضبط
  function schedule() {
    refresh();
    let timer;
    const next = () => {
      timer = setTimeout(() => { refresh(); next(); }, nextRefresh(now()) - now() + 1000);
      timer.unref?.();
    };
    next();
    return () => clearTimeout(timer);
  }

  return { update, refresh, view, schedule, get players() { return players; } };
}

module.exports = { createBoard, nextRefresh, dayKey, weekKey };
