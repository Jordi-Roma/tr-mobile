import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import 'models/perfil_medidas.dart';
import 'models/prenda_ar.dart';
import 'services/vestidor_api_service.dart';
import 'widgets/medidas_bottom_sheet.dart';
import 'espejo_virtual_in_app_screen.dart';
import 'probador_ia_screen.dart';

class VestidorScreen extends StatefulWidget {
  final int productoId;
  final int? varianteInicialId;

  const VestidorScreen({
    super.key,
    required this.productoId,
    this.varianteInicialId,
  });

  @override
  State<VestidorScreen> createState() => _VestidorScreenState();
}

class _VestidorScreenState extends State<VestidorScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Catálogo disponible para armar outfits
  List<PrendaAR> _prendasSuperiores = [];
  List<PrendaAR> _prendasInferiores = [];

  // Outfit seleccionado
  PrendaAR? _superiorSeleccionada;
  PrendaAR? _inferiorSeleccionada;

  TallaAR? _tallaSuperior;
  TallaAR? _tallaInferior;

  ColorAR? _colorSuperior;
  ColorAR? _colorInferior;

  PerfilMedidas _perfilMedidas = const PerfilMedidas();

  final _currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Obtener la prenda actual
      final prenda = await VestidorApiService.obtenerPrendaAR(widget.productoId);

      // 2. Obtener lista de prendas para combinar
      final disponiblesRaw = await VestidorApiService.listarPrendasDisponibles(limite: 40);
      final listaPrendas = disponiblesRaw.map((e) => PrendaAR.fromJson(e)).toList();

      // Asegurar que la prenda actual esté en la lista
      if (!listaPrendas.any((p) => p.productoId == prenda.productoId)) {
        listaPrendas.insert(0, prenda);
      }

      final superiores = listaPrendas.where((p) => p.tipoPrenda == 'SUPERIOR' || p.tipoPrenda == 'VESTIDO').toList();
      final inferiores = listaPrendas.where((p) => p.tipoPrenda == 'INFERIOR').toList();

      setState(() {
        _prendasSuperiores = superiores;
        _prendasInferiores = inferiores;

        // Asignar según el tipo de la prenda inicial (Selección flexible: sólo la prenda de entrada)
        if (prenda.tipoPrenda == 'INFERIOR') {
          _inferiorSeleccionada = prenda;
          _superiorSeleccionada = null;
        } else {
          _superiorSeleccionada = prenda;
          _inferiorSeleccionada = null;
        }

        // Tallas y colores iniciales para la prenda activa
        if (_superiorSeleccionada != null && _superiorSeleccionada!.tallas.isNotEmpty) {
          _tallaSuperior = _superiorSeleccionada!.tallas.first;
        } else {
          _tallaSuperior = null;
        }
        if (_inferiorSeleccionada != null && _inferiorSeleccionada!.tallas.isNotEmpty) {
          _tallaInferior = _inferiorSeleccionada!.tallas.first;
        } else {
          _tallaInferior = null;
        }
        if (_superiorSeleccionada != null && _superiorSeleccionada!.colores.isNotEmpty) {
          _colorSuperior = _superiorSeleccionada!.colores.first;
        } else {
          _colorSuperior = null;
        }
        if (_inferiorSeleccionada != null && _inferiorSeleccionada!.colores.isNotEmpty) {
          _colorInferior = _inferiorSeleccionada!.colores.first;
        } else {
          _colorInferior = null;
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudieron cargar los datos del vestidor: $e';
        _isLoading = false;
      });
    }
  }

  String? get _urlLenteActivo {
    final sup = _superiorSeleccionada?.modelo3dUrl?.trim();
    if (sup != null && sup.isNotEmpty) return sup;
    final inf = _inferiorSeleccionada?.modelo3dUrl?.trim();
    if (inf != null && inf.isNotEmpty) return inf;
    return null;
  }

  void _abrirEspejoVirtualAR() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _buildModalLanzadorARContent(ctx),
    );
  }

  Widget _buildModalLanzadorARContent(BuildContext modalContext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF00E5FF), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESPEJO VIRTUAL 3D AR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Caso de Uso CU24 • Motor Neural de Calce',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Opción 1: Probador Virtual con IA (Foto de Estudio)
          GestureDetector(
            onTap: () {
              Navigator.pop(modalContext);
              _abrirProbadorIA();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Probador Virtual con IA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '✨ Recomendado IA',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toma una foto o elígela de tu galería. Nuestra IA adapta la fisonomía y la caída de la prenda con sombras y proporción realista sin lag.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Opción 2: Motor AR 3D Avanzado (Tracking 60 FPS)
          Builder(
            builder: (context) {
              final String? urlMotor = _urlLenteActivo;
              final bool tieneMotor = urlMotor != null && urlMotor.isNotEmpty;

              return GestureDetector(
                onTap: tieneMotor
                    ? () {
                        Navigator.pop(modalContext);
                        _lanzarMotorARNeuronal(urlMotor);
                      }
                    : () {
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Esta prenda no cuenta con calibración de sensor 3D.',
                            ),
                            backgroundColor: Color(0xFF334155),
                          ),
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tieneMotor
                        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                        : const Color(0xFF1E293B).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: tieneMotor ? Colors.white12 : Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tieneMotor ? Colors.white10 : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.view_in_ar_rounded,
                          color: tieneMotor ? const Color(0xFF00E5FF) : Colors.white24,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Vestidor 3D en Vivo',
                                  style: TextStyle(
                                    color: tieneMotor ? Colors.white : Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tieneMotor
                                        ? Colors.blueAccent.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tieneMotor ? 'Tracking 60 FPS' : 'No disponible en 3D',
                                    style: TextStyle(
                                      color: tieneMotor ? const Color(0xFF60A5FA) : Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tieneMotor
                                  ? 'Tracking corporal completo y física de tela en tiempo real con modelo calibrado.'
                                  : 'Esta prenda aún no cuenta con modelo volumétrico 3D calibrado.',
                              style: TextStyle(
                                color: tieneMotor ? Colors.white70 : Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Opción 3: Espejo en Vivo (Cámara Interna)
          GestureDetector(
            onTap: () {
              Navigator.pop(modalContext);
              _abrirProbadorInApp();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.white60, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Espejo Virtual en Vivo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cámara selfie continua con superposición rápida de prendas.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
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

  Future<void> _lanzarMotorARNeuronal([String? customUrl]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetUrl = customUrl ?? _urlLenteActivo;

    if (targetUrl == null || targetUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La prenda seleccionada no cuenta con calibración de motor 3D.'),
            backgroundColor: Color(0xFF334155),
          ),
        );
      }
      return;
    }

    // Registrar telemetría de la sesión (CU24) en PostgreSQL
    if (_superiorSeleccionada != null) {
      VestidorApiService.registrarSesion(
        clienteId: auth.usuario?.id,
        productoId: _superiorSeleccionada!.productoId,
        origen: 'MOTOR_AR_NEURAL_60FPS',
      );
    }
    if (_inferiorSeleccionada != null) {
      VestidorApiService.registrarSesion(
        clienteId: auth.usuario?.id,
        productoId: _inferiorSeleccionada!.productoId,
        origen: 'MOTOR_AR_NEURAL_60FPS',
      );
    }

    // Modal de Calibración de Alta Tecnología
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF00E5FF)),
              SizedBox(height: 18),
              Text(
                'Iniciando Motor AR Neural StyleAR...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Calibrando sensor de tracking a 60 FPS\ny sincronizando telemetría con PostgreSQL (CU24)...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);

    final cleanUrl = targetUrl.trim();
    final uri = Uri.parse(cleanUrl);

    bool launched = false;
    // Intento 1: External application (app nativa o navegador externo)
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error en LaunchMode.externalApplication: $e');
    }

    // Intento 2: Platform default
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('Error en LaunchMode.platformDefault: $e');
      }
    }

    // Intento 3: In-app browser
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        debugPrint('Error en LaunchMode.inAppBrowserView: $e');
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el motor AR 3D. Verifica el navegador de tu dispositivo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _abrirProbadorIA() {
    final targetId = (_superiorSeleccionada == null && _inferiorSeleccionada != null)
        ? _inferiorSeleccionada!.productoId
        : (_superiorSeleccionada?.productoId ?? _inferiorSeleccionada?.productoId);

    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona al menos una prenda para probarte con IA.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProbadorIaScreen(
          productoInicialId: targetId,
        ),
      ),
    );
  }

  void _abrirProbadorInApp() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_superiorSeleccionada != null) {
      VestidorApiService.registrarSesion(
        clienteId: auth.usuario?.id,
        productoId: _superiorSeleccionada!.productoId,
        origen: 'MOVIL_ESPEJO_INAPP',
      );
    }
    if (_inferiorSeleccionada != null) {
      VestidorApiService.registrarSesion(
        clienteId: auth.usuario?.id,
        productoId: _inferiorSeleccionada!.productoId,
        origen: 'MOVIL_ESPEJO_INAPP',
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EspejoVirtualInAppScreen(
          top: _superiorSeleccionada,
          bottom: _inferiorSeleccionada,
          perfilMedidas: _perfilMedidas,
        ),
      ),
    );
  }

  void _agregarOutfitAlCarrito() {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    int agregados = 0;

    if (_superiorSeleccionada != null) {
      final v = _superiorSeleccionada!.variantes.isNotEmpty
          ? _superiorSeleccionada!.variantes.first
          : null;
      if (v != null) {
        carrito.agregarItem(varianteId: v.id, cantidad: 1);
        agregados++;
      }
    }

    if (_inferiorSeleccionada != null) {
      final v = _inferiorSeleccionada!.variantes.isNotEmpty
          ? _inferiorSeleccionada!.variantes.first
          : null;
      if (v != null) {
        carrito.agregarItem(varianteId: v.id, cantidad: 1);
        agregados++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          agregados > 1
              ? '¡Outfit completo agregado al carrito con éxito!'
              : 'Prenda agregada al carrito con éxito!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  double get _precioTotalOutfit {
    double total = 0;
    if (_superiorSeleccionada != null) total += _superiorSeleccionada!.precio;
    if (_inferiorSeleccionada != null) total += _inferiorSeleccionada!.precio;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vestidor Virtual AR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Arma tu Outfit & Pruébatelo en Vivo',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_rounded),
            tooltip: 'Calcular Talla por Medidas',
            onPressed: () {
              MedidasBottomSheet.show(
                context,
                perfilActual: _perfilMedidas,
                onMedidasChanged: (m) => setState(() => _perfilMedidas = m),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Cargando probador virtual y prendas...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarDatos,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Superior de Tecnología AR
                      _buildArBanner(),

                      const SizedBox(height: 20),

                      // Vista previa combinada del Outfit actual
                      _buildOutfitPreviewCard(),

                      const SizedBox(height: 24),

                      // Selector Prenda Superior
                      _buildSeccionPrendas(
                        titulo: '1. Prenda Superior (Top)',
                        subtitulo: 'Poleras, Polos, Hoodies y Camisas (Opcional)',
                        icono: Icons.checkroom_rounded,
                        prendas: _prendasSuperiores,
                        seleccionada: _superiorSeleccionada,
                        tallaSeleccionada: _tallaSuperior,
                        colorSeleccionado: _colorSuperior,
                        onSelect: (p) => setState(() {
                          if (_superiorSeleccionada?.productoId == p.productoId) {
                            // Deseleccionar si ya estaba seleccionada
                            _superiorSeleccionada = null;
                            _tallaSuperior = null;
                            _colorSuperior = null;
                          } else {
                            _superiorSeleccionada = p;
                            _tallaSuperior = p.tallas.isNotEmpty ? p.tallas.first : null;
                            _colorSuperior = p.colores.isNotEmpty ? p.colores.first : null;
                          }
                        }),
                        onTallaSelect: (t) => setState(() => _tallaSuperior = t),
                        onColorSelect: (c) => setState(() => _colorSuperior = c),
                      ),

                      const SizedBox(height: 24),

                      // Selector Prenda Inferior
                      _buildSeccionPrendas(
                        titulo: '2. Prenda Inferior (Bottom)',
                        subtitulo: 'Jeans, Pantalones y Bermudas (Opcional)',
                        icono: Icons.airline_seat_legroom_extra_rounded,
                        prendas: _prendasInferiores,
                        seleccionada: _inferiorSeleccionada,
                        tallaSeleccionada: _tallaInferior,
                        colorSeleccionado: _colorInferior,
                        onSelect: (p) => setState(() {
                          if (_inferiorSeleccionada?.productoId == p.productoId) {
                            // Deseleccionar si ya estaba seleccionada
                            _inferiorSeleccionada = null;
                            _tallaInferior = null;
                            _colorInferior = null;
                          } else {
                            _inferiorSeleccionada = p;
                            _tallaInferior = p.tallas.isNotEmpty ? p.tallas.first : null;
                            _colorInferior = p.colores.isNotEmpty ? p.colores.first : null;
                          }
                        }),
                        onTallaSelect: (t) => setState(() => _tallaInferior = t),
                        onColorSelect: (c) => setState(() => _colorInferior = c),
                      ),

                      const SizedBox(height: 32),

                      // Botones de acción fija
                      _buildActionButtons(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildArBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _abrirProbadorIA,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF00E5FF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Probador Virtual con IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '✨ NUEVO',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Toma una foto o elígela de tu galería para probarte la ropa con IA sin lag.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF00E5FF),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildOutfitPreviewCard() {
    final bool tieneSuperior = _superiorSeleccionada != null;
    final bool tieneInferior = _inferiorSeleccionada != null;

    String tituloCard = 'Outfit Completo Seleccionado';
    if (tieneSuperior && !tieneInferior) {
      tituloCard = 'Prenda Superior (1 prenda)';
    } else if (!tieneSuperior && tieneInferior) {
      tituloCard = 'Prenda Inferior (1 prenda)';
    } else if (!tieneSuperior && !tieneInferior) {
      tituloCard = 'Selecciona una Prenda';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tituloCard,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currencyFormat.format(_precioTotalOutfit),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Prenda Superior Card
              Expanded(
                child: _buildItemCardSummary(
                  label: 'SUPERIOR',
                  prenda: _superiorSeleccionada,
                  talla: _tallaSuperior,
                  color: _colorSuperior,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.add, color: Color(0xFF94A3B8), size: 20),
              ),
              // Prenda Inferior Card
              Expanded(
                child: _buildItemCardSummary(
                  label: 'INFERIOR',
                  prenda: _inferiorSeleccionada,
                  talla: _tallaInferior,
                  color: _colorInferior,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCardSummary({
    required String label,
    required PrendaAR? prenda,
    required TallaAR? talla,
    required ColorAR? color,
  }) {
    if (prenda == null) {
      return Container(
        height: 145,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.grey.shade400, size: 28),
            const SizedBox(height: 8),
            Text(
              'Sin $label',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Opcional • Toca abajo',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 145,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text(
                _currencyFormat.format(prenda.precio),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              height: 50,
              child: prenda.imagenArUrl != null && prenda.imagenArUrl!.isNotEmpty
                  ? Image.network(
                      prenda.imagenArUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.checkroom, color: Colors.grey, size: 32),
                    )
                  : const Icon(Icons.checkroom, color: Colors.grey, size: 32),
            ),
          ),
          const Spacer(),
          Text(
            prenda.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
          ),
          if (talla != null || color != null)
            Text(
              '${talla != null ? "Talla: ${talla.nombre}" : ""}${talla != null && color != null ? " • " : ""}${color != null ? color.nombre : ""}',
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionPrendas({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required List<PrendaAR> prendas,
    required PrendaAR? seleccionada,
    required TallaAR? tallaSeleccionada,
    required ColorAR? colorSeleccionado,
    required ValueChanged<PrendaAR> onSelect,
    required ValueChanged<TallaAR> onTallaSelect,
    required ValueChanged<ColorAR> onColorSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, color: const Color(0xFF0F172A), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (prendas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No hay prendas disponibles en esta categoría.', style: TextStyle(color: Colors.grey)),
          )
        else
          SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prendas.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) {
                final p = prendas[index];
                final isSelected = seleccionada?.productoId == p.productoId;

                return GestureDetector(
                  onTap: () => onSelect(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: p.imagenArUrl != null && p.imagenArUrl!.isNotEmpty
                                ? Image.network(
                                    p.imagenArUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.checkroom, color: Colors.grey),
                                  )
                                : const Icon(Icons.checkroom, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _currencyFormat.format(p.precio),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Selector de Tallas si hay prenda seleccionada
        if (seleccionada != null && seleccionada.tallas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Talla: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Wrap(
                spacing: 6,
                children: seleccionada.tallas.map((t) {
                  final isTallaSelected = tallaSeleccionada?.id == t.id;
                  return ChoiceChip(
                    label: Text(t.nombre, style: TextStyle(fontSize: 11, color: isTallaSelected ? Colors.white : Colors.black87)),
                    selected: isTallaSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => onTallaSelect(t),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    final bool tieneSuperior = _superiorSeleccionada != null;
    final bool tieneInferior = _inferiorSeleccionada != null;
    final bool tieneAlguna = tieneSuperior || tieneInferior;
    final int cantidadPrendas = (tieneSuperior ? 1 : 0) + (tieneInferior ? 1 : 0);

    String textoBotonIA = 'Probar Outfit con IA (Foto de Estudio)';
    if (tieneSuperior && !tieneInferior) {
      textoBotonIA = 'Probar ${_superiorSeleccionada!.nombre} con IA';
    } else if (!tieneSuperior && tieneInferior) {
      textoBotonIA = 'Probar ${_inferiorSeleccionada!.nombre} con IA';
    } else if (!tieneAlguna) {
      textoBotonIA = 'Selecciona una prenda para probar con IA';
    }

    String textoBotonCarrito = 'Añadir al Carrito (${_currencyFormat.format(_precioTotalOutfit)})';
    if (cantidadPrendas > 1) {
      textoBotonCarrito = 'Añadir Outfit Completo al Carrito (${_currencyFormat.format(_precioTotalOutfit)})';
    } else if (cantidadPrendas == 1) {
      textoBotonCarrito = 'Añadir Prenda al Carrito (${_currencyFormat.format(_precioTotalOutfit)})';
    }

    return Column(
      children: [
        // BOTÓN PRINCIPAL: Probar con IA (Foto de Estudio)
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: tieneAlguna
                ? const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF10B981)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF64748B), Color(0xFF475569)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            boxShadow: tieneAlguna
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: tieneAlguna ? _abrirProbadorIA : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF0F172A), size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      textoBotonIA,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // BOTÓN SECUNDARIO: Opciones de Sensor AR 3D / Espejo Virtual
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: const Color(0xFF0F172A),
            ),
            icon: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF00E5FF), size: 20),
            label: const Text(
              'Sensor 3D en Vivo / Espejo Virtual',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: tieneAlguna ? _abrirEspejoVirtualAR : null,
          ),
        ),

        const SizedBox(height: 12),

        // BOTÓN TERCERO: Añadir al Carrito
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: tieneAlguna ? AppColors.primary : Colors.grey, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
            ),
            icon: Icon(Icons.shopping_bag_outlined, color: tieneAlguna ? AppColors.primary : Colors.grey),
            label: Text(
              textoBotonCarrito,
              style: TextStyle(
                color: tieneAlguna ? AppColors.primary : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: tieneAlguna ? _agregarOutfitAlCarrito : null,
          ),
        ),

      ],
    );
  }
}
