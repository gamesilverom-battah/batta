'use strict';
// الرجوع للدور: البوت يلعب مكان اللي فصل، يرجع بنفس المقعد، أو يخسر، وبالأونلاين يدخل بديل
const test = require('node:test');
const assert = require('node:assert');

process.env.PORT = '0';
process.env.BOT_DELAY_MS = '0';
process.env.DEAL_PAUSE_MS = '0';
process.env.TRICK_PAUSE_MS = '0';
process.env.SEARCH_MS = '600';
process.env.SUB_AFTER_MS = '300';
process.env.CANCEL_MS = '400';
process.env.TRUMP_MS = '200';
process.env.TURN_MS = '200'; // اللاعب الموجود يخلص وقته بسرعة والسيرفر يلعب عنه
const { server, rooms, cleanName } = require('../src/server');
const WebSocket = require('ws');

const ready = () => new Promise((r) => (server.listening ? r() : server.once('listening', r)));

function player() {
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  ws.msgs = [];
  ws.on('message', (raw) => ws.msgs.push(JSON.parse(raw)));
  ws.say = (m) => ws.send(JSON.stringify(m));
  ws.last = (t) => [...ws.msgs].reverse().find((m) => m.t === t);
  return new Promise((r) => ws.on('open', () => r(ws)));
}

const until = (fn, ms = 4000) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => { clearInterval(poll); reject(new Error('timeout')); }, ms);
  const poll = setInterval(() => {
    const v = fn();
    if (v) { clearTimeout(timer); clearInterval(poll); resolve(v); }
  }, 10);
});

// لاعبين اثنين يدوّرون (4 لاعبين) والبوتات تكمّل. كل اختبار باختيارات غير عشان ما يتداخلون
async function onlineGame(opts) {
  const a = await player(), b = await player();
  a.say({ t: 'search', mode: 4, name: 'أ', ...opts });
  await until(() => a.last('room'));
  b.say({ t: 'search', mode: 4, name: 'ب', ...opts });
  await until(() => a.last('room')?.started && b.last('joined'));
  const code = a.last('joined').code;
  return { a, b, code, room: rooms.get(code), tokenA: a.last('joined').token };
}

test('names are cut to 10 characters, and Khalfan is short', async () => {
  assert.strictEqual(cleanName('١٢٣٤٥٦٧٨٩٠ABC'), '١٢٣٤٥٦٧٨٩٠');
  assert.strictEqual(cleanName('خلفان التفق زيادة'), 'خلفان التف');
  assert.strictEqual(cleanName('  '), 'لاعب');
});

test('a player who drops is played by the bot, and can come back to the same seat', async () => {
  await ready();
  const { a, b, code, room, tokenA } = await onlineGame({ score: 34 });
  const seatA = room.seats.findIndex((s) => s && s.token === tokenA);
  a.close();
  await until(() => !room.seats[seatA].ws);
  // الباقين يوصلهم تنبيه
  const gone = await until(() => b.last('seatEvent'));
  assert.deepStrictEqual([gone.kind, gone.seat, gone.name], ['gone', seatA, 'أ']);
  // الدور ما يوقف عند مقعده: البوت يلعب مكانه
  const before = JSON.stringify(room.game.hands[seatA]);
  await until(() => JSON.stringify(room.game.hands[seatA]) !== before || room.game.round > 1, 8000);
  // يفتح اللعبة من جديد: يسأل، ويرجع
  const a2 = await player();
  a2.say({ t: 'rejoinCheck', code, token: tokenA });
  const info = await until(() => a2.last('rejoinInfo'));
  assert.strictEqual(info.ok, true);
  assert.strictEqual(info.team, seatA % 2);
  a2.say({ t: 'join', code, token: tokenA, name: 'أ' });
  await until(() => a2.last('joined'));
  assert.ok(room.seats[seatA].ws);
  await until(() => b.last('seatEvent')?.kind === 'back');
  a2.close(); b.close();
});

test('saying no loses the seat, and a searcher can take it after agreeing', async () => {
  const { a, b, code, room, tokenA } = await onlineGame({ score: 34, signals: false });
  const seatA = room.seats.findIndex((s) => s && s.token === tokenA);
  a.close();
  const a2 = await player();
  a2.say({ t: 'forfeit', code, token: tokenA });
  await until(() => a2.last('forfeited'));
  a2.say({ t: 'rejoinCheck', code, token: tokenA });
  assert.strictEqual((await until(() => a2.last('rejoinInfo'))).ok, false);
  // واحد جديد يدوّر بنفس الاختيارات: يطلع له الدور الشغّال
  const c = await player();
  // شخصية محد ماخذها بالغرفة
  const free = ['medhat', 'fares', 'sulaiman', 'aslam', 'abdo'].find((id) => !room.seats.some((x) => x.char === id));
  c.say({ t: 'search', mode: 4, score: 34, signals: false, name: 'بديل', char: free });
  const offer = await until(() => c.last('subOffer'));
  assert.strictEqual(offer.code, code);
  assert.strictEqual(offer.seat, seatA);
  assert.strictEqual(offer.scores.length, 2);
  c.say({ t: 'subAccept', code, seat: seatA, name: 'بديل', char: free });
  await until(() => c.last('joined'));
  assert.strictEqual(room.seats[seatA].name, 'بديل');
  assert.strictEqual(room.seats[seatA].char, free);
  const sub = await until(() => b.msgs.find((m) => m.t === 'seatEvent' && m.kind === 'sub'));
  assert.deepStrictEqual([sub.name, sub.old], ['بديل', 'أ']);
  // الأصلي لو رجع: مقعده راح
  a2.say({ t: 'join', code, token: tokenA, name: 'أ' });
  await until(() => a2.last('seatLost'));
  a2.close(); b.close(); c.close();
});

test('after two minutes a waiting searcher is offered the seat, and declining searches normally', async () => {
  const { a, b, room, tokenA, code } = await onlineGame({ score: 54 });
  const seatA = room.seats.findIndex((s) => s && s.token === tokenA);
  a.close();
  // واحد يدوّر من قبل ما ينفتح المقعد (ينفتح بعد SUB_AFTER_MS)
  const c = await player();
  c.say({ t: 'search', mode: 4, score: 54, name: 'ج' });
  await until(() => c.last('room')?.search);
  const offer = await until(() => c.last('subOffer'));
  assert.strictEqual(offer.seat, seatA);
  c.say({ t: 'subDecline', code, seat: seatA });
  // رفض: يكمل بحثه، والمقعد ما يتعرض عليه مرة ثانية
  const d = await player();
  d.say({ t: 'search', mode: 4, score: 54, name: 'د', noSub: true });
  await until(() => d.last('room'));
  assert.strictEqual(c.msgs.filter((m) => m.t === 'subOffer').length, 1);
  // اللاعب الأصلي يقدر يرجع ما دام ما دخل بديل
  const a2 = await player();
  a2.say({ t: 'join', code, token: tokenA, name: 'أ' });
  await until(() => a2.last('joined'));
  assert.ok(room.seats[seatA].ws);
  assert.strictEqual(room.seats[seatA].open, false);
  a2.close(); b.close(); c.close(); d.close();
});

test('when every player drops and nobody comes back, the game is cancelled', async () => {
  const { a, b, code, tokenA } = await onlineGame({ score: 34, mode: 6 });
  a.close(); b.close();
  await until(() => !rooms.has(code));
  const a2 = await player();
  a2.say({ t: 'rejoinCheck', code, token: tokenA });
  assert.strictEqual((await until(() => a2.last('rejoinInfo'))).ok, false);
  a2.say({ t: 'join', code, token: tokenA, name: 'أ', inGame: true });
  assert.strictEqual((await until(() => a2.last('seatLost'))).cancelled, true);
  a2.close();
  server.close();
});
