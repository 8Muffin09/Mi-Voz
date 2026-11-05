// Genera las ilustraciones de avatares de Mi Voz (diseño original del
// proyecto, sin recursos de terceros). Todas comparten lienzo de 200 × 200,
// encuadre de busto, paleta suave, ojos y sonrisa del mismo trazo, y fondo
// transparente: el color de fondo lo elige cada perfil en la app.
//
//   dart run tool/avatars/generate_avatars.dart
//
// Escribe assets/avatars/<id>.svg. Los identificadores son estables: los
// perfiles guardan el identificador, nunca la posición en la galería. Si
// cambias un dibujo conserva su identificador; si agregas uno, regístralo en
// lib/core/visuals/avatar_catalog.dart.
// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';

const _out = 'assets/avatars';
const _ink = '#2B2D42';
const _cheek = '#FF8FA3';

void main() {
  Directory(_out).createSync(recursive: true);
  final all = {..._animals(), ..._characters(), ..._adults()};
  for (final e in all.entries) {
    File('$_out/${e.key}.svg').writeAsStringSync(_svg(e.value));
  }
  stdout.writeln('${all.length} avatares generados en $_out.');
}

String _svg(String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">'
    '$body</svg>\n';

// ---------------------------------------------------------------------------
// Piezas comunes
// ---------------------------------------------------------------------------

String _eyes({double y = 92, double dx = 22, double r = 7}) =>
    '<circle cx="${100 - dx}" cy="$y" r="$r" fill="$_ink"/>'
    '<circle cx="${100 + dx}" cy="$y" r="$r" fill="$_ink"/>'
    '<circle cx="${100 - dx + r * 0.35}" cy="${y - r * 0.4}" r="${r * 0.36}" fill="#fff"/>'
    '<circle cx="${100 + dx + r * 0.35}" cy="${y - r * 0.4}" r="${r * 0.36}" fill="#fff"/>';

String _smile({
  double y = 118,
  double w = 10,
  double depth = 9,
  double sw = 3.5,
}) =>
    '<path d="M${100 - w} $y Q100 ${y + depth} ${100 + w} $y" fill="none" '
    'stroke="$_ink" stroke-width="$sw" stroke-linecap="round"/>';

String _cheeks({double y = 112, double dx = 34, double r = 8}) =>
    '<circle cx="${100 - dx}" cy="$y" r="$r" fill="$_cheek" opacity="0.45"/>'
    '<circle cx="${100 + dx}" cy="$y" r="$r" fill="$_cheek" opacity="0.45"/>';

String _body(String color, {String? accent}) =>
    '<path d="M28 200 C28 162 58 146 100 146 C142 146 172 162 172 200 Z" fill="$color"/>'
    '${accent == null ? '' : '<path d="M72 200 C72 172 84 160 100 160 C116 160 128 172 128 200 Z" fill="$accent"/>'}';

String _head(String color, {double rx = 58, double ry = 54, double cy = 95}) =>
    '<ellipse cx="100" cy="$cy" rx="$rx" ry="$ry" fill="$color"/>';

String _roundEars(
  String color,
  String inner, {
  double y = 50,
  double dx = 46,
  double r = 20,
}) =>
    '<circle cx="${100 - dx}" cy="$y" r="$r" fill="$color"/>'
    '<circle cx="${100 + dx}" cy="$y" r="$r" fill="$color"/>'
    '<circle cx="${100 - dx}" cy="$y" r="${r * 0.5}" fill="$inner"/>'
    '<circle cx="${100 + dx}" cy="$y" r="${r * 0.5}" fill="$inner"/>';

String _pointedEars(String color, String inner) =>
    '<path d="M48 76 L54 22 L92 50 Z" fill="$color" stroke="$color" stroke-width="6" stroke-linejoin="round"/>'
    '<path d="M152 76 L146 22 L108 50 Z" fill="$color" stroke="$color" stroke-width="6" stroke-linejoin="round"/>'
    '<path d="M58 62 L61 34 L80 50 Z" fill="$inner"/>'
    '<path d="M142 62 L139 34 L120 50 Z" fill="$inner"/>';

String _muzzle(
  String color, {
  double cy = 116,
  double rx = 28,
  double ry = 20,
}) => '<ellipse cx="100" cy="$cy" rx="$rx" ry="$ry" fill="$color"/>';

String _nose(String color, {double y = 106, double rx = 8, double ry = 5.5}) =>
    '<ellipse cx="100" cy="$y" rx="$rx" ry="$ry" fill="$color"/>';

String _whiskers(String color) => [
  for (final s in [-1, 1])
    for (final dy in [-4, 4])
      '<path d="M${100 + s * 30} ${112 + dy} L${100 + s * 52} ${110 + dy * 2}" '
          'stroke="$color" stroke-width="2.5" stroke-linecap="round"/>',
].join();

// ---------------------------------------------------------------------------
// Animales (perfiles infantiles)
// ---------------------------------------------------------------------------

Map<String, String> _animals() => {
  'animal_lion':
      _body('#E9A23B', accent: '#F6D58E') +
      '<circle cx="100" cy="96" r="76" fill="#C8702A"/>'
          '<circle cx="100" cy="96" r="66" fill="#D9853A"/>' +
      _roundEars('#F3BE4F', '#E79A3A', y: 46, dx: 44, r: 16) +
      _head('#F6C453', rx: 52, ry: 50) +
      _muzzle('#FCE7B8') +
      _nose('#7A4A2B') +
      _eyes() +
      _smile(y: 120) +
      _cheeks(),
  'animal_bear':
      _body('#9C6440', accent: '#D9A57A') +
      _roundEars('#A86B43', '#D9A57A') +
      _head('#A86B43') +
      _muzzle('#E8C39E') +
      _nose('#3B2A22', rx: 10, ry: 7) +
      _eyes() +
      _smile(y: 120) +
      _cheeks(),
  'animal_panda':
      _body('#3A3B4A', accent: '#F4F4F6') +
      _roundEars('#2E2F3B', '#2E2F3B') +
      _head('#F7F7F9') +
      '<ellipse cx="76" cy="94" rx="15" ry="18" fill="#2E2F3B" transform="rotate(-25 76 94)"/>'
          '<ellipse cx="124" cy="94" rx="15" ry="18" fill="#2E2F3B" transform="rotate(25 124 94)"/>'
          '<circle cx="78" cy="92" r="6" fill="#fff"/><circle cx="122" cy="92" r="6" fill="#fff"/>'
          '<circle cx="79" cy="92" r="3.6" fill="$_ink"/><circle cx="121" cy="92" r="3.6" fill="$_ink"/>' +
      _nose('#2E2F3B') +
      _smile(y: 118) +
      _cheeks(y: 114, dx: 38),
  'animal_koala':
      _body('#8F98A6', accent: '#E8E3E8') +
      '<circle cx="46" cy="62" r="30" fill="#A9B0BA"/><circle cx="154" cy="62" r="30" fill="#A9B0BA"/>'
          '<circle cx="48" cy="64" r="18" fill="#EBDDE3"/><circle cx="152" cy="64" r="18" fill="#EBDDE3"/>' +
      _head('#B4BAC4') +
      '<ellipse cx="100" cy="110" rx="13" ry="17" fill="#3E3F4C"/>' +
      _eyes(y: 90, dx: 26, r: 6.5) +
      _smile(y: 132, w: 8, depth: 6) +
      _cheeks(y: 112, dx: 38),
  'animal_fox':
      _body('#E97E36', accent: '#FFF4E8') +
      _pointedEars('#F08A3C', '#4A3530') +
      _head('#F08A3C') +
      '<path d="M44 100 C60 104 80 108 100 132 C120 108 140 104 156 100 C150 132 128 148 100 148 C72 148 50 132 44 100 Z" fill="#FFF4E8"/>' +
      _nose('#3B2A2A', y: 112) +
      _eyes(y: 90) +
      _smile(y: 122, w: 8, depth: 7) +
      _cheeks(y: 108, dx: 36),
  'animal_tiger':
      _body('#EE9737', accent: '#FFF4E3') +
      _roundEars('#F5A142', '#FFF4E3', y: 48, dx: 44, r: 17) +
      _head('#F5A142') +
      '<path d="M100 42 L94 62 L106 62 Z M80 46 L82 66 L90 62 Z M120 46 L118 66 L110 62 Z" fill="#5A3A2E"/>'
          '<path d="M44 92 L64 96 L46 102 Z M42 108 L62 110 L46 118 Z M156 92 L136 96 L154 102 Z M158 108 L138 110 L154 118 Z" fill="#5A3A2E"/>' +
      _muzzle('#FFF4E3', ry: 22) +
      _nose('#E0606B') +
      _eyes() +
      _smile(y: 120) +
      _whiskers('#B9876A'),
  'animal_frog':
      _body('#6DB65C', accent: '#CDEBB5') +
      '<circle cx="68" cy="56" r="24" fill="#7CC66B"/><circle cx="132" cy="56" r="24" fill="#7CC66B"/>' +
      _head('#7CC66B', rx: 64, ry: 48, cy: 102) +
      '<circle cx="68" cy="54" r="15" fill="#fff"/><circle cx="132" cy="54" r="15" fill="#fff"/>'
          '<circle cx="70" cy="55" r="8" fill="$_ink"/><circle cx="130" cy="55" r="8" fill="$_ink"/>'
          '<circle cx="73" cy="51" r="3" fill="#fff"/><circle cx="133" cy="51" r="3" fill="#fff"/>'
          '<circle cx="92" cy="96" r="2.6" fill="#3F7A35"/><circle cx="108" cy="96" r="2.6" fill="#3F7A35"/>' +
      _smile(y: 112, w: 26, depth: 16, sw: 4) +
      _cheeks(y: 112, dx: 42, r: 9),
  'animal_monkey':
      _body('#7D4F33', accent: '#F1C9A0') +
      '<circle cx="40" cy="98" r="20" fill="#8D5A3B"/><circle cx="160" cy="98" r="20" fill="#8D5A3B"/>'
          '<circle cx="40" cy="98" r="11" fill="#F1C9A0"/><circle cx="160" cy="98" r="11" fill="#F1C9A0"/>' +
      _head('#8D5A3B', rx: 56) +
      '<circle cx="80" cy="92" r="21" fill="#F1C9A0"/><circle cx="120" cy="92" r="21" fill="#F1C9A0"/>'
          '<ellipse cx="100" cy="118" rx="34" ry="24" fill="#F1C9A0"/>' +
      _eyes(y: 92, dx: 20, r: 6.5) +
      '<circle cx="95" cy="108" r="2.4" fill="#6B4430"/><circle cx="105" cy="108" r="2.4" fill="#6B4430"/>' +
      _smile(y: 120, w: 12, depth: 9) +
      _cheeks(y: 116, dx: 28, r: 6),
  'animal_dog':
      _body('#C98E55', accent: '#F6E3C8') +
      '<ellipse cx="46" cy="96" rx="17" ry="36" fill="#8B5A35" transform="rotate(16 46 96)"/>'
          '<ellipse cx="154" cy="96" rx="17" ry="36" fill="#8B5A35" transform="rotate(-16 154 96)"/>' +
      _head('#D9A066', rx: 54) +
      '<ellipse cx="124" cy="84" rx="16" ry="14" fill="#F3D3A6"/>' +
      _muzzle('#F6E3C8', ry: 22) +
      _nose('#3B2A22', rx: 10, ry: 7) +
      _eyes() +
      '<path d="M94 124 Q94 138 100 138 Q106 138 106 124 Z" fill="#F08A9A"/>' +
      _smile(y: 120),
  'animal_cat':
      _body('#9EA6B6', accent: '#F1F1F5') +
      _pointedEars('#AEB4C0', '#F7C6D0') +
      _head('#AEB4C0') +
      '<path d="M100 44 L96 60 M88 46 L89 60 M112 46 L111 60" stroke="#868EA0" stroke-width="4" stroke-linecap="round"/>' +
      _muzzle('#F1F1F5', ry: 18) +
      _nose('#F28CA0', rx: 6, ry: 4.5) +
      _eyes() +
      _smile(y: 118, w: 8, depth: 7) +
      _whiskers('#7D8494') +
      _cheeks(y: 108, dx: 36, r: 7),
  'animal_rabbit':
      _body('#E3DEE6', accent: '#FFFFFF') +
      '<ellipse cx="76" cy="36" rx="14" ry="40" fill="#F1EEF2" transform="rotate(-8 76 36)"/>'
          '<ellipse cx="124" cy="36" rx="14" ry="40" fill="#F1EEF2" transform="rotate(8 124 36)"/>'
          '<ellipse cx="76" cy="38" rx="7" ry="28" fill="#F7C6D0" transform="rotate(-8 76 38)"/>'
          '<ellipse cx="124" cy="38" rx="7" ry="28" fill="#F7C6D0" transform="rotate(8 124 38)"/>' +
      _head('#F4F1F5', cy: 102, ry: 50) +
      _muzzle('#FFFFFF', cy: 120, ry: 18) +
      _nose('#F28CA0', y: 112, rx: 6, ry: 4.5) +
      '<rect x="95" y="124" width="10" height="10" rx="2" fill="#fff" stroke="#D5D0D8" stroke-width="1.5"/>' +
      _eyes(y: 98) +
      _smile(y: 122, w: 8, depth: 5, sw: 3) +
      _cheeks(y: 116),
  'animal_unicorn':
      _body('#E7DDF5', accent: '#FFFFFF') +
      '<path d="M52 60 C40 90 44 130 60 150 C54 120 58 92 72 70 Z" fill="#B79BE8"/>'
          '<path d="M60 52 C52 80 56 110 70 128 C68 104 74 84 84 70 Z" fill="#F4A6C7"/>' +
      _pointedEars('#FBF7FF', '#F7C6D0') +
      _head('#FBF7FF') +
      '<path d="M100 6 L88 52 L112 52 Z" fill="#F7CF5A"/>'
          '<path d="M91 40 L108 34 M94 28 L105 24" stroke="#E2A93A" stroke-width="3" stroke-linecap="round"/>'
          '<path d="M78 46 C92 34 116 36 128 50 C112 46 96 50 86 60 Z" fill="#9FD3F2"/>' +
      _muzzle('#FFE9F2', ry: 18) +
      '<circle cx="93" cy="114" r="2.6" fill="#C98AA6"/><circle cx="107" cy="114" r="2.6" fill="#C98AA6"/>' +
      _eyes() +
      _smile(y: 122, w: 9, depth: 7),
  'animal_turtle':
      '<path d="M22 200 C22 150 56 132 100 132 C144 132 178 150 178 200 Z" fill="#5E9A4E"/>'
          '<path d="M60 200 L68 160 L100 148 L132 160 L140 200 M68 160 L46 176 M132 160 L154 176 M100 148 L100 132" fill="none" stroke="#467A3A" stroke-width="5" stroke-linejoin="round"/>' +
      _head('#9ACD7A', rx: 50, ry: 48, cy: 92) +
      _eyes(y: 88, dx: 20) +
      _smile(y: 112, w: 14, depth: 10) +
      _cheeks(y: 106, dx: 30, r: 7),
  'animal_owl':
      _body('#8E6A4B', accent: '#E9D5B5') +
      '<path d="M50 60 L46 24 L76 48 Z M150 60 L154 24 L124 48 Z" fill="#9B7653"/>' +
      _head('#9B7653', rx: 58, ry: 56) +
      '<circle cx="76" cy="92" r="24" fill="#F2E3C6"/><circle cx="124" cy="92" r="24" fill="#F2E3C6"/>' +
      _eyes(y: 92, dx: 24, r: 10) +
      '<path d="M92 110 L108 110 L100 124 Z" fill="#F3A33C" stroke="#F3A33C" stroke-width="4" stroke-linejoin="round"/>' +
      _cheeks(y: 120, dx: 40, r: 7),
  'animal_penguin':
      _body('#3A4660', accent: '#F7F7FA') +
      _head('#3A4660', rx: 56, ry: 56) +
      '<path d="M100 66 C114 52 146 62 142 96 C140 124 122 140 100 140 C78 140 60 124 58 96 C54 62 86 52 100 66 Z" fill="#F7F7FA"/>' +
      _eyes(y: 94, dx: 20) +
      '<path d="M90 106 L110 106 L100 118 Z" fill="#F5A33C" stroke="#F5A33C" stroke-width="5" stroke-linejoin="round"/>' +
      _cheeks(y: 114, dx: 30, r: 7),
  'animal_elephant':
      _body('#93A6BC', accent: '#C9D6E4') +
      '<ellipse cx="44" cy="96" rx="34" ry="40" fill="#A7B8CC"/><ellipse cx="156" cy="96" rx="34" ry="40" fill="#A7B8CC"/>'
          '<ellipse cx="48" cy="98" rx="22" ry="28" fill="#E5C9D6"/><ellipse cx="152" cy="98" rx="22" ry="28" fill="#E5C9D6"/>' +
      _head('#B3C3D5', rx: 52, ry: 52) +
      '<path d="M90 104 C88 130 92 150 112 152 C120 152 122 144 116 142 C104 140 108 124 110 104 Z" fill="#A7B8CC"/>' +
      _eyes(y: 90, dx: 24, r: 6.5) +
      _cheeks(y: 110, dx: 36, r: 8),
  'animal_mouse':
      _body('#A9A9B8', accent: '#ECECF2') +
      '<circle cx="50" cy="52" r="28" fill="#B8B8C4"/><circle cx="150" cy="52" r="28" fill="#B8B8C4"/>'
          '<circle cx="50" cy="52" r="17" fill="#F7C6D0"/><circle cx="150" cy="52" r="17" fill="#F7C6D0"/>' +
      _head('#C4C4CF', rx: 54, ry: 52) +
      _muzzle('#ECECF2', cy: 118, rx: 24, ry: 16) +
      _nose('#F28CA0', y: 110, rx: 6, ry: 5) +
      _eyes() +
      _smile(y: 122, w: 7, depth: 5, sw: 3) +
      _whiskers('#7D7D8C'),
  'animal_chick':
      _body('#F5C531', accent: '#FFE58A') +
      '<path d="M96 46 C92 30 100 24 104 34 C108 24 118 30 108 46 Z" fill="#F5C531"/>' +
      _head('#FFD84D', rx: 56, ry: 54) +
      _eyes(y: 90) +
      '<path d="M88 106 L112 106 L100 122 Z" fill="#F38A2E" stroke="#F38A2E" stroke-width="5" stroke-linejoin="round"/>' +
      _cheeks(y: 110, dx: 36, r: 9),
};

// ---------------------------------------------------------------------------
// Personajes neutros (perfiles infantiles y adultos)
// ---------------------------------------------------------------------------

Map<String, String> _characters() => {
  'character_robot':
      _body('#7FA8CC', accent: '#C9DDF0') +
      '<line x1="100" y1="22" x2="100" y2="44" stroke="#5B7FA3" stroke-width="5"/>'
          '<circle cx="100" cy="20" r="8" fill="#F38A8A"/>'
          '<rect x="34" y="80" width="14" height="30" rx="6" fill="#5B7FA3"/>'
          '<rect x="152" y="80" width="14" height="30" rx="6" fill="#5B7FA3"/>'
          '<rect x="44" y="42" width="112" height="100" rx="30" fill="#9FC7E8"/>'
          '<rect x="58" y="62" width="84" height="60" rx="20" fill="#2F3E57"/>'
          '<circle cx="82" cy="88" r="8" fill="#7FF0D6"/><circle cx="118" cy="88" r="8" fill="#7FF0D6"/>'
          '<path d="M86 104 Q100 114 114 104" fill="none" stroke="#7FF0D6" stroke-width="4" stroke-linecap="round"/>',
  'character_star':
      '<path d="M100 18 L123 70 L180 75 L137 112 L150 168 L100 139 L50 168 L63 112 L20 75 L77 70 Z" '
          'fill="#FFD447" stroke="#FFD447" stroke-width="14" stroke-linejoin="round"/>' +
      _eyes(y: 96, dx: 18, r: 6.5) +
      _smile(y: 116, w: 9, depth: 8) +
      _cheeks(y: 112, dx: 30, r: 7),
  'character_cloud':
      '<path d="M48 150 C22 150 18 112 44 106 C40 76 74 64 90 82 C98 56 140 56 146 88 C172 84 186 116 164 134 C166 146 158 150 150 150 Z" fill="#FFFFFF" stroke="#B9D7F0" stroke-width="5" stroke-linejoin="round"/>' +
      _eyes(y: 112, dx: 20, r: 6.5) +
      _smile(y: 130, w: 9, depth: 7) +
      _cheeks(y: 126, dx: 34, r: 7),
  'character_flower':
      '<g fill="#F7A1C0">'
          '${[for (var i = 0; i < 8; i++) '<ellipse cx="100" cy="46" rx="20" ry="30" transform="rotate(${i * 45} 100 98)"/>'].join()}'
          '</g>'
          '<circle cx="100" cy="98" r="40" fill="#FFD447"/>' +
      _eyes(y: 92, dx: 15, r: 5.5) +
      _smile(y: 108, w: 9, depth: 7) +
      _cheeks(y: 106, dx: 26, r: 6),
  'character_sun':
      '<g stroke="#FFB43B" stroke-width="10" stroke-linecap="round">'
          '${[for (var i = 0; i < 12; i++) '<line x1="100" y1="14" x2="100" y2="32" transform="rotate(${i * 30} 100 100)"/>'].join()}'
          '</g>'
          '<circle cx="100" cy="100" r="58" fill="#FFCF4A"/>' +
      _eyes(y: 94, dx: 20) +
      _smile(y: 116, w: 12, depth: 10) +
      _cheeks(y: 112, dx: 34),
  'character_leaf':
      '<path d="M100 170 C40 150 34 80 100 26 C166 80 160 150 100 170 Z" fill="#8FD18A"/>'
          '<path d="M100 170 L100 60" stroke="#5FA35A" stroke-width="5" stroke-linecap="round"/>'
          '<path d="M100 120 L72 98 M100 100 L128 80" stroke="#5FA35A" stroke-width="4" stroke-linecap="round"/>'
          '<g transform="translate(0 -4)">${_eyes(y: 116, dx: 18, r: 6)}</g>' +
      _smile(y: 130, w: 8, depth: 6) +
      _cheeks(y: 126, dx: 30, r: 6),
};

// ---------------------------------------------------------------------------
// Retratos de adultos
// ---------------------------------------------------------------------------

const _skin = {
  'light': ('#F9D9C3', '#E9B99B'),
  'lightmed': ('#F0C49F', '#D9A47C'),
  'medium': ('#D9A06F', '#BE8355'),
  'meddark': ('#B57A4D', '#9A6239'),
  'dark': ('#8C5A36', '#734628'),
  'deep': ('#62402A', '#4E321F'),
};

const _hairColor = {
  'black': '#2A2420',
  'darkbrown': '#4A2F22',
  'brown': '#7A4B2E',
  'auburn': '#A4472A',
  'blond': '#E1B65A',
  'gray': '#B9B6B2',
};

class _Adult {
  const _Adult(
    this.skin,
    this.hair,
    this.color, {
    required this.shirt,
    this.glasses = false,
    this.beard = false,
    this.earrings = false,
  });

  final String skin;
  final String hair; // estilo
  final String color; // color de pelo
  final String shirt;
  final bool glasses;
  final bool beard;
  final bool earrings;
}

const _adultList = {
  'adult_long_brown': _Adult(
    'light',
    'long',
    'brown',
    shirt: '#7FB3E6',
    earrings: true,
  ),
  'adult_short_brown': _Adult('lightmed', 'short', 'brown', shirt: '#8FCBA8'),
  'adult_short_black': _Adult('medium', 'short', 'black', shirt: '#F2B880'),
  'adult_curly_black': _Adult(
    'dark',
    'curly',
    'black',
    shirt: '#E99AB3',
    earrings: true,
  ),
  'adult_shortcurly_beard': _Adult(
    'deep',
    'shortcurly',
    'black',
    shirt: '#9DB8E8',
    beard: true,
  ),
  'adult_bob_auburn': _Adult('light', 'bob', 'auburn', shirt: '#B9A3E3'),
  'adult_gray_beard': _Adult(
    'lightmed',
    'short',
    'gray',
    shirt: '#86B9C9',
    beard: true,
  ),
  'adult_bun_gray': _Adult(
    'medium',
    'bun',
    'gray',
    shirt: '#E7A3A3',
    glasses: true,
  ),
  'adult_bald_glasses': _Adult(
    'meddark',
    'bald',
    'gray',
    shirt: '#A3C79A',
    glasses: true,
  ),
  'adult_long_black_glasses': _Adult(
    'medium',
    'long',
    'black',
    shirt: '#F0C76A',
    glasses: true,
  ),
  'adult_sidepart_glasses': _Adult(
    'meddark',
    'sidepart',
    'darkbrown',
    shirt: '#7FB3E6',
    glasses: true,
  ),
  'adult_buzz_glasses': _Adult(
    'dark',
    'buzz',
    'black',
    shirt: '#F2A37A',
    glasses: true,
  ),
  'adult_ponytail_blond': _Adult(
    'light',
    'ponytail',
    'blond',
    shirt: '#93D1C4',
  ),
  'adult_locs': _Adult('deep', 'locs', 'black', shirt: '#F0C76A'),
  'adult_headscarf': _Adult('lightmed', 'headscarf', 'black', shirt: '#6FA8A0'),
  'adult_wavy_brown': _Adult(
    'meddark',
    'wavy',
    'darkbrown',
    shirt: '#C7A3E3',
    earrings: true,
  ),
  'adult_short_blond_beard': _Adult(
    'medium',
    'short',
    'blond',
    shirt: '#9DB8E8',
    beard: true,
  ),
  'adult_curly_brown': _Adult('lightmed', 'curly', 'brown', shirt: '#8FCBA8'),
};

Map<String, String> _adults() => {
  for (final e in _adultList.entries) e.key: _portrait(e.value),
};

String _portrait(_Adult a) {
  final (skin, shade) = _skin[a.skin]!;
  final hair = _hairColor[a.color]!;
  final b = StringBuffer();

  // Pelo de atrás (estilos largos).
  switch (a.hair) {
    case 'long':
      b.write(
        '<path d="M56 86 C54 46 76 36 100 36 C124 36 146 46 144 86 L150 160 C130 168 70 168 50 160 Z" fill="$hair"/>',
      );
    case 'wavy':
      b.write(
        '<path d="M54 86 C52 44 78 34 100 34 C122 34 148 44 146 86 C156 104 144 118 152 134 C140 150 60 150 48 134 C56 118 44 104 54 86 Z" fill="$hair"/>',
      );
    case 'bob':
      b.write(
        '<path d="M54 90 C52 46 76 36 100 36 C124 36 148 46 146 90 L148 132 C130 140 70 140 52 132 Z" fill="$hair"/>',
      );
    case 'locs':
      for (final x in [56, 66, 76, 124, 134, 144]) {
        b.write(
          '<rect x="${x - 5}" y="70" width="10" height="${x < 100 ? 92 - (x - 56) : 92 - (144 - x)}" rx="5" fill="$hair"/>',
        );
      }
    case 'headscarf':
      b.write(
        '<path d="M46 100 C42 46 72 28 100 28 C128 28 158 46 154 100 C156 130 146 156 100 160 C54 156 44 130 46 100 Z" fill="${a.shirt}"/>',
      );
    case 'ponytail':
      b.write(
        '<ellipse cx="150" cy="96" rx="14" ry="34" fill="$hair" transform="rotate(-14 150 96)"/>',
      );
  }

  // Cuello y ropa.
  b.write(
    '<rect x="86" y="122" width="28" height="34" rx="10" fill="$shade"/>',
  );
  b.write(_body(a.shirt));
  b.write(
    '<path d="M82 148 Q100 166 118 148" fill="none" stroke="$shade" stroke-width="4" stroke-linecap="round" opacity="0.6"/>',
  );

  // Orejas y cara.
  if (a.hair != 'headscarf') {
    b.write(
      '<circle cx="60" cy="98" r="9" fill="$skin"/><circle cx="140" cy="98" r="9" fill="$skin"/>',
    );
  }
  b.write('<ellipse cx="100" cy="92" rx="40" ry="46" fill="$skin"/>');
  if (a.earrings && a.hair != 'headscarf') {
    b.write(
      '<circle cx="60" cy="110" r="3.5" fill="#F2C14E"/><circle cx="140" cy="110" r="3.5" fill="#F2C14E"/>',
    );
  }

  // Pelo de delante.
  switch (a.hair) {
    case 'long' || 'wavy':
      b.write(
        '<path d="M60 88 C56 52 78 40 100 40 C124 40 146 54 140 90 C130 72 112 60 100 58 C94 70 76 80 60 88 Z" fill="$hair"/>',
      );
    case 'short':
      b.write(
        '<path d="M60 92 C56 52 80 38 100 38 C124 38 146 52 140 92 C136 74 124 64 102 62 C86 62 68 70 60 92 Z" fill="$hair"/>',
      );
    case 'sidepart':
      b.write(
        '<path d="M60 92 C56 50 80 38 102 38 C126 38 146 52 140 90 C134 72 122 60 86 60 C76 66 66 76 60 92 Z" fill="$hair"/>'
        '<path d="M86 60 C96 50 112 46 124 50" fill="none" stroke="#000" stroke-opacity="0.15" stroke-width="3" stroke-linecap="round"/>',
      );
    case 'buzz':
      b.write(
        '<path d="M62 84 C60 52 80 44 100 44 C120 44 140 52 138 84 C130 66 116 58 100 58 C84 58 70 66 62 84 Z" fill="$hair" opacity="0.92"/>',
      );
    case 'bob':
      b.write(
        '<path d="M58 96 C54 50 80 40 104 40 C126 40 146 54 142 92 C134 70 116 62 96 60 C84 70 70 82 58 96 Z" fill="$hair"/>',
      );
    case 'curly' || 'shortcurly':
      final r = a.hair == 'curly' ? 15.0 : 12.0;
      final pts = a.hair == 'curly'
          ? [
              (58, 86),
              (56, 66),
              (66, 48),
              (84, 38),
              (100, 34),
              (116, 38),
              (134, 48),
              (144, 66),
              (142, 86),
              (52, 106),
              (148, 106),
              (54, 124),
              (146, 124),
            ]
          : [
              (62, 80),
              (64, 62),
              (78, 48),
              (96, 42),
              (114, 44),
              (130, 52),
              (138, 68),
              (138, 82),
            ];
      for (final (x, y) in pts) {
        b.write('<circle cx="$x" cy="$y" r="$r" fill="$hair"/>');
      }
      b.write(
        '<path d="M64 80 C70 62 86 56 100 56 C116 56 130 62 136 80 C128 68 114 66 100 66 C86 66 72 70 64 80 Z" fill="$hair"/>',
      );
    case 'bun':
      b.write(
        '<circle cx="100" cy="36" r="18" fill="$hair"/>'
        '<path d="M60 92 C56 54 80 44 100 44 C124 44 146 54 140 92 C134 72 118 62 100 62 C82 62 66 72 60 92 Z" fill="$hair"/>',
      );
    case 'ponytail':
      b.write(
        '<path d="M60 90 C56 52 80 40 100 40 C124 40 146 54 140 90 C132 70 116 60 100 60 C84 60 68 70 60 90 Z" fill="$hair"/>',
      );
    case 'locs':
      b.write(
        '<path d="M60 92 C56 50 80 38 100 38 C124 38 146 52 140 92 C134 72 118 60 100 60 C82 60 66 72 60 92 Z" fill="$hair"/>',
      );
    case 'bald':
      b.write(
        '<path d="M58 100 C56 84 60 76 66 72 C66 86 64 94 66 104 Z M142 100 C144 84 140 76 134 72 C134 86 136 94 134 104 Z" fill="$hair"/>',
      );
    case 'headscarf':
      b.write(
        '<path d="M58 96 C56 56 78 42 100 42 C122 42 144 56 142 96 C136 70 120 58 100 58 C80 58 64 70 58 96 Z" fill="${a.shirt}"/>'
        '<path d="M58 96 C56 56 78 42 100 42 C122 42 144 56 142 96" fill="none" stroke="#000" stroke-opacity="0.12" stroke-width="4"/>',
      );
  }

  // Rasgos.
  b.write(
    '<path d="M76 82 Q84 77 92 82 M108 82 Q116 77 124 82" fill="none" stroke="${a.color == 'gray' ? '#8C8884' : hair}" stroke-width="3.5" stroke-linecap="round"/>',
  );
  b.write(
    '<circle cx="84" cy="94" r="4.6" fill="$_ink"/><circle cx="116" cy="94" r="4.6" fill="$_ink"/>'
    '<circle cx="85.6" cy="92.4" r="1.6" fill="#fff"/><circle cx="117.6" cy="92.4" r="1.6" fill="#fff"/>',
  );
  b.write(
    '<path d="M100 98 Q95 108 100 110" fill="none" stroke="$shade" stroke-width="3" stroke-linecap="round"/>',
  );
  if (a.beard) {
    b.write(
      '<path d="M62 100 C64 130 82 142 100 142 C118 142 136 130 138 100 C132 116 120 122 100 122 C80 122 68 116 62 100 Z" fill="$hair"/>',
    );
    b.write(
      '<path d="M88 122 Q100 130 112 122" fill="none" stroke="#FFF" stroke-opacity="0.85" stroke-width="3" stroke-linecap="round"/>',
    );
  } else {
    b.write(
      '<path d="M88 118 Q100 127 112 118" fill="none" stroke="#9E4A4A" stroke-width="3.2" stroke-linecap="round"/>',
    );
  }
  b.write(
    '<circle cx="72" cy="110" r="7" fill="$_cheek" opacity="0.3"/><circle cx="128" cy="110" r="7" fill="$_cheek" opacity="0.3"/>',
  );
  if (a.glasses) {
    b.write(
      '<rect x="70" y="84" width="27" height="21" rx="9" fill="none" stroke="$_ink" stroke-width="3"/>'
      '<rect x="103" y="84" width="27" height="21" rx="9" fill="none" stroke="$_ink" stroke-width="3"/>'
      '<path d="M97 92 L103 92" stroke="$_ink" stroke-width="3"/>',
    );
  }
  return b.toString();
}
