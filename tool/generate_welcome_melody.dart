// Genera la melodía de bienvenida de Mi Voz: una cajita musical suave de
// unos 4,6 segundos, compuesta y sintetizada aquí (obra original, sin
// muestras de terceros). Uso:
//
//   dart run tool/generate_welcome_melody.dart
//
// Resultado: assets/audio/bienvenida_mi_voz.wav (PCM 16 bits, mono, 22 050 Hz).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 22050;
const durationSeconds = 4.6;

/// (inicio en segundos, frecuencia en Hz, volumen relativo).
/// Arpegio ascendente de Do mayor, respuesta descendente y acorde final.
const melody = <(double, double, double)>[
  (0.00, 523.25, 0.80), // Do5
  (0.32, 659.25, 0.72), // Mi5
  (0.64, 783.99, 0.72), // Sol5
  (0.96, 1046.50, 0.62), // Do6
  (1.44, 880.00, 0.62), // La5
  (1.80, 783.99, 0.64), // Sol5
  (2.16, 659.25, 0.66), // Mi5
  (2.64, 523.25, 0.55), // Do5 (acorde final)
  (2.66, 659.25, 0.45), // Mi5
  (2.68, 783.99, 0.40), // Sol5
  (2.72, 1046.50, 0.32), // Do6
];

/// Notas graves muy suaves que acompañan.
const bass = <(double, double, double)>[
  (0.00, 261.63, 0.30), // Do4
  (1.44, 220.00, 0.26), // La3
  (2.64, 261.63, 0.30), // Do4
];

void main() {
  final total = (sampleRate * durationSeconds).round();
  final mix = Float64List(total);

  void addNote(double start, double freq, double gain, {required bool soft}) {
    final first = (start * sampleRate).round();
    for (var i = first; i < total; i++) {
      final t = (i - first) / sampleRate;
      // Ataque breve (sin chasquidos) y caída exponencial de cajita musical.
      final attack = math.min(1.0, t / 0.012);
      final decay = math.exp(-t / (soft ? 1.6 : 1.05));
      if (decay < 0.0005) break;
      final w = 2 * math.pi * freq * t;
      // Parciales: fundamental cálida + armónicos tenues que se apagan antes.
      final tone = soft
          ? math.sin(w)
          : math.sin(w) +
                0.28 * math.sin(2 * w) * math.exp(-t / 0.35) +
                0.08 * math.sin(4.02 * w) * math.exp(-t / 0.18);
      mix[i] += tone * gain * attack * decay;
    }
  }

  for (final (s, f, g) in melody) {
    addNote(s, f, g, soft: false);
  }
  for (final (s, f, g) in bass) {
    addNote(s, f, g, soft: true);
  }

  // Eco muy discreto para dar espacio (dos retardos atenuados).
  final wet = Float64List.fromList(mix);
  for (final (delay, gain) in [(0.13, 0.18), (0.21, 0.10)]) {
    final d = (delay * sampleRate).round();
    for (var i = d; i < total; i++) {
      wet[i] += mix[i - d] * gain;
    }
  }

  // Entrada y salida suaves, y normalización a un volumen moderado (-8 dBFS).
  final fadeIn = (0.06 * sampleRate).round();
  final fadeOut = (1.1 * sampleRate).round();
  var peak = 0.0;
  for (var i = 0; i < total; i++) {
    var env = 1.0;
    if (i < fadeIn) env = i / fadeIn;
    if (i > total - fadeOut) {
      final x = (total - i) / fadeOut;
      env = x * x;
    }
    wet[i] *= env;
    peak = math.max(peak, wet[i].abs());
  }
  final target = math.pow(10, -8 / 20) / peak;

  final pcm = ByteData(total * 2);
  for (var i = 0; i < total; i++) {
    final v = (wet[i] * target * 32767).round().clamp(-32768, 32767);
    pcm.setInt16(i * 2, v, Endian.little);
  }

  final file = File('assets/audio/bienvenida_mi_voz.wav')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(_wav(pcm.buffer.asUint8List()));
  stdout.writeln(
    'Generado ${file.path} (${file.lengthSync()} bytes, '
    '${durationSeconds}s)',
  );
}

Uint8List _wav(Uint8List data) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + data.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, data.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
}
