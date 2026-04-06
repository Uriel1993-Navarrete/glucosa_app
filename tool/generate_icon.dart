/// Script para generar el ícono de la app de glucosa.
/// Ejecutar con: dart tool/generate_icon.dart
///
/// Genera un PNG 1024x1024 con:
///   - Fondo gradiente azul marino (#0A2540 → #1a7f7f)
///   - Gota de sangre roja en el centro
///   - Cruz médica blanca pequeña arriba a la derecha

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

// ── PNG encoder mínimo ───────────────────────────────────────────────────────
Uint8List encodePng(List<List<int>> pixels, int w, int h) {
  // RGBA raw image → PNG con zlib store (level 0)
  final raw = BytesBuilder();

  // PNG signature
  raw.add([137, 80, 78, 71, 13, 10, 26, 10]);

  void addChunk(String type, List<int> data) {
    final t = type.codeUnits;
    final combined = [...t, ...data];
    final crc = _crc32(combined);
    final len = data.length;
    raw.add([(len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    raw.add(t);
    raw.add(data);
    raw.add([(crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF]);
  }

  // IHDR
  addChunk('IHDR', [
    (w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF,
    (h >> 24) & 0xFF, (h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF,
    8, // bit depth
    2, // color type: RGB
    0, 0, 0,
  ]);

  // IDAT – each row: filter byte (0) + RGB data, then deflate store
  final rowBytes = BytesBuilder();
  for (int y = 0; y < h; y++) {
    rowBytes.addByte(0); // filter none
    for (int x = 0; x < w; x++) {
      final px = pixels[y][x * 3 + 0]; // R
      rowBytes.addByte(px);
      rowBytes.addByte(pixels[y][x * 3 + 1]); // G
      rowBytes.addByte(pixels[y][x * 3 + 2]); // B
    }
  }
  final raw2 = rowBytes.toBytes();

  // zlib: CMF, FLG, then deflate non-compressed blocks
  final zlib = BytesBuilder();
  zlib.addByte(0x78); // CMF: deflate, window=32768
  zlib.addByte(0x01); // FLG: no dict, check bits

  const blockSize = 65535;
  int offset = 0;
  while (offset < raw2.length) {
    final end = min(offset + blockSize, raw2.length);
    final chunk = raw2.sublist(offset, end);
    final last = end >= raw2.length ? 1 : 0;
    zlib.addByte(last);
    final len = chunk.length;
    zlib.addByte(len & 0xFF);
    zlib.addByte((len >> 8) & 0xFF);
    zlib.addByte((~len) & 0xFF);
    zlib.addByte((~len >> 8) & 0xFF);
    zlib.add(chunk);
    offset = end;
  }

  // Adler-32
  int s1 = 1, s2 = 0;
  for (final b in raw2) {
    s1 = (s1 + b) % 65521;
    s2 = (s2 + s1) % 65521;
  }
  final adler = (s2 << 16) | s1;
  zlib.add([(adler >> 24) & 0xFF, (adler >> 16) & 0xFF, (adler >> 8) & 0xFF, adler & 0xFF]);

  addChunk('IDAT', zlib.toBytes());
  addChunk('IEND', []);

  return raw.toBytes();
}

int _crc32(List<int> data) {
  final table = List<int>.generate(256, (i) {
    int c = i;
    for (int j = 0; j < 8; j++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

// ── Dibujo ───────────────────────────────────────────────────────────────────
const int SIZE = 512;

List<List<int>> createCanvas() =>
    List.generate(SIZE, (_) => List.filled(SIZE * 3, 0));

void setPixel(List<List<int>> px, int x, int y, int r, int g, int b) {
  if (x < 0 || x >= SIZE || y < 0 || y >= SIZE) return;
  px[y][x * 3 + 0] = r;
  px[y][x * 3 + 1] = g;
  px[y][x * 3 + 2] = b;
}

// Blend sobre fondo
void blendPixel(List<List<int>> px, int x, int y, int r, int g, int b, double alpha) {
  if (x < 0 || x >= SIZE || y < 0 || y >= SIZE) return;
  final br = px[y][x * 3 + 0];
  final bg = px[y][x * 3 + 1];
  final bb = px[y][x * 3 + 2];
  px[y][x * 3 + 0] = (br + (r - br) * alpha).round().clamp(0, 255);
  px[y][x * 3 + 1] = (bg + (g - bg) * alpha).round().clamp(0, 255);
  px[y][x * 3 + 2] = (bb + (b - bb) * alpha).round().clamp(0, 255);
}

// Gradiente de fondo azul marino → teal
void drawBackground(List<List<int>> px) {
  for (int y = 0; y < SIZE; y++) {
    for (int x = 0; x < SIZE; x++) {
      final t = (x + y) / (SIZE * 2.0);
      // #0A2540 → #0D5B6E
      final r = (10 + (3 - 10) * t).round().clamp(0, 255);
      final g = (37 + (91 - 37) * t).round().clamp(0, 255);
      final b = (64 + (110 - 64) * t).round().clamp(0, 255);
      setPixel(px, x, y, r, g, b);
    }
  }
}

// Círculo relleno con anti-aliasing
void drawCircle(List<List<int>> px, double cx, double cy, double radius,
    int r, int g, int b) {
  final x0 = (cx - radius - 1).floor();
  final x1 = (cx + radius + 1).ceil();
  final y0 = (cy - radius - 1).floor();
  final y1 = (cy + radius + 1).ceil();
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = sqrt(dx * dx + dy * dy);
      final alpha = (radius + 0.5 - dist).clamp(0.0, 1.0);
      if (alpha > 0) blendPixel(px, x, y, r, g, b, alpha);
    }
  }
}

// Gota de sangre (círculo + triángulo apuntando arriba)
void drawBloodDrop(List<List<int>> px, double cx, double cy, double size) {
  const r = 220, g = 50, b = 50; // rojo sangre

  // Cuerpo circular
  drawCircle(px, cx, cy + size * 0.1, size * 0.55, r, g, b);

  // Punta superior (triángulo suavizado con círculos)
  for (double t = 0.0; t <= 1.0; t += 0.01) {
    final tx = cx + (1 - t) * 0.0;
    final ty = cy + size * 0.1 - t * size * 0.7;
    final rad = size * 0.55 * (1 - t * 0.9);
    if (rad > 1) drawCircle(px, tx, ty, rad, r, g, b);
  }

  // Brillo
  drawCircle(px, cx - size * 0.18, cy - size * 0.05, size * 0.12, 255, 180, 180, );
}

// Rectángulo relleno
void drawRect(List<List<int>> px, int x, int y, int w, int h,
    int r, int g, int b) {
  for (int dy = 0; dy < h; dy++) {
    for (int dx = 0; dx < w; dx++) {
      setPixel(px, x + dx, y + dy, r, g, b);
    }
  }
}

// Cruz médica blanca
void drawCross(List<List<int>> px, double cx, double cy, double size) {
  const r = 255, g = 255, b = 255;
  final half = (size / 2).round();
  final thick = (size / 4).round();
  // horizontal
  drawRect(px, (cx - half).round(), (cy - thick ~/ 2).round(),
      half * 2, thick, r, g, b);
  // vertical
  drawRect(px, (cx - thick ~/ 2).round(), (cy - half).round(),
      thick, half * 2, r, g, b);
}

void main() {
  final px = createCanvas();
  drawBackground(px);
  drawBloodDrop(px, SIZE * 0.5, SIZE * 0.52, SIZE * 0.38);
  // Cruz médica pequeña arriba a la derecha
  drawCross(px, SIZE * 0.74, SIZE * 0.26, SIZE * 0.16);

  final png = encodePng(px, SIZE, SIZE);
  File('assets/icon/app_icon.png').writeAsBytesSync(png);
  print('Icono generado: assets/icon/app_icon.png (${SIZE}x$SIZE)');
}
