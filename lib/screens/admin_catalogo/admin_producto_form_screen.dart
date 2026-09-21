import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/admin_catalogo_models.dart';
import '../../services/admin_catalogo_service.dart';

class AdminProductoFormScreen extends StatefulWidget {
  final AdminProductoItem? producto;

  const AdminProductoFormScreen({super.key, this.producto});

  @override
  State<AdminProductoFormScreen> createState() => _AdminProductoFormScreenState();
}

class _AdminProductoFormScreenState extends State<AdminProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _materialCtrl;
  final TextEditingController _imagenUrlCtrl = TextEditingController();

  int? _categoriaId;
  int? _marcaId;
  String? _genero;
  String _tipoPrenda = 'SUPERIOR';
  String _tipoCorte = 'REGULAR_FIT';
  List<AdminProductoImagen> _imagenes = [];

  List<AdminCategoria> _categorias = [];
  List<AdminMarca> _marcas = [];

  bool _cargandoInicial = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descCtrl = TextEditingController(text: p?.descripcion ?? '');
    _materialCtrl = TextEditingController(text: p?.material ?? '');

    _categoriaId = p?.categoriaId;
    _marcaId = p?.marcaId;
    _genero = p?.genero;
    _tipoPrenda = p?.tipoPrenda ?? 'SUPERIOR';
    _tipoCorte = p?.tipoCorte ?? 'REGULAR_FIT';
    _imagenes = p != null ? List.from(p.imagenes) : [];

    _cargarCatalogosAuxiliares();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _materialCtrl.dispose();
    _imagenUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogosAuxiliares() async {
    setState(() {
      _cargandoInicial = true;
      _error = null;
    });

    try {
      final cats = await AdminCatalogoService.listarCategorias();
      final marcas = await AdminCatalogoService.listarMarcas();

      if (mounted) {
        setState(() {
          _categorias = cats.where((c) => c.activo).toList();
          _marcas = marcas.where((m) => m.activo).toList();
          if (_categoriaId == null && _categorias.isNotEmpty) {
            _categoriaId = _categorias.first.id;
          }
          _cargandoInicial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando categorías: $e';
          _cargandoInicial = false;
        });
      }
    }
  }

  void _agregarImagen() {
    final url = _imagenUrlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _imagenes.add(AdminProductoImagen(
        url: url,
        esPrincipal: _imagenes.isEmpty,
      ));
      _imagenUrlCtrl.clear();
    });
  }

  void _marcarPrincipal(int index) {
    setState(() {
      for (int i = 0; i < _imagenes.length; i++) {
        _imagenes[i] = AdminProductoImagen(
          id: _imagenes[i].id,
          url: _imagenes[i].url,
          esPrincipal: i == index,
        );
      }
    });
  }

  void _quitarImagen(int index) {
    setState(() {
      final removida = _imagenes.removeAt(index);
      if (removida.esPrincipal && _imagenes.isNotEmpty) {
        _imagenes[0] = AdminProductoImagen(
          id: _imagenes[0].id,
          url: _imagenes[0].url,
          esPrincipal: true,
        );
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría')),
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await AdminCatalogoService.actualizarProducto(
          id: widget.producto!.id,
          categoriaId: _categoriaId!,
          marcaId: _marcaId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          material: _materialCtrl.text.trim().isEmpty ? null : _materialCtrl.text.trim(),
          genero: _genero,
          tipoPrenda: _tipoPrenda,
          tipoCorte: _tipoCorte,
          anchoBaseCm: widget.producto!.anchoBaseCm,
          largoBaseCm: widget.producto!.largoBaseCm,
          coleccionesIds: widget.producto!.coleccionesIds,
          proveedoresIds: widget.producto!.proveedoresIds,
          imagenes: _imagenes,
        );
      } else {
        await AdminCatalogoService.crearProducto(
          categoriaId: _categoriaId!,
          marcaId: _marcaId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          material: _materialCtrl.text.trim().isEmpty ? null : _materialCtrl.text.trim(),
          genero: _genero,
          tipoPrenda: _tipoPrenda,
          tipoCorte: _tipoCorte,
          imagenes: _imagenes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? 'Producto actualizado con éxito' : 'Producto creado con éxito'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esEdicion ? 'Editar Prenda' : 'Nueva Prenda',
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
              child: Form(
                key: _formKey,
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
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),

                    // Datos Generales Card
                    _buildSectionCard(
                      title: 'Información General',
                      icon: Icons.info_outline,
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la Prenda *',
                            hintText: 'Ej: Polera Classic Cuello Redondo',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<int>(
                          initialValue: _categoriaId,
                          decoration: const InputDecoration(
                            labelText: 'Categoría *',
                            border: OutlineInputBorder(),
                          ),
                          items: _categorias.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.nombre),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _categoriaId = val),
                          validator: (v) => v == null ? 'Selecciona una categoría' : null,
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<int?>(
                          initialValue: _marcaId,
                          decoration: const InputDecoration(
                            labelText: 'Marca',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Sin Marca')),
                            ..._marcas.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nombre))),
                          ],
                          onChanged: (val) => setState(() => _marcaId = val),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _materialCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Material',
                                  hintText: 'Ej: 100% Algodón',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _genero,
                                decoration: const InputDecoration(
                                  labelText: 'Género',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem<String?>(value: null, child: Text('Unisex')),
                                  DropdownMenuItem<String?>(value: 'MASCULINO', child: Text('Masculino')),
                                  DropdownMenuItem<String?>(value: 'FEMENINO', child: Text('Femenino')),
                                ],
                                onChanged: (val) => setState(() => _genero = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción detallada',
                            hintText: 'Detalles del estilo, textura y cuidados...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // REALIDAD AUMENTADA Y MEDIDAS
                    _buildSectionCard(
                      title: 'Vestidor Virtual & Realidad Aumentada (RA)',
                      icon: Icons.view_in_ar,
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderColor: AppColors.primary.withValues(alpha: 0.25),
                      children: [
                        const Text(
                          'Configura el tipo de prenda y corte. Esto determina cómo se ajusta y superpone la prenda tridimensionalmente en el cuerpo del cliente.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: _tipoPrenda,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Prenda',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dry_cleaning),
                          ),
                          items: kTiposPrenda.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt.key,
                              child: Text(opt.label),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _tipoPrenda = v);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Dropdown con explicaciones completas del corte
                        const Text(
                          'Tipo de Corte / Silueta:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        ...kTiposCorte.map((opt) {
                          final isSelected = _tipoCorte == opt.key;
                          return InkWell(
                            onTap: () => setState(() => _tipoCorte = opt.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isSelected ? AppColors.primary : Colors.grey.shade500,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opt.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          opt.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.straighten, size: 18, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Las medidas exactas en cm se definen y ajustan al crear o editar cada variante de talla individualmente.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // IMÁGENES
                    _buildSectionCard(
                      title: 'Imágenes del Producto',
                      icon: Icons.photo_library_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _imagenUrlCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'URL de Imagen',
                                  hintText: 'https://...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _agregarImagen,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Añadir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_imagenes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Aún no has agregado imágenes a la prenda.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        else
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imagenes.length,
                              separatorBuilder: (_, index) => const SizedBox(width: 10),
                              itemBuilder: (ctx, i) {
                                final img = _imagenes[i];
                                return Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: img.esPrincipal ? AppColors.primary : Colors.grey.shade300,
                                          width: img.esPrincipal ? 2 : 1,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(img.url),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: InkWell(
                                        onTap: () => _marcarPrincipal(i),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            img.esPrincipal ? Icons.star : Icons.star_border,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () => _quitarImagen(i),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (img.esPrincipal)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Principal',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // BOTÓN GUARDAR
                    ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _esEdicion ? 'Guardar Cambios de Prenda' : 'Crear Prenda en Catálogo',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}
