import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/admin_catalogo_models.dart';
import '../../services/admin_catalogo_service.dart';

class AdminVarianteFormScreen extends StatefulWidget {
  final AdminVarianteItem? variante;
  final int? preselectedProductoId;

  const AdminVarianteFormScreen({super.key, this.variante, this.preselectedProductoId});

  @override
  State<AdminVarianteFormScreen> createState() => _AdminVarianteFormScreenState();
}

class _AdminVarianteFormScreenState extends State<AdminVarianteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _precioFormKey = GlobalKey<FormState>();

  late TextEditingController _skuCtrl;
  late TextEditingController _anchoCtrl;
  late TextEditingController _largoCtrl;
  final TextEditingController _precioMontoCtrl = TextEditingController();

  int? _productoId;
  int? _tallaId;
  int? _colorId;

  List<AdminProductoItem> _productos = [];
  List<AdminTalla> _tallas = [];
  List<AdminColor> _colores = [];
  List<AdminPrecioItem> _precios = [];

  bool _cargandoInicial = true;
  bool _guardando = false;
  bool _guardandoPrecio = false;
  String? _error;
  String? _errorPrecio;

  bool get _esEdicion => widget.variante != null;

  @override
  void initState() {
    super.initState();
    final v = widget.variante;
    _skuCtrl = TextEditingController(text: v?.sku ?? '');
    _anchoCtrl = TextEditingController(text: v?.anchoCm?.toString() ?? '');
    _largoCtrl = TextEditingController(text: v?.largoCm?.toString() ?? '');

    _productoId = v?.productoId ?? widget.preselectedProductoId;
    _tallaId = v?.tallaId;
    _colorId = v?.colorId;
    _precios = v != null ? List.from(v.precios) : [];

    _cargarDatos();
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _anchoCtrl.dispose();
    _largoCtrl.dispose();
    _precioMontoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargandoInicial = true;
      _error = null;
    });

    try {
      final prods = await AdminCatalogoService.listarProductos();
      final tallas = await AdminCatalogoService.listarTallas();
      final colores = await AdminCatalogoService.listarColores();

      if (mounted) {
        setState(() {
          _productos = prods.where((p) => p.activo).toList();
          _tallas = tallas.where((t) => t.activo).toList();
          _colores = colores.where((c) => c.activo).toList();
          if (_productoId == null && _productos.isNotEmpty) {
            _productoId = _productos.first.id;
          }
          _cargandoInicial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar catálogo: $e';
          _cargandoInicial = false;
        });
      }
    }
  }

  /// AUTO-FILL: Al seleccionar una talla, se cargan automáticamente sus medidas
  /// en los campos de la variante, manteniéndolos editables individualmente.
  void _onTallaSeleccionada(int? nuevaTallaId) {
    setState(() {
      _tallaId = nuevaTallaId;
      if (nuevaTallaId != null) {
        final tallaEncontrada = _tallas.where((t) => t.id == nuevaTallaId).firstOrNull;
        if (tallaEncontrada != null) {
          if (tallaEncontrada.anchoCm != null) {
            _anchoCtrl.text = tallaEncontrada.anchoCm.toString();
          }
          if (tallaEncontrada.largoCm != null) {
            _largoCtrl.text = tallaEncontrada.largoCm.toString();
          }
        }
      }
    });
  }

  Future<void> _guardarVariante() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un producto')),
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final ancho = _anchoCtrl.text.trim().isNotEmpty ? double.tryParse(_anchoCtrl.text.trim()) : null;
      final largo = _largoCtrl.text.trim().isNotEmpty ? double.tryParse(_largoCtrl.text.trim()) : null;

      if (_esEdicion) {
        final actualizada = await AdminCatalogoService.actualizarVariante(
          id: widget.variante!.id,
          tallaId: _tallaId,
          colorId: _colorId,
          sku: _skuCtrl.text.trim(),
          anchoCm: ancho,
          largoCm: largo,
        );
        setState(() {
          _precios = actualizada.precios;
          _guardando = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variante actualizada correctamente'), backgroundColor: Colors.green),
          );
        }
      } else {
        await AdminCatalogoService.crearVariante(
          productoId: _productoId!,
          tallaId: _tallaId,
          colorId: _colorId,
          sku: _skuCtrl.text.trim(),
          anchoCm: ancho,
          largoCm: largo,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variante creada correctamente'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  Future<void> _asignarPrecio() async {
    if (!_precioFormKey.currentState!.validate()) return;
    if (widget.variante == null) return;

    final monto = double.tryParse(_precioMontoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      setState(() => _errorPrecio = 'El monto debe ser mayor a 0');
      return;
    }

    setState(() {
      _guardandoPrecio = true;
      _errorPrecio = null;
    });

    try {
      final res = await AdminCatalogoService.asignarPrecio(
        varianteId: widget.variante!.id,
        monto: monto,
      );
      if (mounted) {
        setState(() {
          _precios = res.precios;
          _precioMontoCtrl.clear();
          _guardandoPrecio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nuevo precio vigente asignado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorPrecio = e.toString();
          _guardandoPrecio = false;
        });
      }
    }
  }

  AdminProductoItem? get _productoSeleccionado {
    if (_productoId == null) return null;
    return _productos.where((p) => p.id == _productoId).firstOrNull;
  }

  List<AdminTalla> get _tallasFiltradas {
    final prod = _productoSeleccionado;
    if (prod == null) return _tallas;
    final tipo = prod.tipoPrenda;
    final filtradas = _tallas.where((t) => t.tipoPrenda == tipo).toList();
    return filtradas.isNotEmpty ? filtradas : _tallas;
  }

  @override
  Widget build(BuildContext context) {
    String anchoLabel = 'Ancho (cm)';
    String largoLabel = 'Largo (cm)';
    final prod = _productoSeleccionado;
    if (prod?.tipoPrenda == 'INFERIOR') {
      anchoLabel = 'Cintura (cm)';
      largoLabel = 'Largo Pierna (cm)';
    } else if (prod?.tipoPrenda == 'VESTIDO') {
      anchoLabel = 'Busto / Torso (cm)';
      largoLabel = 'Largo Vestido (cm)';
    } else if (prod?.tipoPrenda == 'SUPERIOR') {
      anchoLabel = 'Ancho Pecho (cm)';
      largoLabel = 'Largo Torso (cm)';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esEdicion ? 'Editar Variante / Talla' : 'Nueva Variante',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 1,
      ),
      body: _cargandoInicial
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                    ),

                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Detalles de la Variante',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                          const Divider(height: 20),

                          DropdownButtonFormField<int>(
                            initialValue: _productoId,
                            decoration: const InputDecoration(
                              labelText: 'Producto *',
                              border: OutlineInputBorder(),
                            ),
                            items: _productos.map((p) {
                              return DropdownMenuItem<int>(
                                value: p.id,
                                child: Text('${p.nombre} (${p.tipoPrenda})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: _esEdicion
                                ? null
                                : (val) {
                                    setState(() {
                                      _productoId = val;
                                      if (_tallaId != null && !_tallasFiltradas.any((t) => t.id == _tallaId)) {
                                        _tallaId = null;
                                        _anchoCtrl.clear();
                                        _largoCtrl.clear();
                                      }
                                    });
                                  },
                            validator: (v) => v == null ? 'Selecciona un producto' : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _skuCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Código SKU *',
                              hintText: 'Ej: POL-CLA-M-BLA',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el SKU' : null,
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  key: ValueKey('talla_${_productoId}_$_tallaId'),
                                  initialValue: _tallasFiltradas.any((t) => t.id == _tallaId) ? _tallaId : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Talla',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Sin Talla / NA')),
                                    ..._tallasFiltradas.map((t) => DropdownMenuItem<int?>(
                                          value: t.id,
                                          child: Text('${t.nombre} [${t.tipoPrenda}]${t.anchoCm != null ? ' (${t.anchoCm?.toStringAsFixed(0)}x${t.largoCm?.toStringAsFixed(0)}cm)' : ''}'),
                                        )),
                                  ],
                                  onChanged: _onTallaSeleccionada,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _colorId,
                                  decoration: const InputDecoration(
                                    labelText: 'Color',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Sin Color / NA')),
                                    ..._colores.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nombre))),
                                  ],
                                  onChanged: (val) => setState(() => _colorId = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // SECCIÓN MEDIDAS INDIVIDUALES PRENDA (RA)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.straighten, color: AppColors.primary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Medidas individuales de la prenda (RA)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Al seleccionar una talla se cargan automáticamente sus medidas estándar. Puedes editarlas libremente para esta prenda individual sin alterar la talla global.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _anchoCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: anchoLabel,
                                          hintText: 'Ej: 54.0',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _largoCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: largoLabel,
                                          hintText: 'Ej: 73.0',
                                          isDense: true,
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: _guardando ? null : _guardarVariante,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _guardando
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(_esEdicion ? 'Actualizar Variante' : 'Crear Variante', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // SECCIÓN PRECIOS (Si está editando)
                  if (_esEdicion) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Form(
                        key: _precioFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Gestión de Precios',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                            ),
                            const Divider(height: 20),

                            if (_errorPrecio != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(_errorPrecio!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _precioMontoCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Monto (Bs.) *',
                                      hintText: '120.00',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _guardandoPrecio ? null : _asignarPrecio,
                                  icon: const Icon(Icons.attach_money, size: 18),
                                  label: const Text('Fijar Precio'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Historial de Precios:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),

                            if (_precios.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: Text('Sin precios asignados aún', style: TextStyle(color: Colors.grey))),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _precios.length,
                                separatorBuilder: (_, index) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final pr = _precios[idx];
                                  final esVigente = idx == 0;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      esVigente ? Icons.verified : Icons.history,
                                      color: esVigente ? Colors.green.shade700 : Colors.grey,
                                    ),
                                    title: Text(
                                      'Bs. ${pr.monto.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: esVigente ? FontWeight.bold : FontWeight.normal,
                                        color: esVigente ? Colors.black87 : Colors.grey.shade700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      esVigente ? 'Precio vigente' : (pr.fechaInicio ?? 'Histórico'),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: esVigente
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              border: Border.all(color: Colors.green.shade300),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text('ACTIVO', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
