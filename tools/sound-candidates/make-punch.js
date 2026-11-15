// صوت خال الحكم (آص الحكم): من mixkit-martial-arts-fast-punch-2047.wav
// node tools/sound-candidates/make-punch.js <المصدر.wav> app/assets/sounds/trump_ace.wav
// مونو 44100، يبدأ من أول الهبّة (0.08 ث) فالضربة تصير عند ~0.16 ث، ويخلص بـ 0.60 مع تلاشي، والذروة 0.6 (نفس مستوى صوت الجوكر تقريباً)
const fs = require('fs');
const [src, out] = process.argv.slice(2);
const b = fs.readFileSync(src);
let p = 12, fmt, data;
while (p < b.length - 8) {
  const id = b.toString('ascii', p, p + 4), sz = b.readUInt32LE(p + 4);
  if (id === 'fmt ') fmt = { ch: b.readUInt16LE(p + 10), sr: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
  if (id === 'data') data = { off: p + 8, sz };
  p += 8 + sz + (sz & 1);
}
if (fmt.bits !== 16 || fmt.sr !== 44100) throw new Error('يتوقع 16bit 44100');
const n = data.sz / 2 / fmt.ch;
const mono = new Float32Array(n);
for (let i = 0; i < n; i++) {
  let s = 0;
  for (let c = 0; c < fmt.ch; c++) s += b.readInt16LE(data.off + (i * fmt.ch + c) * 2) / 32768;
  mono[i] = s / fmt.ch;
}
const sr = 44100, start = Math.round(0.08 * sr), end = Math.round(0.60 * sr), fadeFrom = Math.round(0.42 * sr), fadeIn = Math.round(0.005 * sr);
const seg = mono.slice(start, end);
for (let i = 0; i < seg.length; i++) {
  const t = start + i;
  if (i < fadeIn) seg[i] *= i / fadeIn;
  if (t > fadeFrom) seg[i] *= Math.pow(1 - (t - fadeFrom) / (end - fadeFrom), 2);
}
let peak = 0;
for (const v of seg) peak = Math.max(peak, Math.abs(v));
const gain = 0.6 / peak;
const o = Buffer.alloc(44 + seg.length * 2);
o.write('RIFF', 0); o.writeUInt32LE(36 + seg.length * 2, 4); o.write('WAVE', 8);
o.write('fmt ', 12); o.writeUInt32LE(16, 16); o.writeUInt16LE(1, 20); o.writeUInt16LE(1, 22);
o.writeUInt32LE(sr, 24); o.writeUInt32LE(sr * 2, 28); o.writeUInt16LE(2, 32); o.writeUInt16LE(16, 34);
o.write('data', 36); o.writeUInt32LE(seg.length * 2, 40);
for (let i = 0; i < seg.length; i++) o.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(seg[i] * gain * 32767))), 44 + i * 2);
fs.writeFileSync(out, o);
console.log('wrote', out, (seg.length / sr).toFixed(3) + 's', 'gain', gain.toFixed(2));
