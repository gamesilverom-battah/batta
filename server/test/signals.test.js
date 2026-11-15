'use strict';
const test = require('node:test');
const assert = require('node:assert');

process.env.PORT = '0';
process.env.DEAL_PAUSE_MS = '0';
process.env.BOT_DELAY_MS = '0';
const { server } = require('../src/server');
const E = require('../src/engine');
const WebSocket = require('ws');

const ready = () => new Promise((r) => (server.listening ? r() : server.once('listening', r)));

async function client() {
  const ws = new WebSocket(`ws://localhost:${server.address().port}`);
  await new Promise((r) => ws.once('open', r));
  const inbox = [], waiters = [];
  ws.on('message', (raw) => {
    const m = JSON.parse(raw);
    const i = waiters.findIndex((w) => w.test(m));
    if (i >= 0) waiters.splice(i, 1)[0].resolve(m);
    else inbox.push(m);
  });
  return {
    ws,
    send: (m) => ws.send(JSON.stringify(m)),
    next: (test) => {
      const i = inbox.findIndex(test);
      if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
      return new Promise((resolve) => waiters.push({ test, resolve }));
    },
  };
}

test('engine: no-signals match never allows signals', () => {
  const g = E.createMatch({ players: 6, signals: false });
  for (let seat = 0; seat < 6; seat++) {
    assert.strictEqual(E.viewFor(g, seat).signals, false);
    assert.strictEqual(E.viewFor(g, seat).canSignal, false);
    assert.strictEqual(E.viewFor(g, seat).canSignalJoker, false);
  }
  assert.strictEqual(E.viewFor(E.createMatch({ players: 6 }), 0).signals, true); // الافتراضي مع إشارة
});

test('server: practice without signals, and search keeps the two options apart', async () => {
  await ready();
  const p = await client();
  p.send({ t: 'practice', mode: 6, name: 'مهند', signals: false });
  const room = await p.next((m) => m.t === 'room');
  assert.strictEqual(room.signals, false);
  const st = await p.next((m) => m.t === 'state');
  assert.strictEqual(st.view.signals, false);

  // واحد يدور «بدون إشارة» والثاني «مع إشارة»: كل واحد بغرفة
  const a = await client(), b = await client();
  a.send({ t: 'search', mode: 6, score: 54, name: 'أ', signals: false });
  b.send({ t: 'search', mode: 6, score: 54, name: 'ب' });
  const ja = await a.next((m) => m.t === 'joined');
  const jb = await b.next((m) => m.t === 'joined');
  assert.notStrictEqual(ja.code, jb.code);
  // وثالث «بدون إشارة» ينضم لغرفة الأول
  const c = await client();
  c.send({ t: 'search', mode: 6, score: 54, name: 'ج', signals: false });
  const jc = await c.next((m) => m.t === 'joined');
  assert.strictEqual(jc.code, ja.code);
  for (const x of [p, a, b, c]) x.ws.close();
  server.close();
});
