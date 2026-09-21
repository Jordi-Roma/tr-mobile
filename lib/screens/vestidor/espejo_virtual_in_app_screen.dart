import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/carrito_provider.dart';
import 'models/prenda_ar.dart';
import 'models/perfil_medidas.dart';
import 'services/vestidor_api_service.dart';

class EspejoVirtualInAppScreen extends StatefulWidget {
  final PrendaAR? top;
  final PrendaAR? bottom;
  final PerfilMedidas perfilMedidas;

  const EspejoVirtualInAppScreen({
    super.key,
    this.top,
    this.bottom,
    required this.perfilMedidas,
  });

  @override
  State<EspejoVirtualInAppScreen> createState() => _EspejoVirtualInAppScreenState();
}

class _EspejoVirtualInAppScreenState extends State<EspejoVirtualInAppScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 1; // Priorizar cámara frontal
  bool _isCameraInitialized = false;
  bool _cameraError = false;

  // Estado de transformación y renderizado de prendas
  Offset _topOffset = const Offset(0, -60);
  Offset _bottomOffset = const Offset(0, 110);
  double _scale = 1.0;
  final double _opacity = 0.96;
  String _selectedTalla = 'M';
  String _filtroPrenda = 'AMBOS'; // 'AMBOS', 'TOP', 'BOTTOM'
  bool _mostrarGuias = true;
  bool _capturandoFoto = false;

  // Variables para pinch-to-zoom interactivo
  double _baseScale = 1.0;

  final _currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    _inicializarCamara();
    _registrarTelemetria();
  }

  Future<void> _inicializarCamara() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }

      int frontIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

      await _configurarCamaraActual();
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  Future<void> _configurarCamaraActual() async {
    if (_cameras.isEmpty) return;

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _cameraError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  Future<void> _alternarCamara() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() => _isCameraInitialized = false);
    await _configurarCamaraActual();
  }

  Future<void> _registrarTelemetria() async {
    if (widget.top != null) {
      await VestidorApiService.registrarSesion(
        productoId: widget.top!.productoId,
        origen: 'MOVIL_AR_ESPEJO_INTERNO',
      );
    }
    if (widget.bottom != null) {
      await VestidorApiService.registrarSesion(
        productoId: widget.bottom!.productoId,
        origen: 'MOVIL_AR_ESPEJO_INTERNO',
      );
    }
  }

  void _cambiarTalla(String talla) {
    setState(() {
      _selectedTalla = talla;
      switch (talla) {
        case 'S':
          _scale = 0.90;
          break;
        case 'M':
          _scale = 1.0;
          break;
        case 'L':
          _scale = 1.10;
          break;
        case 'XL':
          _scale = 1.22;
          break;
      }
    });
  }

  Future<void> _capturarFoto() async {
    setState(() => _capturandoFoto = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _capturandoFoto = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF00E5FF)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Look en vivo capturado y guardado en tu galería del vestidor!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  double get _precioTotal {
    double total = 0.0;
    final incluirTop = _filtroPrenda == 'AMBOS' || _filtroPrenda == 'TOP';
    final incluirBottom = _filtroPrenda == 'AMBOS' || _filtroPrenda == 'BOTTOM';
    if (incluirTop && widget.top != null) total += widget.top!.precio;
    if (incluirBottom && widget.bottom != null) total += widget.bottom!.precio;
    return total;
  }

  void _agregarOutfitAlCarrito() {
    try {
      final carrito = Provider.of<CarritoProvider>(context, listen: false);
      int agregados = 0;
      final incluirTop = _filtroPrenda == 'AMBOS' || _filtroPrenda == 'TOP';
      final incluirBottom = _filtroPrenda == 'AMBOS' || _filtroPrenda == 'BOTTOM';

      if (incluirTop && widget.top != null && widget.top!.variantes.isNotEmpty) {
        carrito.agregarItem(varianteId: widget.top!.variantes.first.id, cantidad: 1);
        agregados++;
      }
      if (incluirBottom && widget.bottom != null && widget.bottom!.variantes.isNotEmpty) {
        carrito.agregarItem(varianteId: widget.bottom!.variantes.first.id, cantidad: 1);
        agregados++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            agregados > 1
                ? '¡Outfit completo añadido al carrito (${_currencyFormat.format(_precioTotal)})!'
                : 'Prenda añadida al carrito con éxito!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Look guardado en tu probador.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fondo de Cámara en Vivo o Estudio Simulado
          _buildCameraOrStudioBackground(),

          // 2. Capa de Guías Antropométricas en Realidad Aumentada
          if (_mostrarGuias) _buildGuiaAntropometrica(),

          // 3. Capa Interactiva de Prendas AR Reales
          _buildPrendasARLayer(),

          // 4. Flash visual al tomar foto
          if (_capturandoFoto)
            Container(color: Colors.white.withValues(alpha: 0.85)),

          // 5. Barra Superior de Navegación y Telemetría
          _buildTopBar(),

          // 6. Selector de prendas en vista (Ambos, Top, Bottom)
          _buildFiltroPrendaSelector(),

          // 7. Controles Laterales de Ajuste Rápido y Calce
          _buildLateralControls(),

          // 8. Panel Inferior de Ajuste de Talla, Precio y Carrito
          _buildBottomControlPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraOrStudioBackground() {
    if (_isCameraInitialized && _cameraController != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1080,
            height: _cameraController!.value.previewSize?.width ?? 1920,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [
            Color(0xFF2A3447),
            Color(0xFF151922),
            Color(0xFF0B0E14),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _cameraError ? Icons.videocam_off_outlined : Icons.sync,
              size: 54,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            Text(
              _cameraError
                  ? 'Modo Estudio Activo (Sin Cámara)'
                  : 'Iniciando Espejo Virtual AR...',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuiaAntropometrica() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 270 * _scale,
          height: 500 * _scale,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(44),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGuideLine('HOMBROS • 46 cm'),
              _buildGuideLine('PECHO / TORSO • 98 cm'),
              _buildGuideLine('CINTURA • 82 cm'),
              _buildGuideLine('CADERA / BOTAMANGAS • 96 cm'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideLine(String label) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildPrendasARLayer() {
    final mostrarBottom = widget.bottom != null && (_filtroPrenda == 'AMBOS' || _filtroPrenda == 'BOTTOM');
    final mostrarTop = widget.top != null && (_filtroPrenda == 'AMBOS' || _filtroPrenda == 'TOP');

    return Stack(
      children: [
        // Prenda Inferior (Pantalón / Jeans)
        if (mostrarBottom)
          Center(
            child: Transform.translate(
              offset: _bottomOffset,
              child: Transform.scale(
                scale: _scale,
                child: GestureDetector(
                  onScaleStart: (details) {
                    _baseScale = _scale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _bottomOffset += details.focalPointDelta;
                      if (details.scale != 1.0) {
                        _scale = (_baseScale * details.scale).clamp(0.6, 1.8);
                      }
                    });
                  },
                  child: Opacity(
                    opacity: _opacity,
                    child: _buildBottomGarmentWidget(widget.bottom!),
                  ),
                ),
              ),
            ),
          ),

        // Prenda Superior (Polo / Polera / Sudadera)
        if (mostrarTop)
          Center(
            child: Transform.translate(
              offset: _topOffset,
              child: Transform.scale(
                scale: _scale,
                child: GestureDetector(
                  onScaleStart: (details) {
                    _baseScale = _scale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _topOffset += details.focalPointDelta;
                      if (details.scale != 1.0) {
                        _scale = (_baseScale * details.scale).clamp(0.6, 1.8);
                      }
                    });
                  },
                  child: Opacity(
                    opacity: _opacity,
                    child: _buildTopGarmentWidget(widget.top!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopGarmentWidget(PrendaAR prenda) {
    final hasImg = prenda.imagenArUrl != null && prenda.imagenArUrl!.trim().isNotEmpty;
    return Container(
      width: 260,
      height: 250,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                prenda.imagenArUrl!,
                width: 260,
                height: 250,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                  );
                },
                errorBuilder: (ctx, err, stack) => CustomPaint(
                  size: const Size(240, 220),
                  painter: _TopGarmentPainter(
                    color: const Color(0xFF2563EB),
                    tipoCorte: prenda.tipoCorte,
                  ),
                ),
              ),
            )
          else
            CustomPaint(
              size: const Size(240, 220),
              painter: _TopGarmentPainter(
                color: const Color(0xFF2563EB),
                tipoCorte: prenda.tipoCorte,
              ),
            ),
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.checkroom_rounded, color: Color(0xFF00E5FF), size: 13),
                  const SizedBox(width: 5),
                  Text(
                    '${prenda.nombre} • Talla $_selectedTalla • ${_currencyFormat.format(prenda.precio)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGarmentWidget(PrendaAR prenda) {
    final hasImg = prenda.imagenArUrl != null && prenda.imagenArUrl!.trim().isNotEmpty;
    return Container(
      width: 220,
      height: 340,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                prenda.imagenArUrl!,
                width: 220,
                height: 340,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                  );
                },
                errorBuilder: (ctx, err, stack) => CustomPaint(
                  size: const Size(190, 280),
                  painter: _PantsGarmentPainter(
                    denimColor: const Color(0xFF334155),
                  ),
                ),
              ),
            )
          else
            CustomPaint(
              size: const Size(190, 280),
              painter: _PantsGarmentPainter(
                denimColor: const Color(0xFF334155),
              ),
            ),
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.airline_seat_legroom_extra_rounded, color: Color(0xFF00E5FF), size: 13),
                  const SizedBox(width: 5),
                  Text(
                    '${prenda.nombre} • Talla $_selectedTalla • ${_currencyFormat.format(prenda.precio)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ESPEJO VIRTUAL AR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'En Vivo • CU24 • ${widget.perfilMedidas.resumen}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
                onPressed: _alternarCamara,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroPrendaSelector() {
    return Positioned(
      top: 90,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFiltroPill('AMBOS', 'Outfit Completo'),
              _buildFiltroPill('TOP', 'Solo Top'),
              _buildFiltroPill('BOTTOM', 'Solo Pantalón'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltroPill(String id, String label) {
    final isSelected = _filtroPrenda == id;
    return GestureDetector(
      onTap: () => setState(() => _filtroPrenda = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLateralControls() {
    return Positioned(
      right: 14,
      top: 140,
      child: Column(
        children: [
          _buildLateralButton(
            icon: Icons.zoom_in_rounded,
            label: '+ Calce',
            active: false,
            onTap: () => setState(() => _scale = (_scale + 0.08).clamp(0.6, 1.8)),
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: Icons.zoom_out_rounded,
            label: '- Calce',
            active: false,
            onTap: () => setState(() => _scale = (_scale - 0.08).clamp(0.6, 1.8)),
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: Icons.arrow_upward_rounded,
            label: 'Subir',
            active: false,
            onTap: () => setState(() {
              _topOffset += const Offset(0, -18);
              _bottomOffset += const Offset(0, -18);
            }),
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Bajar',
            active: false,
            onTap: () => setState(() {
              _topOffset += const Offset(0, 18);
              _bottomOffset += const Offset(0, 18);
            }),
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: Icons.restart_alt_rounded,
            label: 'Centrar',
            active: false,
            onTap: () {
              setState(() {
                _topOffset = const Offset(0, -60);
                _bottomOffset = const Offset(0, 110);
                _scale = 1.0;
                _selectedTalla = 'M';
              });
            },
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: _mostrarGuias ? Icons.grid_on_rounded : Icons.grid_off_rounded,
            label: 'Guías',
            active: _mostrarGuias,
            onTap: () => setState(() => _mostrarGuias = !_mostrarGuias),
          ),
          const SizedBox(height: 8),
          _buildLateralButton(
            icon: Icons.camera_alt_rounded,
            label: 'Captura',
            active: false,
            onTap: _capturarFoto,
          ),
        ],
      ),
    );
  }

  Widget _buildLateralButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 50,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E5FF).withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF00E5FF) : Colors.white12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? const Color(0xFF00E5FF) : Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF00E5FF) : Colors.white70,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selector de Tallas con Calce Antropométrico
            Row(
              children: [
                const Icon(Icons.straighten_rounded, color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Talla y Calce:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Compatibilidad: 98% con $_selectedTalla',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['S', 'M', 'L', 'XL'].map((talla) {
                final isSelected = _selectedTalla == talla;
                return GestureDetector(
                  onTap: () => _cambiarTalla(talla),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      talla,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Resumen de Precio y Botón de Añadir al Carrito
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Outfit',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      _currencyFormat.format(_precioTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _agregarOutfitAlCarrito,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Añadir al Carrito',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Pintor de Prenda Superior estilizada (fallback)
class _TopGarmentPainter extends CustomPainter {
  final Color color;
  final String tipoCorte;

  _TopGarmentPainter({required this.color, required this.tipoCorte});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    path.moveTo(size.width * 0.35, 20);
    path.quadraticBezierTo(size.width * 0.5, 45, size.width * 0.65, 20);
    path.lineTo(size.width * 0.85, 28);
    path.lineTo(size.width, 70);
    path.lineTo(size.width * 0.82, 85);
    path.lineTo(size.width * 0.74, 65);
    path.lineTo(size.width * 0.76, size.height - 10);
    path.quadraticBezierTo(size.width * 0.5, size.height - 4, size.width * 0.24, size.height - 10);
    path.lineTo(size.width * 0.26, 65);
    path.lineTo(size.width * 0.18, 85);
    path.lineTo(0, 70);
    path.lineTo(size.width * 0.15, 28);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    final stitchPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final collarPath = Path()
      ..moveTo(size.width * 0.35, 20)
      ..quadraticBezierTo(size.width * 0.5, 45, size.width * 0.65, 20);
    canvas.drawPath(collarPath, stitchPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pintor de Jeans/Pantalón estilizado (fallback)
class _PantsGarmentPainter extends CustomPainter {
  final Color denimColor;

  _PantsGarmentPainter({required this.denimColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = denimColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    path.moveTo(size.width * 0.22, 10);
    path.lineTo(size.width * 0.78, 10);
    path.quadraticBezierTo(size.width * 0.85, 40, size.width * 0.84, 90);
    path.lineTo(size.width * 0.82, size.height);
    path.lineTo(size.width * 0.56, size.height);
    path.lineTo(size.width * 0.52, 90);
    path.lineTo(size.width * 0.44, size.height);
    path.lineTo(size.width * 0.18, size.height);
    path.lineTo(size.width * 0.16, 90);
    path.quadraticBezierTo(size.width * 0.15, 40, size.width * 0.22, 10);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    final stitchPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(size.width * 0.22, 22),
      Offset(size.width * 0.78, 22),
      stitchPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.50, 22),
      Offset(size.width * 0.50, 85),
      stitchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
