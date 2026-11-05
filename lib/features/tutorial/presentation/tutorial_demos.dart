import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/visuals/avatar_catalog.dart';
import '../../../core/widgets/visuals.dart';

/// Pantallas simuladas del recorrido. Todo es de ejemplo: no se crean
/// cuentas, no se guardan datos ni se envían avisos.
enum TutorialDemo {
  chooseRole,
  register,
  createClass,
  createFamily,
  studentProfile,
  inviteCode,
  joinCode,
  pickPictograms,
  listenAndSend,
  receiveRequest,
  switchProfile,
  urgentHelp,
}

/// Simulación interactiva de un paso: resalta el elemento que hay que tocar
/// y avanza por sus fases al tocarlo. "Siguiente" funciona siempre, así que
/// probarla es opcional (también con lector de pantalla o teclado).
class TutorialDemoView extends StatefulWidget {
  const TutorialDemoView({
    super.key,
    required this.demo,
    required this.accent,
    this.roleLabel,
  });

  final TutorialDemo demo;
  final Color accent;

  /// Rol del recorrido, para el paso "Elige tu perfil".
  final String? roleLabel;

  @override
  State<TutorialDemoView> createState() => _TutorialDemoViewState();
}

class _TutorialDemoViewState extends State<TutorialDemoView> {
  int _phase = 0;

  void _advance() => setState(() => _phase++);

  @override
  void didUpdateWidget(covariant TutorialDemoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demo != widget.demo) _phase = 0;
  }

  @override
  Widget build(BuildContext context) {
    return _MockFrame(
      accent: widget.accent,
      child: switch (widget.demo) {
        TutorialDemo.chooseRole => _chooseRole(),
        TutorialDemo.register => _register(),
        TutorialDemo.createClass => _createClass(),
        TutorialDemo.createFamily => _createFamily(),
        TutorialDemo.studentProfile => _studentProfile(),
        TutorialDemo.inviteCode => _inviteCode(),
        TutorialDemo.joinCode => _joinCode(),
        TutorialDemo.pickPictograms => _pickPictograms(),
        TutorialDemo.listenAndSend => _listenAndSend(),
        TutorialDemo.receiveRequest => _receiveRequest(),
        TutorialDemo.switchProfile => _switchProfile(),
        TutorialDemo.urgentHelp => _urgentHelp(),
      },
    );
  }

  Spotlight _spot(String label, Widget child, {bool active = true}) =>
      Spotlight(
        key: Key('tour-target-${widget.demo.name}-$_phase'),
        label: label,
        accent: widget.accent,
        active: active,
        onTap: active ? _advance : null,
        child: child,
      );

  Widget _chooseRole() {
    final chosen = widget.roleLabel ?? 'Docente';
    return Column(
      children: [
        const _MockTitle('Crear una cuenta'),
        const Text('Selecciona cómo utilizarás Mi Voz'),
        const SizedBox(height: 8),
        if (_phase == 0)
          _spot(
            'Abrir "Tipo de perfil" y elegir "$chosen"',
            const _MockField('Tipo de perfil', 'Selecciona una opción'),
          )
        else ...[
          _MockField('Tipo de perfil', chosen),
          for (final role in const [
            'Docente',
            'Padre, madre o tutor',
            'Alumno',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _MockTile(role, selected: role == chosen),
            ),
          const _MockButton('Continuar'),
          const _Done(
            'Una sola opción a la vez. Al iniciar sesión después no se '
            'vuelve a preguntar.',
          ),
        ],
      ],
    );
  }

  Widget _register() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _MockTitle('Crear cuenta'),
      const _MockField('Nombre', 'Ana (ejemplo)'),
      const _MockField('Correo', 'ana@ejemplo.mx'),
      const _MockField('Contraseña', '••••••••'),
      const SizedBox(height: 8),
      _spot(
        'Crear cuenta',
        const _MockButton('Crear cuenta'),
        active: _phase == 0,
      ),
      if (_phase > 0)
        const _Done('Cuenta de ejemplo: en el recorrido no se guarda nada.'),
    ],
  );

  Widget _createClass() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _MockTitle('Mis clases'),
      if (_phase == 0) ...[
        const Text('Aún no tienes clases', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        _spot(
          'Crear mi primera clase',
          const _MockButton('Crear mi primera clase'),
        ),
      ] else ...[
        const _MockCard(
          _Art.icon(Icons.school_rounded),
          '1.º A (ejemplo)',
          'Grupo de la mañana · 0 alumnos',
        ),
        const _Done('Clase creada. Ahora invita a las familias.'),
      ],
    ],
  );

  Widget _createFamily() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _MockTitle('Mi familia'),
      if (_phase == 0)
        _spot('Crear mi familia', const _MockButton('Crear mi familia'))
      else ...[
        const _MockCard(
          _Art.icon(Icons.home_rounded),
          'Familia Ejemplo',
          'Tú eres quien la administra',
        ),
        if (_phase == 1)
          _spot('Agregar niño', const _MockButton('+ Agregar niño'))
        else ...[
          const _MockCard(
            _Art.avatar('animal_panda'),
            'Leo (ejemplo)',
            'Sin clase vinculada',
          ),
          const _Done('Perfil creado: el niño no necesita correo.'),
        ],
      ],
    ],
  );

  Widget _studentProfile() => Column(
    children: [
      const _MockTitle('Tu avatar'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final a in const [
            'animal_lion',
            'animal_panda',
            'animal_fox',
            'animal_turtle',
          ])
            a == 'animal_panda'
                ? _spot(
                    'Elegir el panda',
                    _AvatarBubble(a, selected: _phase > 0),
                    active: _phase == 0,
                  )
                : _AvatarBubble(a),
        ],
      ),
      if (_phase > 0)
        const _Done('Un adulto guarda tu perfil. Tú no necesitas contraseña.'),
    ],
  );

  Widget _inviteCode() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _MockCard(
        _Art.icon(Icons.school_rounded),
        '1.º A (ejemplo)',
        'Invitaciones',
      ),
      const SizedBox(height: 8),
      if (_phase == 0)
        _spot('Invitar', const _MockButton('Invitar'))
      else ...[
        const Icon(Icons.qr_code_2_rounded, size: 96),
        const Text(
          'AB12CD34',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const Text(
          'Válido 7 días · 30 usos · requiere tu aprobación',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
        ),
        const _Done('Código de ejemplo: compártelo con las familias.'),
      ],
    ],
  );

  Widget _joinCode() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _MockTitle('Tengo un código'),
      const _MockField('Código', 'AB12CD34'),
      if (_phase == 0)
        _spot('Comprobar el código', const _MockButton('Comprobar'))
      else ...[
        const _MockCard(
          _Art.icon(Icons.school_rounded),
          '1.º A (ejemplo)',
          'Invitación de Ana (ejemplo)',
        ),
        if (_phase == 1)
          _spot('Enviar solicitud', const _MockButton('Enviar solicitud'))
        else
          const _Done('Solicitud de ejemplo enviada: la docente la aprueba.'),
      ],
    ],
  );

  Widget _pickPictograms() {
    final tiles = _phase == 0
        ? const [
            ('cat_quiero', 'QUIERO'),
            ('cat_necesito', 'NECESITO'),
            ('cat_me_siento', 'ME SIENTO'),
            ('cat_me_molesta', 'ME MOLESTA'),
          ]
        : const [
            ('quiero_agua', 'Agua'),
            ('necesito_comer', 'Comer'),
            ('quiero_jugar', 'Jugar'),
            ('necesito_bano', 'Baño'),
          ];
    final target = _phase == 0 ? 'QUIERO' : 'Agua';
    return Column(
      children: [
        _PhraseBar(_phase < 2 ? (_phase == 0 ? '' : 'Quiero…') : 'Quiero agua'),
        const SizedBox(height: 10),
        // Filas de dos con altura libre: el resaltado y el texto ampliado
        // caben sin recortarse.
        for (var row = 0; row < tiles.length; row += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (emoji, label) in tiles.sublist(row, row + 2)) ...[
                  Expanded(
                    child: label == target && _phase < 2
                        ? _spot('Tocar "$label"', _PictoTile(emoji, label))
                        : _PictoTile(emoji, label),
                  ),
                  if (label != tiles[row + 1].$2) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        if (_phase >= 2) const _Done('La frase se formó sola.'),
      ],
    );
  }

  Widget _listenAndSend() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _PhraseBar('Quiero agua'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _phase == 0
                ? _spot(
                    'Escuchar',
                    const _MockButton(
                      'ESCUCHAR',
                      icon: Icons.volume_up_rounded,
                    ),
                  )
                : const _MockButton('ESCUCHAR', icon: Icons.volume_up_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _phase == 1
                ? _spot(
                    'Comunicar',
                    const _MockButton(
                      'COMUNICAR',
                      icon: Icons.campaign_rounded,
                    ),
                  )
                : const _MockButton('COMUNICAR', icon: Icons.campaign_rounded),
          ),
        ],
      ),
      if (_phase == 1)
        const _Done('Se lee en voz alta (aquí no suena). Ahora COMUNICAR.'),
      if (_phase >= 2) ...[
        const SizedBox(height: 8),
        const _MockCard(
          _Art.icon(Icons.check_circle_rounded),
          'Aviso enviado a Ana (ejemplo)',
          'Todavía no sabemos si ya lo vio',
        ),
        const _Done('Sin internet diría "Todavía no se envió".'),
      ],
    ],
  );

  Widget _receiveRequest() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_phase == 0)
        _spot(
          'Abrir el aviso',
          const _MockCard(
            _Art.icon(Icons.notifications_active_rounded),
            'Leo (ejemplo) necesita atención',
            '"Quiero agua"',
          ),
        )
      else ...[
        const _MockCard(
          _Art.symbol('quiero_agua'),
          'Quiero agua',
          'Leo (ejemplo) · Vista',
        ),
        const SizedBox(height: 8),
        if (_phase == 1)
          _spot('Voy en camino', const _MockButton('Voy en camino'))
        else if (_phase == 2)
          _spot(
            'Marcar como resuelta',
            const _MockButton('Marcar como resuelta'),
          )
        else
          const _Done('Resuelta. Leo vio "Ana viene a ayudarte".'),
      ],
    ],
  );

  Widget _switchProfile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_phase == 0) ...[
        const _MockTitle('¡Hola, Leo!'),
        Align(
          alignment: Alignment.centerRight,
          child: _spot(
            'Cambiar perfil',
            const _MockButton(
              'Cambiar perfil',
              icon: Icons.switch_account_rounded,
            ),
          ),
        ),
      ] else if (_phase == 1) ...[
        const _MockTitle('Solo para adultos'),
        const _MockField('PIN', '••••'),
        _spot('Continuar', const _MockButton('Continuar')),
      ] else ...[
        const _MockTitle('Preferencias de Leo'),
        const _MockSwitch('Voz al tocar un pictograma', true),
        const _MockSwitch('Pictogramas grandes', true),
        if (_phase == 2)
          _spot('Modo tranquilo', const _MockSwitch('Modo tranquilo', false))
        else ...[
          const _MockSwitch('Modo tranquilo', true),
          const _Done('Sin sonidos ni animaciones, colores suaves.'),
        ],
      ],
    ],
  );

  Widget _urgentHelp() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_phase == 0)
        _spot(
          'Necesito ayuda ya',
          const _MockButton(
            'NECESITO AYUDA YA',
            icon: Icons.sos_rounded,
            urgent: true,
          ),
        )
      else if (_phase == 1) ...[
        const _MockTitle('¿Quieres avisar a tu adulto?'),
        _spot('Sí, avisar', const _MockButton('SÍ, AVISAR', urgent: true)),
      ] else ...[
        const _MockCard(
          _Art.icon(Icons.check_circle_rounded),
          'Aviso enviado',
          'Todavía no sabemos si ya lo vio',
        ),
        const _Done(
          'Si nadie viene, busca a un adulto cerca. No sustituye al 911.',
        ),
      ],
    ],
  );
}

/// Resalta un elemento con un anillo (que late, salvo que se pida reducir
/// el movimiento) y la indicación "Toca aquí".
class Spotlight extends StatefulWidget {
  const Spotlight({
    super.key,
    required this.label,
    required this.child,
    required this.accent,
    this.onTap,
    this.active = true,
  });

  final String label;
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<Spotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !reduce) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return Semantics(
      button: true,
      label: 'Resaltado: ${widget.label}. Toca para probar.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Toca aquí',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(
                        alpha: 0.15 + 0.35 * _pulse.value,
                      ),
                      blurRadius: 6 + 10 * _pulse.value,
                      spreadRadius: 1 + 3 * _pulse.value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas de las pantallas simuladas
// ---------------------------------------------------------------------------

class _MockFrame extends StatelessWidget {
  const _MockFrame({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('tour-demo'),
    constraints: const BoxConstraints(maxWidth: 380),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.black26, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: accent.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Text(
            'SIMULACIÓN · EJEMPLO FICTICIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ],
    ),
  );
}

class _MockTitle extends StatelessWidget {
  const _MockTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );
}

class _MockTile extends StatelessWidget {
  const _MockTile(this.label, {this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Icon(
          selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: selected ? AppColors.success : AppColors.inkSoft,
        ),
      ],
    ),
  );
}

class _MockField extends StatelessWidget {
  const _MockField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}

class _MockButton extends StatelessWidget {
  const _MockButton(this.label, {this.icon, this.urgent = false});

  final String label;
  final IconData? icon;
  final bool urgent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: urgent ? AppColors.urgent : AppColors.primary,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MockCard extends StatelessWidget {
  const _MockCard(this.leading, this.title, this.subtitle);

  final _Art leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        SizedBox.square(dimension: 36, child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MockSwitch extends StatelessWidget {
  const _MockSwitch(this.label, this.on);

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Icon(
          on ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
          size: 40,
          color: on ? AppColors.success : AppColors.inkSoft,
        ),
        Text(on ? 'Sí' : 'No'),
      ],
    ),
  );
}

class _PhraseBar extends StatelessWidget {
  const _PhraseBar(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary, width: 2),
    ),
    child: Text(
      text.isEmpty ? 'Tu frase aparecerá aquí' : text,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: text.isEmpty ? AppColors.inkSoft : AppColors.ink,
      ),
    ),
  );
}

class _PictoTile extends StatelessWidget {
  const _PictoTile(this.symbol, this.label);

  final String symbol;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SymbolImage(symbol, size: 40),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble(this.avatar, {this.selected = false});

  final String avatar;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? AppColors.success : Colors.black12,
        width: selected ? 3 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: AvatarArtImage(art: AvatarCatalog.byId(avatar)!, size: 64),
  );
}

class _Done extends StatelessWidget {
  const _Done(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: const Key('tour-demo-done'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Imagen de las tarjetas de ejemplo: icono de interfaz, avatar o
/// pictograma (las mismas familias visuales que la app real).
class _Art extends StatelessWidget {
  const _Art.icon(IconData this._icon) : _avatar = null, _symbol = null;
  const _Art.avatar(String this._avatar) : _icon = null, _symbol = null;
  const _Art.symbol(String this._symbol) : _icon = null, _avatar = null;

  final IconData? _icon;
  final String? _avatar;
  final String? _symbol;

  @override
  Widget build(BuildContext context) {
    if (_avatar != null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Color(0xFFDCEBFF),
          shape: BoxShape.circle,
        ),
        child: AvatarArtImage(art: AvatarCatalog.byId(_avatar)!, size: 36),
      );
    }
    if (_symbol != null) return SymbolImage(_symbol, size: 36);
    return Icon(_icon, size: 30, color: AppColors.primary);
  }
}
