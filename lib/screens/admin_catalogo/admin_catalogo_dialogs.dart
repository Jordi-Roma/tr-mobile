import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/admin_catalogo_models.dart';
import '../../services/admin_catalogo_service.dart';

// ── DIÁLOGO TALLA ─────────────────────────────────────────────

class AdminTallaDialog extends StatefulWidget {
  final AdminTalla? talla;

  const AdminTallaDialog({super.key, this.talla});

  static Future<bool?> show(BuildContext context, {AdminTalla? talla}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AdminTallaDialog(talla: talla),
    );
  }

  @override
  State<AdminTallaDialog> createState() => _AdminTallaDialogState();
}

class _AdminTallaDialogState extends State<AdminTallaDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _anchoCtrl;
  late TextEditingController _largoCtrl;
  String _tipoPrenda = 'SUPERIOR';
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.talla != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.talla?.nombre ?? '');
    _descCtrl = TextEditingController(text: widget.talla?.descripcion ?? '');
    _anchoCtrl = TextEditingController(text: widget.talla?.anchoCm?.toString() ?? '');
    _largoCtrl = TextEditingController(text: widget.talla?.largoCm?.toString() ?? '');
    _tipoPrenda = widget.talla?.tipoPrenda ?? 'SUPERIOR';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _anchoCtrl.dispose();
    _largoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final ancho = _anchoCtrl.text.trim().isNotEmpty ? double.tryParse(_anchoCtrl.text.trim()) : null;
      final largo = _largoCtrl.text.trim().isNotEmpty ? double.tryParse(_largoCtrl.text.trim()) : null;

      if (_esEdicion) {
        await AdminCatalogoService.actualizarTalla(
          id: widget.talla!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          tipoPrenda: _tipoPrenda,
          anchoCm: ancho,
          largoCm: largo,
        );
      } else {
        await AdminCatalogoService.crearTalla(
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          tipoPrenda: _tipoPrenda,
          anchoCm: ancho,
          largoCm: largo,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String anchoLabel = 'Ancho Pecho (cm)';
    String anchoHint = 'Ej: 53.0';
    String largoLabel = 'Largo Torso (cm)';
    String largoHint = 'Ej: 72.0';

    if (_tipoPrenda == 'INFERIOR') {
      anchoLabel = 'Cintura (cm)';
      anchoHint = 'Ej: 40.0';
      largoLabel = 'Largo Pierna (cm)';
      largoHint = 'Ej: 102.0';
    } else if (_tipoPrenda == 'VESTIDO') {
      anchoLabel = 'Busto / Torso (cm)';
      anchoHint = 'Ej: 46.0';
      largoLabel = 'Largo Vestido (cm)';
      largoHint = 'Ej: 120.0';
    }

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar Talla' : 'Nueva Talla'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _tipoPrenda,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Prenda *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SUPERIOR', child: Text('Prenda Superior')),
                    DropdownMenuItem(value: 'INFERIOR', child: Text('Prenda Inferior / Pantalón')),
                    DropdownMenuItem(value: 'VESTIDO', child: Text('Vestido / Enterizo')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _tipoPrenda = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de la Talla *', hintText: 'Ej: S, M, L, 32, 40', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Opcional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Medidas Base Estándar (RA):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _anchoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: anchoLabel, hintText: anchoHint, border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _largoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: largoLabel, hintText: largoHint, border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _guardando ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── DIÁLOGO CATEGORÍA ─────────────────────────────────────────

class AdminCategoriaDialog extends StatefulWidget {
  final AdminCategoria? categoria;
  final List<AdminCategoria> categoriasPadreDisponibles;

  const AdminCategoriaDialog({super.key, this.categoria, required this.categoriasPadreDisponibles});

  static Future<bool?> show(BuildContext context, {AdminCategoria? categoria, required List<AdminCategoria> categoriasPadre}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AdminCategoriaDialog(categoria: categoria, categoriasPadreDisponibles: categoriasPadre),
    );
  }

  @override
  State<AdminCategoriaDialog> createState() => _AdminCategoriaDialogState();
}

class _AdminCategoriaDialogState extends State<AdminCategoriaDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  int? _padreId;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.categoria?.nombre ?? '');
    _descCtrl = TextEditingController(text: widget.categoria?.descripcion ?? '');
    _padreId = widget.categoria?.categoriaPadreId;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await AdminCatalogoService.actualizarCategoria(
          id: widget.categoria!.id,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          categoriaPadreId: _padreId,
        );
      } else {
        await AdminCatalogoService.crearCategoria(
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          categoriaPadreId: _padreId,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar Categoría' : 'Nueva Categoría'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej: Poleras, Pantalones', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Opcional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _padreId,
                  decoration: const InputDecoration(labelText: 'Categoría Padre', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Ninguna (Principal)')),
                    ...widget.categoriasPadreDisponibles
                        .where((c) => widget.categoria == null || c.id != widget.categoria!.id)
                        .map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nombre))),
                  ],
                  onChanged: (v) => setState(() => _padreId = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _guardando ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── DIÁLOGO COLOR ─────────────────────────────────────────────

class AdminColorDialog extends StatefulWidget {
  final AdminColor? color;

  const AdminColorDialog({super.key, this.color});

  static Future<bool?> show(BuildContext context, {AdminColor? color}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AdminColorDialog(color: color),
    );
  }

  @override
  State<AdminColorDialog> createState() => _AdminColorDialogState();
}

class _AdminColorDialogState extends State<AdminColorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _hexCtrl;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.color != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.color?.nombre ?? '');
    _hexCtrl = TextEditingController(text: widget.color?.codigoHex ?? '#000000');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await AdminCatalogoService.actualizarColor(
          id: widget.color!.id,
          nombre: _nombreCtrl.text.trim(),
          codigoHex: _hexCtrl.text.trim().isEmpty ? null : _hexCtrl.text.trim(),
        );
      } else {
        await AdminCatalogoService.crearColor(
          nombre: _nombreCtrl.text.trim(),
          codigoHex: _hexCtrl.text.trim().isEmpty ? null : _hexCtrl.text.trim(),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar Color' : 'Nuevo Color'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej: Azul Marino, Blanco', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hexCtrl,
                        decoration: const InputDecoration(labelText: 'Código Hex', hintText: '#1E3A8A', border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _parseHex(_hexCtrl.text),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _guardando ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar'),
        ),
      ],
    );
  }
}
