import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Permite configurar manualmente una IP local (ej. '192.168.1.5') o URL pública completa (ej. 'https://xxx.ngrok-free.app')
  static String? customHost;

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    final host = _envApiUrl.isNotEmpty ? _envApiUrl : customHost;
    if (host != null && host.isNotEmpty) {
      if (host.startsWith('http://') || host.startsWith('https://')) {
        final clean = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
        return clean.endsWith('/api/v1') ? clean : '$clean/api/v1';
      }
      return 'http://$host:8000/api/v1';
    }

    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Túnel público ngrok: conecta directo desde Wi-Fi, datos móviles 4G/5G o punto de acceso sin configurar IP
        return 'https://impromptu-uncertain-grading.ngrok-free.dev/api/v1';
      default:
        return 'https://impromptu-uncertain-grading.ngrok-free.dev/api/v1';
    }
  }

  // Endpoints Autenticacion
  static String get login => '$baseUrl/autenticacion/login';
  static String get registro => '$baseUrl/autenticacion/registro';
  static String get logout => '$baseUrl/autenticacion/logout';

  // Endpoints Perfil
  static String get perfil => '$baseUrl/perfil';
  static String get perfilPassword => '$baseUrl/perfil/password';
  static String get perfilDirecciones => '$baseUrl/perfil/direcciones';

  // Endpoints Catalogo
  static String get catalogoPrendas => '$baseUrl/catalogo/prendas';
  static String get catalogoFiltros => '$baseUrl/catalogo/filtros';
  static String get catalogoSucursales => '$baseUrl/catalogo/sucursales';
  static String catalogoPrendaDetalle(int id) => '$baseUrl/catalogo/prendas/$id';
  static String catalogoDisponibilidad(int id) => '$baseUrl/catalogo/prendas/$id/disponibilidad';

  // Endpoints Carrito
  static String get carrito => '$baseUrl/carrito';
  static String get carritoItems => '$baseUrl/carrito/items';
  static String carritoItem(int id) => '$baseUrl/carrito/items/$id';

  // Endpoints Reservas
  static String get reservas => '$baseUrl/reservas';
  static String get reservasDesdeCarrito => '$baseUrl/reservas/desde-carrito';
  static String get misReservas => '$baseUrl/reservas/mis-reservas';
  static String reservaDetalle(int id) => '$baseUrl/reservas/$id';
  static String reservaCancelar(int id) => '$baseUrl/reservas/$id/cancelar';
  static String reservaEstado(int id) => '$baseUrl/reservas/$id/estado';
  static String reservaFinalizarVenta(int id) => '$baseUrl/reservas/$id/finalizar-venta';
  static String reservaAnticipoStripe(int id) => '$baseUrl/reservas/$id/anticipo/stripe';
  static String reservaFinalizarCliente(int id) => '$baseUrl/reservas/$id/finalizar';

  // Endpoints Vestidor AR (CU24)
  static String vestidorPrenda(int id) => '$baseUrl/catalogo/vestidor/prenda/$id';
  static String get vestidorPrendasDisponibles => '$baseUrl/catalogo/vestidor/prendas-disponibles';
  static String get vestidorSesion => '$baseUrl/catalogo/vestidor/sesion';
  static String get vestidorProbarIa => '$baseUrl/catalogo/vestidor/probar-ia';

  // Endpoints Administración Catálogo  (prefix: /api/v1 sin /administracion)
  static String get adminProductos => '$baseUrl/productos';
  static String adminProductoDetalle(int id) => '$baseUrl/productos/$id';
  static String adminProductoDesactivar(int id) => '$baseUrl/productos/$id/desactivar';
  static String adminProductoActivar(int id) => '$baseUrl/productos/$id/activar';

  static String get adminCategorias => '$baseUrl/categorias';
  static String adminCategoriaDetalle(int id) => '$baseUrl/categorias/$id';
  static String adminCategoriaDesactivar(int id) => '$baseUrl/categorias/$id/desactivar';
  static String adminCategoriaActivar(int id) => '$baseUrl/categorias/$id/activar';

  static String get adminTallas => '$baseUrl/tallas';
  static String adminTallaDetalle(int id) => '$baseUrl/tallas/$id';
  static String adminTallaDesactivar(int id) => '$baseUrl/tallas/$id/desactivar';
  static String adminTallaActivar(int id) => '$baseUrl/tallas/$id/activar';

  static String get adminColores => '$baseUrl/colores';
  static String adminColorDetalle(int id) => '$baseUrl/colores/$id';
  static String adminColorDesactivar(int id) => '$baseUrl/colores/$id/desactivar';
  static String adminColorActivar(int id) => '$baseUrl/colores/$id/activar';

  static String get adminMarcas => '$baseUrl/marcas';
  static String adminMarcaDetalle(int id) => '$baseUrl/marcas/$id';

  static String get adminVariantes => '$baseUrl/variantes';
  static String adminVarianteDetalle(int id) => '$baseUrl/variantes/$id';
  static String adminVarianteDesactivar(int id) => '$baseUrl/variantes/$id/desactivar';
  static String adminVarianteActivar(int id) => '$baseUrl/variantes/$id/activar';
  static String adminVariantePrecios(int id) => '$baseUrl/variantes/$id/precios';

  // Endpoints Pagos Stripe
  static String get pagoStripeCheckout => '$baseUrl/pagos/stripe/checkout';
  static String pagoOrden(int ordenId) => '$baseUrl/pagos/orden/$ordenId';
  static String pagoConfirmarPrueba(int ordenId) => '$baseUrl/pagos/stripe/confirmar-prueba/$ordenId';
  static String get misPagos => '$baseUrl/pagos/mis-pagos';
  static String miPagoDetalle(int ordenId) => '$baseUrl/pagos/mis-pagos/$ordenId';
  static String get pagosHistorial => '$baseUrl/pagos';
  static String pagoDetalleAdmin(int ordenId) => '$baseUrl/pagos/$ordenId';

  // Endpoints Delivery
  static String get misDeliveries => '$baseUrl/delivery/mis-deliveries';
  static String get deliveryCotizar => '$baseUrl/delivery/cotizar';
  static String get deliveryGeocodificar => '$baseUrl/delivery/geocodificar';
  static String miDeliveryDetalle(int deliveryId) => '$baseUrl/delivery/mis-deliveries/$deliveryId';
  static String get deliveries => '$baseUrl/delivery';
  static String deliveryDetalle(int deliveryId) => '$baseUrl/delivery/$deliveryId';
  static String deliveryEstado(int deliveryId) => '$baseUrl/delivery/$deliveryId/estado';

  // Endpoints Reportes / Dashboard (CU21)
  static String get reportesCatalogo => '$baseUrl/reportes/catalogo';
  static String get reportesInterpretar => '$baseUrl/reportes/interpretar';
  static String get reportesGenerar => '$baseUrl/reportes/generar';
  static String get reportesExportarPdf => '$baseUrl/reportes/exportar/pdf';
  static String get reportesExportarExcel => '$baseUrl/reportes/exportar/excel';
  static String get reportesProgramados => '$baseUrl/reportes/programados';
  static String reporteProgramadoEstado(int id) => '$baseUrl/reportes/programados/$id/estado';
  static String reporteProgramadoDetalle(int id) => '$baseUrl/reportes/programados/$id';
  static String reporteProgramadoEjecutar(int id) => '$baseUrl/reportes/programados/$id/ejecutar';

  // Endpoints Asistente Virtual IA (CU23)
  static String get asistenteChat => '$baseUrl/asistente/chat';

  // Endpoints Recomendaciones e IA
  static String get recomendacionesParaMi => '$baseUrl/recomendaciones/para-mi';
  static String recomendacionesProducto(int productoId) => '$baseUrl/recomendaciones/producto/$productoId';
  static String get recomendacionesFavoritos => '$baseUrl/recomendaciones/favoritos';
  static String recomendacionesFavoritoDetalle(int productoId) => '$baseUrl/recomendaciones/favoritos/$productoId';
}


