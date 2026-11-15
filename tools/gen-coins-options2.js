'use strict';
// خيارات قريبة من صوت العملات الحالي (عملات معدن تطيح ورا بعض وتتسارع): node tools/gen-coins-options2.js <مجلد>
// كل خيار يغيّر شي واحد: د أدفأ وأوطى، هـ عملات أكثر، و عملات أقل وأوضح، ز نفس الحالي بس آخر عملة ترن أطول بجو خفيف
const fs = require('fs');
const path = require('path');

const RATE = 44100;
const out = process.argv[2] || path.join(__dirname, '..', 'app', 'build');
fs.mkdirSync(out, { recursive: true });

function wav(name, x) {
  let peak = 0;
  for (const v of x) peak = Math.max(peak, Math.abs(v));
  const data = Buffer.alloc(x.length * 2);
  x.forEach((v, i) => data.writeInt16LE(Math.round((v / peak) * 0.6 * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(RATE, 24); h.writeUInt32LE(RATE * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(out, name), Buffer.concat([h, data]));
}

// نفس رنّة الصوت الحالي (tools/gen-coins.js)، مع تحكم بالطول وكمية الحدّة
function clink(buf, at, base, gain, { len = 0.35, bright = 1, decay = 1 } = {}) {
  const start = Math.round(at * RATE);
  const partials = [[1, 1, 18], [2.76, 0.55 * bright, 26], [5.4, 0.35 * bright, 38], [8.93, 0.2 * bright, 55]];
  for (let i = 0; i < len * RATE && start + i < buf.length; i++) {
    const t = i / RATE;
    let v = 0;
    for (const [m, g, d] of partials) v += g * Math.sin(2 * Math.PI * base * m * t) * Math.exp(-t * d * decay);
    const click = t < 0.004 ? (rnd() * 2 - 1) * (1 - t / 0.004) * 0.5 * bright : 0;
    buf[start + i] += gain * (v * Math.min(1, t / 0.0015) + click);
  }
}

let seed = 11;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

// جو خفيف (انعكاسات قصيرة) لخيار ز
function room(x) {
  const y = Float64Array.from(x);
  for (const [d, g] of [[0.019, 0.22], [0.033, 0.16], [0.051, 0.11], [0.079, 0.07], [0.12, 0.04]]) {
    const k = Math.round(d * RATE);
    for (let i = k; i < y.length; i++) y[i] += x[i - k] * g;
  }
  return y;
}

const times7 = [0, 0.07, 0.13, 0.2, 0.26, 0.33, 0.42];

// د: أدفأ وأوطى (عملات أكبر)
{
  seed = 11;
  const x = new Float64Array(Math.round(0.9 * RATE));
  times7.forEach((t, k) => clink(x, t, 1300 + rnd() * 800, k === 6 ? 0.5 : 0.32 + rnd() * 0.12, { bright: 0.6, len: 0.45 }));
  wav('عملة_د_أدفأ.wav', x);
}

// هـ: عملات أكثر (11) وأكثف، نفس الطول تقريباً
{
  seed = 11;
  const x = new Float64Array(Math.round(0.95 * RATE));
  const times = [0, 0.045, 0.085, 0.13, 0.17, 0.21, 0.25, 0.3, 0.34, 0.39, 0.47];
  times.forEach((t, k) => clink(x, t, 1900 + rnd() * 1300, k === times.length - 1 ? 0.5 : 0.26 + rnd() * 0.12));
  wav('عملة_هـ_أكثر.wav', x);
}

// و: عملات أقل (4) وأوضح، كل وحدة تبين لحالها
{
  seed = 11;
  const x = new Float64Array(Math.round(0.8 * RATE));
  [0, 0.11, 0.21, 0.33].forEach((t, k) => clink(x, t, 2100 + rnd() * 900, k === 3 ? 0.55 : 0.42, { len: 0.4 }));
  wav('عملة_و_أقل_وأوضح.wav', x);
}

// ز: نفس الحالي، بس آخر عملة ترن أطول، مع جو خفيف
{
  seed = 11;
  const x = new Float64Array(Math.round(1.2 * RATE));
  times7.forEach((t, k) => clink(x, t, 1900 + rnd() * 1300, k === 6 ? 0.55 : 0.32 + rnd() * 0.12, k === 6 ? { len: 0.75, decay: 0.45 } : {}));
  wav('عملة_ز_رنة_أطول.wav', room(x));
}
console.log('wrote 4 options to', out);
