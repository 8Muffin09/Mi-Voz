import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mi_voz_logo.dart';
import '../../../models/app_user.dart';
import '../application/access_providers.dart';
import 'widgets/role_illustration.dart';

/// "Crear una cuenta": un único selector de "Tipo de perfil" y "Continuar".
///
/// El rol no viene preseleccionado. Elegirlo solo decide qué formulario se
/// abre (y qué panel se muestra después): nunca concede acceso a una clase,
/// familia o perfil existente; eso solo lo da un código de invitación
/// validado en el servidor.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  AccessRole? _role;
  String? _error;

  Future<void> _continue() async {
    final role = _role;
    if (role == null) {
      setState(() => _error = 'Selecciona un tipo de perfil para continuar.');
      return;
    }
    final pending = ref.read(pendingStudentProfileProvider.notifier);
    final experience = ref.read(selectedExperienceProvider.notifier);
    switch (role) {
      case AccessRole.teacher:
        pending.set(false);
        await experience.select(UserExperience.teacher);
        if (mounted) await context.push(Routes.register);
      case AccessRole.guardian:
        pending.set(false);
        await experience.select(UserExperience.guardian);
        if (mounted) await context.push(Routes.register);
      case AccessRole.child:
        if (mounted) await context.push(Routes.createStudent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MiVozLogo(size: 88)),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Crear una cuenta',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona cómo utilizarás Mi Voz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 28),
                  RoleSelectorField(
                    key: const Key('role-selector'),
                    value: _role,
                    errorText: _error,
                    onChanged: (r) => setState(() {
                      _role = r;
                      _error = null;
                    }),
                  ),
                  if (_role != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _role!.description,
                      key: const Key('role-description'),
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('role-continue'),
                    onPressed: _continue,
                    child: const Text('Continuar'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('¿Ya tienes una cuenta?'),
                      TextButton(
                        key: const Key('role-login'),
                        onPressed: () {
                          ref
                              .read(pendingStudentProfileProvider.notifier)
                              .set(false);
                          context.push(Routes.login);
                        },
                        child: const Text('Iniciar sesión'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo "Tipo de perfil". En pantallas estrechas abre un panel inferior con
/// la lista; en pantallas anchas (escritorio, tableta horizontal) un menú
/// desplegable. En ambos casos: una sola selección, la activa marcada con
/// palomita (no solo color), se cierra al elegir y funciona con teclado
/// (Tab, Intro/Espacio, flechas, Esc) y lector de pantalla.
class RoleSelectorField extends StatefulWidget {
  const RoleSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final AccessRole? value;
  final ValueChanged<AccessRole> onChanged;
  final String? errorText;

  /// A partir de este ancho se usa el menú desplegable.
  static const menuBreakpoint = 600.0;

  @override
  State<RoleSelectorField> createState() => _RoleSelectorFieldState();
}

class _RoleSelectorFieldState extends State<RoleSelectorField> {
  final _menu = MenuController();
  final _focus = FocusNode(debugLabel: 'role-selector');
  bool _open = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _wide =>
      MediaQuery.sizeOf(context).width >= RoleSelectorField.menuBreakpoint;

  Future<void> _openSheet() async {
    setState(() => _open = true);
    final picked = await showModalBottomSheet<AccessRole>(
      context: context,
      showDragHandle: true,
      // Con texto ampliado o pantallas bajas la lista se desplaza en lugar
      // de cortarse.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Tipo de perfil',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final r in AccessRole.values)
                _RoleOptionTile(
                  role: r,
                  selected: r == widget.value,
                  onTap: () => Navigator.of(context).pop(r),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    _focus.requestFocus();
    if (picked != null) widget.onChanged(picked);
  }

  void _toggle() {
    if (_wide) {
      _menu.isOpen ? _menu.close() : _menu.open();
    } else {
      _openSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final field = Semantics(
      button: true,
      expanded: _open,
      label: 'Tipo de perfil',
      value: value?.label ?? 'Selecciona una opción',
      hint: widget.errorText,
      excludeSemantics: true,
      child: InkWell(
        focusNode: _focus,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: _toggle,
        child: InputDecorator(
          isFocused: _focus.hasFocus || _open,
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'Tipo de perfil',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: widget.errorText,
            prefixIcon: value == null
                ? const Icon(Icons.badge_outlined)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: RoleIllustration(role: value, size: 32),
                  ),
            suffixIcon: Icon(
              _open
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
            ),
          ),
          child: Text(
            value?.label ?? 'Selecciona una opción',
            key: const Key('role-selector-value'),
            style: TextStyle(
              fontSize: 17,
              color: value == null ? AppColors.inkSoft : AppColors.ink,
              fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return MenuAnchor(
      controller: _menu,
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final r in AccessRole.values)
          MenuItemButton(
            key: Key('role-option-${r.name}'),
            leadingIcon: SizedBox(
              width: 24,
              child: r == value ? const Icon(Icons.check_rounded) : null,
            ),
            onPressed: () {
              widget.onChanged(r);
              _focus.requestFocus();
            },
            child: Semantics(
              selected: r == value,
              inMutuallyExclusiveGroup: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(r.label, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => field,
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  const _RoleOptionTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AccessRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    button: true,
    label: role.label,
    excludeSemantics: true,
    child: ListTile(
      key: Key('role-option-${role.name}'),
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: RoleIllustration(role: role, size: 44),
      title: Text(
        role.label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(role.description),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: onTap,
    ),
  );
}
