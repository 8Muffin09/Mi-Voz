// Descarga los pictogramas de ARASAAC que usa Mi Voz.
//
// ARASAAC (https://arasaac.org): autor Sergio Palao, propiedad del Gobierno
// de Aragón (España), licencia CC BY-NC-SA 4.0. Ver
// assets/pictograms/ATRIBUCION.md.
//
// Uso:
//   dart run tool/pictograms/fetch_pictograms.dart candidates <carpeta>
//       Busca cada concepto de queries.json y genera hojas de contacto con
//       los primeros candidatos para elegir a mano (no modifica assets/).
//   dart run tool/pictograms/fetch_pictograms.dart download
//       Descarga los identificadores elegidos en selection.json a
//       assets/pictograms/<id>.png (256 px, PNG con transparencia).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _api = 'https://api.arasaac.org/v1/pictograms/es/search';
const _static = 'https://static.arasaac.org/pictograms';
const _dir = 'tool/pictograms';
const _out = 'assets/pictograms';
const _size = 256;
const _candidates = 5;

Future<void> main(List<String> args) async {
  final client = HttpClient();
  try {
    switch (args.firstOrNull) {
      case 'candidates':
        await _candidatesSheets(
          client,
          args.length > 1 ? args[1] : 'build',
          args.length > 2 ? args[2] : '$_dir/queries.json',
        );
      case 'download':
        await _download(client);
      default:
        stderr.writeln('Uso: candidates <carpeta> | download');
        exitCode = 64;
    }
  } finally {
    client.close();
  }
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Future<List<int>> _get(HttpClient client, String url) async {
  for (var attempt = 0; ; attempt++) {
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
      if (res.statusCode != 200) throw HttpException('${res.statusCode} $url');
      return bytes;
    } catch (e) {
      if (attempt >= 2) rethrow;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}

Future<List<int>> _search(HttpClient client, String query) async {
  try {
    final body = await _get(client, '$_api/${Uri.encodeComponent(query)}');
    final list = jsonDecode(utf8.decode(body)) as List;
    return [
      for (final p in list.cast<Map<String, dynamic>>())
        if (p['sex'] != true && p['violence'] != true) p['_id'] as int,
    ].take(_candidates).toList();
  } on HttpException {
    return const [];
  }
}

Future<img.Image> _picto(HttpClient client, int id, int size) async {
  final bytes = await _get(client, '$_static/$id/${id}_300.png');
  final decoded = img.decodePng(Uint8List.fromList(bytes))!;
  return img.copyResize(
    decoded,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}

Future<void> _candidatesSheets(
  HttpClient client,
  String folder,
  String queriesFile,
) async {
  final queries = _readJson(queriesFile);
  final found = <String, List<int>>{};
  const thumb = 110;
  const labelWidth = 230;
  const perSheet = 14;
  final keys = queries.keys.toList();
  Directory(folder).createSync(recursive: true);
  for (var s = 0; s * perSheet < keys.length; s++) {
    final chunk = keys.skip(s * perSheet).take(perSheet).toList();
    final sheet = img.Image(
      width: labelWidth + thumb * _candidates,
      height: (thumb + 18) * chunk.length,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var r = 0; r < chunk.length; r++) {
      final key = chunk[r];
      final ids = await _search(client, queries[key] as String);
      found[key] = ids;
      final y = r * (thumb + 18);
      img.drawString(
        sheet,
        key,
        font: img.arial14,
        x: 4,
        y: y + thumb ~/ 2,
        color: img.ColorRgb8(0, 0, 0),
      );
      for (var c = 0; c < ids.length; c++) {
        final x = labelWidth + c * thumb;
        img.compositeImage(
          sheet,
          await _picto(client, ids[c], thumb - 6),
          dstX: x,
          dstY: y,
        );
        img.drawString(
          sheet,
          '${ids[c]}',
          font: img.arial14,
          x: x + 4,
          y: y + thumb - 4,
          color: img.ColorRgb8(200, 0, 0),
        );
      }
      img.drawLine(
        sheet,
        x1: 0,
        y1: y + thumb + 16,
        x2: sheet.width,
        y2: y + thumb + 16,
        color: img.ColorRgb8(210, 210, 210),
      );
    }
    File('$folder/sheet_$s.png').writeAsBytesSync(img.encodePng(sheet));
    stdout.writeln('Hoja $s lista');
  }
  File('$folder/candidates.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(found));
}

Future<void> _download(HttpClient client) async {
  final selection = _readJson('$_dir/selection.json');
  Directory(_out).createSync(recursive: true);
  var total = 0;
  for (final e in selection.entries) {
    final id = e.value as int;
    final image = await _picto(client, id, _size);
    final png = img.encodePng(image, level: 9);
    File('$_out/${e.key}.png').writeAsBytesSync(png);
    total += png.length;
  }
  stdout.writeln(
    '${selection.length} pictogramas, ${(total / 1024).round()} KB en total.',
  );
}
