import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/presentation/widgets/role_illustration.dart';
import 'tutorial_demos.dart';

/// Paso del recorrido: instrucción breve y pantalla simulada para probarla.
class TutorialStep {
  const TutorialStep(this.title, this.text, this.demo);

  final String title;
  final String text;
  final TutorialDemo demo;
}

/// Recorridos por rol.
class TutorialContent {
  const TutorialContent._();

  static const _phrase = [
    TutorialStep(
      'Elegir pictogramas',
      'El niño toca una categoría grande y después un pictograma. Mi Voz arma '
          'la frase con buena gramática.',
      TutorialDemo.pickPictograms,
    ),
    TutorialStep(
      'Escuchar y comunicar',
      'ESCUCHAR la lee en voz alta. COMUNICAR avisa al adulto que acompaña y '
          'el niño ve si el aviso se envió o no.',
      TutorialDemo.listenAndSend,
    ),
  ];

  static const _receive = TutorialStep(
    'Recibir y atender una solicitud',
    'Llega el aviso al adulto que acompaña (o a quien eligió la familia si '
        'nadie acompaña). Al marcar "Voy en camino", el niño lo ve.',
    TutorialDemo.receiveRequest,
  );

  static const _switch = TutorialStep(
    'Cambiar de perfil y ajustar preferencias',
    'Salir del modo infantil pide el PIN o la contraseña del adulto. La voz, '
        'el tamaño y el modo tranquilo se ajustan para cada niño.',
    TutorialDemo.switchProfile,
  );

  static const teacher = [
    TutorialStep(
      'Elige tu perfil',
      'En "Comenzar → Crear una cuenta", abre "Tipo de perfil" y elige '
          '"Docente". Al volver a entrar solo inicias sesión.',
      TutorialDemo.chooseRole,
    ),
    TutorialStep(
      'Regístrate',
      'Nombre, correo y contraseña. Elegir "docente" no da acceso a ningún '
          'alumno: el acceso llega cuando una familia lo autoriza.',
      TutorialDemo.register,
    ),
    TutorialStep(
      'Crea tu clase',
      'Puedes tener varias clases; un mismo alumno puede estar en más de una.',
      TutorialDemo.createClass,
    ),
    TutorialStep(
      'Incorpora alumnos con código o QR',
      'Genera una invitación con caducidad y límite de usos. Cada familia la '
          'escribe o escanea, elige a su hijo y tú apruebas la solicitud.',
      TutorialDemo.inviteCode,
    ),
    ..._phrase,
    _receive,
    _switch,
  ];

  static const guardian = [
    TutorialStep(
      'Elige tu perfil',
      'En "Comenzar → Crear una cuenta", abre "Tipo de perfil" y elige '
          '"Padre, madre o tutor".',
      TutorialDemo.chooseRole,
    ),
    TutorialStep(
      'Regístrate',
      'Nombre, correo y contraseña. Solo los adultos tienen cuenta.',
      TutorialDemo.register,
    ),
    TutorialStep(
      'Crea tu familia y el perfil de tu hijo',
      'El perfil del niño solo necesita un nombre y un avatar ilustrado; la '
          'foto es opcional.',
      TutorialDemo.createFamily,
    ),
    TutorialStep(
      'Vincula a tu hijo con su clase',
      'Escribe o escanea el código que te dé el docente, revisa la clase y '
          'envía la solicitud. Al otro tutor lo invitas con el código de tu '
          'familia.',
      TutorialDemo.joinCode,
    ),
    ..._phrase,
    _receive,
    _switch,
  ];

  static const student = [
    TutorialStep(
      'Tu perfil lo crea un adulto',
      'Pide a tu mamá, papá o tutor que cree tu perfil. Tú eliges tu avatar.',
      TutorialDemo.studentProfile,
    ),
    ..._phrase,
    TutorialStep(
      'Pedir ayuda',
      'NECESITO AYUDA YA avisa a tu adulto y te dice si el aviso se pudo '
          'enviar. No sustituye a los servicios de emergencia.',
      TutorialDemo.urgentHelp,
    ),
  ];

  static List<TutorialStep> forRole(AccessRole role) => switch (role) {
    AccessRole.teacher => teacher,
    AccessRole.guardian => guardian,
    AccessRole.child => student,
  };

  static String label(AccessRole role) => switch (role) {
    AccessRole.teacher => 'Docente',
    AccessRole.guardian => 'Padre, madre o tutor',
    AccessRole.child => 'Alumno',
  };
}

/// "Conocer cómo funciona": recorrido guiado e interactivo según el rol. Las
/// pantallas son simulaciones: no crea cuentas, no envía avisos ni modifica
/// datos. Con [initialRole] (desde Ayuda, con sesión) empieza en ese rol.
///
/// Teclado: ← y → cambian de paso; Esc cierra el recorrido.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.initialRole});

  final AccessRole? initialRole;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late AccessRole? _role = widget.initialRole;
  int _index = 0;

  List<TutorialStep> get _steps =>
      _role == null ? const [] : TutorialContent.forRole(_role!);

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.start);
    }
  }

  void _next() {
    if (_role == null) return;
    if (_index < _steps.length - 1) {
      setState(() => _index++);
    } else {
      _close();
    }
  }

  void _previous() => setState(() {
    if (_role == null) return;
    if (_index > 0) {
      _index--;
    } else if (widget.initialRole == null) {
      _role = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final role = _role;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Conocer cómo funciona'),
            actions: [
              TextButton(
                key: const Key('tour-skip'),
                onPressed: _close,
                child: const Text('Omitir'),
              ),
            ],
          ),
          body: SafeArea(child: role == null ? _rolePicker() : _stepView(role)),
        ),
      ),
    );
  }

  Widget _rolePicker() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '¿Qué perfil quieres conocer?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Es una simulación con datos ficticios: no se crea ninguna cuenta '
            'ni se envía nada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          for (final role in const [
            AccessRole.teacher,
            AccessRole.guardian,
            AccessRole.child,
          ]) ...[
            Material(
              color: role.background,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                key: Key('tour-role-${role.name}'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() {
                  _role = role;
                  _index = 0;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      RoleIllustration(role: role, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          TutorialContent.label(role),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: role.accent,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: role.accent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );

  Widget _stepView(AccessRole role) {
    final steps = _steps;
    final step = steps[_index];
    final last = _index == steps.length - 1;
    final first = _index == 0 && widget.initialRole != null;

    final instructions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            step.title,
            key: const Key('tour-title'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(step.text, style: const TextStyle(fontSize: 17, height: 1.4)),
        const SizedBox(height: 8),
        const Text(
          'Prueba tocando lo resaltado, o pulsa "Siguiente".',
          style: TextStyle(color: AppColors.inkSoft),
        ),
      ],
    );
    final demo = Center(
      child: TutorialDemoView(
        key: ValueKey('${role.name}-$_index'),
        demo: step.demo,
        accent: role.accent,
        roleLabel: TutorialContent.label(role),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Paso ${_index + 1} de ${steps.length}',
                child: LinearProgressIndicator(
                  value: (_index + 1) / steps.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Paso ${_index + 1} de ${steps.length} · '
                '${TutorialContent.label(role)}',
                key: const Key('tour-progress'),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // En pantallas anchas (tableta, Windows) la instrucción
                    // y la simulación van lado a lado.
                    if (constraints.maxWidth >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: instructions),
                          const SizedBox(width: 32),
                          Expanded(child: SingleChildScrollView(child: demo)),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          instructions,
                          const SizedBox(height: 16),
                          demo,
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    key: const Key('tour-previous'),
                    onPressed: first ? null : _previous,
                    child: const Text('Anterior'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key(last ? 'tour-finish' : 'tour-next'),
                      onPressed: _next,
                      child: Text(last ? 'Finalizar' : 'Siguiente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
