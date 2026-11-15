'use strict';
// صوت العملات (الغوازي): عملات معدن توصل ورا بعض: node tools/gen-coins.js [ملف الإخراج]
// (ملف لحاله عشان ما نعيد توليد باقي الأصوات)
// الإيقاع نفس أنميشن العملات بـ app/lib/coins.dart: 10 عملات، الطيران 1.6 ثانية وكل عملة 40% منه،
// فتوصل عملة كل (1 - 0.4 - 0.02) / 9 * 1.6 = 103ms، والصوت يبدأ مع أول وحدة. آخر عملة ترن أطول.
const fs = require('fs');
const path = require('path');

const RATE = 44100;
const COINS = 10, GAP = ((1 - 0.4 - 0.02) / (COINS - 1)) * 1.6;
const outFile = process.argv[2] || path.join(__dirname, '..', 'app', 'assets', 'sounds', 'coins.wav');

function wav(file, samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.max(-1, Math.min(1, v)) * 32767 | 0, i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(RATE, 24); h.writeUInt32LE(RATE * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([h, data]));
}

let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

// رنّة عملة: نغمات معدنية غير متناسقة تخفت بسرعة، وطقة خفيفة بالبداية
function clink(buf, at, base, gain, { len = 0.35, decay = 1 } = {}) {
  const start = Math.round(at * RATE);
  const partials = [[1, 1, 18], [2.76, 0.55, 26], [5.4, 0.35, 38], [8.93, 0.2, 55]];
  for (let i = 0; i < len * RATE && start + i < buf.length; i++) {
    const t = i / RATE;
    let v = 0;
    for (const [m, g, d] of partials) v += g * Math.sin(2 * Math.PI * base * m * t) * Math.exp(-t * d * decay);
    const click = t < 0.004 ? (rnd() * 2 - 1) * (1 - t / 0.004) * 0.5 : 0;
    buf[start + i] += gain * (v * Math.min(1, t / 0.0015) + click);
  }
}

// جو خفيف (انعكاسات قصيرة) عشان الرنّة الأخيرة تذوب بنعومة
function room(x) {
  const y = Float64Array.from(x);
  for (const [d, g] of [[0.019, 0.2], [0.033, 0.14], [0.051, 0.1], [0.079, 0.06], [0.12, 0.035]]) {
    const k = Math.round(d * RATE);
    for (let i = k; i < y.length; i++) y[i] += x[i - k] * g;
  }
  return y;
}

const last = (COINS - 1) * GAP;
const x = new Float64Array(Math.round((last + 0.85) * RATE));
for (let k = 0; k < COINS; k++) {
  const final = k === COINS - 1;
  // تعلى شوي مع تجمّع العملات، والأخيرة أوضح وترن أطول
  clink(x, k * GAP, 1900 + rnd() * 1300, final ? 0.55 : 0.26 + (k / COINS) * 0.12 + rnd() * 0.08, final ? { len: 0.8, decay: 0.45 } : {});
}
const y = room(x);
let peak = 0;
for (const v of y) peak = Math.max(peak, Math.abs(v));
for (let i = 0; i < y.length; i++) y[i] *= 0.6 / peak;
wav(outFile, y);
console.log(`${path.basename(outFile)}: ${COINS} coins every ${(GAP * 1000).toFixed(0)}ms, ${(y.length / RATE).toFixed(2)}s`);
