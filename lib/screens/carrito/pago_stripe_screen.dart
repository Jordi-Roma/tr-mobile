import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pago_models.dart';
import '../../services/pago_service.dart';
import '../../core/network/api_exceptions.dart';
import '../../widgets/payment_status_badge.dart';

/// Pantalla de pago con Stripe — abre el checkout_url en un WebView interno.
/// Al detectar la URL de retorno (success o cancel), consulta el estado de la orden.
class PagoStripeScreen extends StatefulWidget {
  /// URL de checkout obtenida del backend.
  final String checkoutUrl;

  /// ID de la orden para consultar el estado final.
  final int ordenId;

  const PagoStripeScreen({
    super.key,
    required this.checkoutUrl,
    required this.ordenId,
  });

  @override
  State<PagoStripeScreen> createState() => _PagoStripeScreenState();
}

class _PagoStripeScreenState extends State<PagoStripeScreen> {
  WebViewController? _webController;
  bool _cargando = true;
  bool _verificando = false;

  // Stripe redirige a estas URLs tras completar o cancelar
  static const _urlExito = 'stripe-success';
  static const _urlCancel = 'stripe-cancel';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _cargando = false;
      return;
    }

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _cargando = true),
        onPageFinished: (_) => setState(() => _cargando = false),
        onNavigationRequest: (req) {
          final url = req.url.toLowerCase();
          if (url.contains(_urlExito) || url.contains('success')) {
            _verificarOrden(exito: true);
            return NavigationDecision.prevent;
          }
          if (url.contains(_urlCancel) || url.contains('cancel')) {
            _verificarOrden(exito: false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _abrirStripeEnWeb() async {
    final uri = Uri.parse(widget.checkoutUrl);
    final abierto = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Stripe en el navegador.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _verificarOrden({required bool exito}) async {
    if (_verificando) return;
    setState(() => _verificando = true);

    try {
      OrdenPagoResponse orden;
      if (exito) {
        // Al regresar con éxito de la pasarela, confirmamos la orden
        try {
          orden = await PagoService.confirmarPagoPrueba(
            ordenId: widget.ordenId,
            aprobar: true,
          );
        } catch (_) {
          orden = await PagoService.obtenerOrden(widget.ordenId);
        }
      } else {
        orden = await PagoService.obtenerOrden(widget.ordenId);
      }
      if (!mounted) return;

      _mostrarResultado(orden);
    } on ApiException catch (e) {
      if (!mounted) return;
      _mostrarError(e.message);
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo verificar el estado del pago.');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  void _mostrarResultado(OrdenPagoResponse orden) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: _ResultadoPagoContent(orden: orden),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  orden.pagado ? AppColors.success : AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Retorna la orden al caller para que actualice el estado
              Navigator.of(context).pop(orden);
            },
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pago con Stripe'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('¿Cancelar pago?'),
              content: const Text(
                  'Si cierras esta pantalla, el pago no se completará.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Seguir pagando'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar pago'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_verificando)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _verificarOrden(exito: true),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
              label: const Text(
                'Aprobar (Prueba)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: kIsWeb ? _buildWebFallback() : _buildWebViewBody(),
    );
  }

  Widget _buildWebViewBody() {
    final controller = _webController;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_cargando)
          const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
      ],
    );
  }

  Widget _buildWebFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.open_in_new, size: 48, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text(
                  'Abrir pago en Stripe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'En Chrome no se puede mostrar Stripe dentro de un WebView. Abre la pasarela en otra pestaña y, al terminar, vuelve aquí para verificar la orden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _abrirStripeEnWeb,
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Abrir Stripe'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _verificando ? null : () => _verificarOrden(exito: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_verificando ? 'Verificando...' : 'Ya pagué, verificar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget interno para mostrar el resultado del pago.
class _ResultadoPagoContent extends StatelessWidget {
  final OrdenPagoResponse orden;
  const _ResultadoPagoContent({required this.orden});

  @override
  Widget build(BuildContext context) {
    final bool exito = orden.pagado;
    final bool pendiente = orden.pendiente;
    final visual = paymentStatusVisual(orden.estado);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          visual.icon,
          size: 64,
          color: visual.color,
        ),
        const SizedBox(height: 16),
        Text(
          exito
              ? '¡Pago completado!'
              : pendiente
                  ? 'Pago en proceso'
                  : 'Pago no completado',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _InfoRow(
            label: 'Estado',
            valor: visual.label,
            color: visual.color),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            visual.description,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        _InfoRow(label: 'Orden #', valor: orden.ordenId.toString()),
        _InfoRow(
            label: 'Total',
            valor:
                'Bs. ${orden.montoTotal.toStringAsFixed(2)} ${orden.moneda}'),
        _InfoRow(label: 'Método', valor: orden.metodo),
        if (orden.fechaPago != null)
          _InfoRow(label: 'Fecha', valor: orden.fechaPago!),
        const SizedBox(height: 8),
        if (pendiente)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'El pago está siendo procesado. Puedes verificarlo más tarde desde tu perfil.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;
  const _InfoRow({required this.label, required this.valor, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
