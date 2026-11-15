'use strict';
// خيارات لصوت العملات (الغوازي) عشان المستخدم يسمع ويختار: node tools/gen-coins-options.js <مجلد الإخراج>
// أ: عملة وحدة تطيح على الطاولة وترن وتتدحرج. ب: كومة عملات تنصب على بعض. ج: رنّة مكافأة لامعة (لعب).
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

let seed = 21;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

// رنّة معدن: نغمات غير متناسقة (مثل العملة الحقيقية) تخفت كل وحدة بسرعتها، وطقة بالبداية
function ring(buf, at, base, gain, decay = 1) {
  const s0 = Math.round(at * RATE);
  const parts = [[1, 1, 9], [2.32, 0.7, 13], [3.87, 0.45, 18], [5.6, 0.3, 26], [7.9, 0.18, 34]];
  for (let i = 0; i < 1.2 * RATE && s0 + i < buf.length; i++) {
    const t = i / RATE;
    let v = 0;
    for (const [m, g, d] of parts) v += g * Math.sin(2 * Math.PI * base * m * t + m) * Math.exp(-t * d * decay);
    const click = t < 0.003 ? (rnd() * 2 - 1) * (1 - t / 0.003) * 0.6 : 0;
    buf[s0 + i] += gain * (v * Math.min(1, t / 0.0008) + click);
  }
}

// أ: عملة وحدة: تطيح، تنط مرتين أخف، وبعدها تدور على الطاولة (رنّات سريعة تتقارب)
{
  const x = new Float64Array(Math.round(1.1 * RATE));
  const f = 2600;
  ring(x, 0, f, 1, 0.8);
  ring(x, 0.11, f * 1.004, 0.45, 1.2);
  ring(x, 0.19, f * 1.002, 0.25, 1.6);
  let t = 0.26, gap = 0.06, g = 0.18;
  while (gap > 0.012 && t < 0.8) {
    ring(x, t, f, g, 3);
    t += gap; gap *= 0.82; g *= 0.9;
  }
  wav('عملة_أ_عملة_وحدة.wav', x);
}

// ب: كومة عملات تنصب: رنّات كثيرة متداخلة بترددات مختلفة، تبدأ كثيفة وتخف
{
  const x = new Float64Array(Math.round(1.0 * RATE));
  for (let k = 0; k < 22; k++) {
    const t = Math.pow(rnd(), 1.6) * 0.55;
    ring(x, t, 1900 + rnd() * 1700, 0.25 + rnd() * 0.35, 1.4);
  }
  wav('عملة_ب_كومة_عملات.wav', x);
}

// ج: رنّة مكافأة: ثلاث نغمات صاعدة لامعة (مثل الألعاب لما تاخذ عملات) مع بريق خفيف
{
  const x = new Float64Array(Math.round(0.9 * RATE));
  const notes = [1318.5, 1661.2, 1975.5]; // مي، صول#، سي (كبير ولامع)
  notes.forEach((f, k) => {
    const s0 = Math.round(k * 0.075 * RATE);
    for (let i = 0; i < 0.6 * RATE && s0 + i < x.length; i++) {
      const t = i / RATE;
      const env = Math.min(1, t / 0.004) * Math.exp(-t * 7);
      x[s0 + i] += env * (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(2 * Math.PI * f * 2 * t) + 0.12 * Math.sin(2 * Math.PI * f * 3.01 * t));
    }
  });
  // بريق: نقرات عالية صغيرة متفرقة
  for (let k = 0; k < 10; k++) ring(x, 0.15 + rnd() * 0.35, 4200 + rnd() * 1800, 0.08, 2.5);
  wav('عملة_ج_رنة_مكافأة.wav', x);
}
console.log('wrote 3 options to', out);
