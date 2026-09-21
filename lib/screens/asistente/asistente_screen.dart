import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/asistente_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistente_service.dart';
import '../../services/voz_service.dart';
import '../auth/login_screen.dart';

/// Pantalla del asistente virtual IA (CU23).
/// Puede usarse desde cualquier pantalla como hoja modal.
class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _mensajeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  final List<_MensajeChat> _mensajes = [];
  bool _enviando = false;
  bool _escuchando = false;

  static const _sugerencias = [
    '¿Qué camisetas tienen en talla M?',
    '¿Cómo hago una reserva?',
    '¿Cómo funciona el delivery?',
    '¿Cómo pago con Stripe?',
    '¿Cómo uso el carrito?',
    '¿Dónde veo mis pagos?',
    '¿Cómo guardo favoritos?',
    '¿Cuáles son las sucursales activas?',
  ];

  @override
  void initState() {
    super.initState();
    _agregarMensajeBienvenida();
  }

  @override
  void dispose() {
    VozService.cancelar();
    _scrollController.dispose();
    _mensajeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _agregarMensajeBienvenida() {
    _mensajes.add(
      _MensajeChat(
        texto:
            '¡Hola! Soy el asistente virtual de **StyleAR**. Puedo ayudarte a:\n\n'
            '• Buscar prendas por categoría, talla, color o precio\n'
            '• Consultar disponibilidad en sucursales\n'
            '• Explicarte reservas, delivery, pagos y carrito\n'
            '• Ayudarte con favoritos, cuenta y otros procesos\n\n'
            '¿En qué puedo ayudarte hoy?',
        esAsistente: true,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _enviarMensaje([String? textoFijo]) async {
    final texto = textoFijo ?? _mensajeCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    _mensajeCtrl.clear();
    _focusNode.unfocus();

    final auth = context.read<AuthProvider>();

    setState(() {
      _enviando = true;
      _mensajes.add(
        _MensajeChat(
          texto: texto,
          esAsistente: false,
          timestamp: DateTime.now(),
        ),
      );
    });

    _scrollAlFinal();

    try {
      final response = await AsistenteService.chat(
        mensaje: texto,
        estaAutenticado: auth.estaAutenticado,
      );

      if (!mounted) return;

      setState(() {
        _mensajes.add(
          _MensajeChat(
            texto: response.respuesta,
            esAsistente: true,
            timestamp: DateTime.now(),
            productos: response.productos,
            alternativas: response.alternativas,
            acciones: response.acciones,
            requiereLogin: response.requiereLogin,
          ),
        );
      });

      _scrollAlFinal();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(
          _MensajeChat(
            texto: 'Error: ${e.message}',
            esAsistente: true,
            timestamp: DateTime.now(),
            esError: true,
          ),
        );
      });
      _scrollAlFinal();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(
          _MensajeChat(
            texto: 'Ocurrió un error al consultar el asistente. Intenta nuevamente.',
            esAsistente: true,
            timestamp: DateTime.now(),
            esError: true,
          ),
        );
      });
      _scrollAlFinal();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _alternarDictado() async {
    if (_enviando) return;

    if (_escuchando) {
      await VozService.cancelar();
      if (mounted) setState(() => _escuchando = false);
      final texto = _mensajeCtrl.text.trim();
      if (texto.isNotEmpty) {
        await _enviarMensaje(texto);
      }
      return;
    }

    setState(() => _escuchando = true);
    await VozService.escuchar(
      onTexto: (texto, finalizado) {
        if (!mounted) return;
        setState(() {
          _mensajeCtrl.text = texto;
          _mensajeCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _mensajeCtrl.text.length),
          );
        });
        if (finalizado) {
          setState(() => _escuchando = false);
          if (texto.trim().isNotEmpty) {
            _enviarMensaje(texto.trim());
          }
        }
      },
      onError: (mensaje) {
        if (!mounted) return;
        setState(() {
          _escuchando = false;
          _mensajes.add(
            _MensajeChat(
              texto: mensaje,
              esAsistente: true,
              timestamp: DateTime.now(),
              esError: true,
            ),
          );
        });
        _scrollAlFinal();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildListaMensajes()),
          if (_mensajes.length <= 1) _buildSugerencias(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asistente StyleAR',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Asistente virtual IA',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_enviando)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListaMensajes() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _mensajes.length,
      itemBuilder: (_, i) => _BurbujaMensaje(
        mensaje: _mensajes[i],
        onIniciarSesion: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
      ),
    );
  }

  Widget _buildSugerencias() {
    return Container(
      color: const Color(0xFFF7F7F5),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Puedes preguntar:',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _sugerencias
                .map(
                  (s) => GestureDetector(
                    onTap: () => _enviarMensaje(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _mensajeCtrl,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviarMensaje(),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu consulta...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviando ? null : _alternarDictado,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _escuchando ? AppColors.danger : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: _escuchando
                    ? [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _escuchando ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _enviando ? null : _enviarMensaje,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _enviando
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _enviando ? Icons.hourglass_empty : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modelo de mensaje en el chat ────────────────────────────────────────────

class _MensajeChat {
  final String texto;
  final bool esAsistente;
  final DateTime timestamp;
  final List<AsistenteProductoResponse> productos;
  final List<AsistenteProductoResponse> alternativas;
  final List<AsistenteAccionResponse> acciones;
  final bool requiereLogin;
  final bool esError;

  const _MensajeChat({
    required this.texto,
    required this.esAsistente,
    required this.timestamp,
    this.productos = const [],
    this.alternativas = const [],
    this.acciones = const [],
    this.requiereLogin = false,
    this.esError = false,
  });
}

// ─── Burbuja de mensaje ───────────────────────────────────────────────────────

class _BurbujaMensaje extends StatelessWidget {
  final _MensajeChat mensaje;
  final VoidCallback? onIniciarSesion;

  const _BurbujaMensaje({required this.mensaje, this.onIniciarSesion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: mensaje.esAsistente
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          // Indicador de autor
          if (mensaje.esAsistente)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Asistente',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Burbuja de texto
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mensaje.esError
                  ? AppColors.dangerSoft
                  : mensaje.esAsistente
                  ? Colors.white
                  : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mensaje.esAsistente ? 4 : 16),
                bottomRight: Radius.circular(mensaje.esAsistente ? 16 : 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildTextoConMarkdown(
              mensaje.texto,
              esChatBot: mensaje.esAsistente && !mensaje.esError,
            ),
          ),

          // Alerta de login requerido
          if (mensaje.requiereLogin) ...[
            const SizedBox(height: 8),
            _TarjetaLoginRequerido(onIniciarSesion: onIniciarSesion),
          ],

          // Productos encontrados
          if (mensaje.productos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ListaProductosChat(
              titulo: 'Resultados',
              productos: mensaje.productos,
            ),
          ],

          // Alternativas
          if (mensaje.alternativas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ListaProductosChat(
              titulo: 'También te puede interesar',
              productos: mensaje.alternativas,
            ),
          ],

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              DateFormat('HH:mm').format(mensaje.timestamp),
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextoConMarkdown(String texto, {bool esChatBot = false}) {
    // Parseo básico de markdown: **negrita**, listas y saltos de línea
    final Color textColor = esChatBot ? AppColors.textPrimary : Colors.white;

    final spans = <InlineSpan>[];
    final partes = texto.split('**');
    for (int i = 0; i < partes.length; i++) {
      if (i.isOdd) {
        spans.add(
          TextSpan(
            text: partes[i],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: textColor,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: partes[i],
            style: TextStyle(fontSize: 13.5, height: 1.5, color: textColor),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Tarjeta de login requerido ───────────────────────────────────────────────

class _TarjetaLoginRequerido extends StatelessWidget {
  final VoidCallback? onIniciarSesion;
  const _TarjetaLoginRequerido({this.onIniciarSesion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Inicia sesión para acceder a esta información',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: onIniciarSesion,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text(
              'Iniciar sesión',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista horizontal de productos en el chat ─────────────────────────────────

class _ListaProductosChat extends StatelessWidget {
  final String titulo;
  final List<AsistenteProductoResponse> productos;

  const _ListaProductosChat({required this.titulo, required this.productos});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs. ',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: productos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = productos[i];
              return Container(
                width: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checkroom,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (p.talla != null || p.color != null)
                      Text(
                        [
                          if (p.talla != null) p.talla!,
                          if (p.color != null) p.color!,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const Spacer(),
                    if (p.precioVigente != null)
                      Text(
                        currencyFormat.format(p.precioVigente),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    if (p.stockDisponible != null)
                      Text(
                        'Stock: ${p.stockDisponible}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
