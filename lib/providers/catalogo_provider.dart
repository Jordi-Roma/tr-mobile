import '../core/session/contexto_sesion.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/catalogo_models.dart';

class CatalogoProvider extends SessionBoundNotifier {
  List<CatalogoPrendaItem> _prendas = [];
  CatalogoPrendaDetalle? _detalleSeleccionado;
  List<CatalogoDisponibilidad> _disponibilidad = [];
  List<CatalogoSucursal> _sucursales = [];
  List<CatalogoCategoria> _categorias = [];
  List<CatalogoTalla> tallas = [];
  List<CatalogoColor> colores = [];
  List<CatalogoCategoria> temporadas = [];
  List<CatalogoCategoria> colecciones = [];
  int? tallaId, colorId, temporadaId, coleccionId;
  double? precioMin, precioMax;
  String orden = 'relevancia';
  int _pagina = 1;
  int _total = 0;
  int _solicitud = 0;
  int get pagina => _pagina;
  int get total => _total;
  int get paginas => (_total / 24).ceil().clamp(1, 1000000);
  bool get tieneFiltrosAvanzados =>
      tallaId != null ||
      colorId != null ||
      temporadaId != null ||
      coleccionId != null ||
      precioMin != null ||
      precioMax != null ||
      orden != 'relevancia';

  bool _cargando = false;
  bool _cargandoDetalle = false;
  bool _cargandoDisponibilidad = false;
  String? _error;

  String _filtroBusqueda = '';
  int? _filtroCategoriaId;
  int? _filtroSucursalId;
  bool _filtroSoloDisponibles = false;

  List<CatalogoPrendaItem> get prendas => _prendas;
  CatalogoPrendaDetalle? get detalleSeleccionado => _detalleSeleccionado;
  List<CatalogoDisponibilidad> get disponibilidad => _disponibilidad;
  List<CatalogoSucursal> get sucursales => _sucursales;
  List<CatalogoCategoria> get categorias => _categorias;

  bool get cargando => _cargando;
  bool get cargandoDetalle => _cargandoDetalle;
  bool get cargandoDisponibilidad => _cargandoDisponibilidad;
  String? get error => _error;

  String get filtroBusqueda => _filtroBusqueda;
  int? get filtroCategoriaId => _filtroCategoriaId;
  int? get filtroSucursalId => _filtroSucursalId;
  bool get filtroSoloDisponibles => _filtroSoloDisponibles;

  Future<void> cargarPrendas({int pagina = 1}) async {
    final solicitud = ++_solicitud;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (_filtroBusqueda.isNotEmpty) queryParams['q'] = _filtroBusqueda;
      if (_filtroCategoriaId != null) {
        queryParams['categoria_id'] = _filtroCategoriaId.toString();
      }
      if (_filtroSucursalId != null) {
        queryParams['sucursal_id'] = _filtroSucursalId.toString();
      }
      if (_filtroSoloDisponibles) queryParams['solo_disponibles'] = 'true';
      queryParams['por_pagina'] = '24';
      queryParams['pagina'] = pagina.toString();
      queryParams['orden'] = orden;
      if (tallaId != null) queryParams['talla_id'] = tallaId.toString();
      if (colorId != null) queryParams['color_id'] = colorId.toString();
      if (temporadaId != null) {
        queryParams['temporada_id'] = temporadaId.toString();
      }
      if (coleccionId != null) {
        queryParams['coleccion_id'] = coleccionId.toString();
      }
      if (precioMin != null) queryParams['precio_min'] = precioMin.toString();
      if (precioMax != null) queryParams['precio_max'] = precioMax.toString();

      final res = await ApiClient.get(
        ApiConstants.catalogoPrendas,
        queryParams: queryParams,
        withAuth: false,
      );

      if (solicitud != _solicitud) return;
      _pagina = pagina;
      _total = int.tryParse(res['total'].toString()) ?? 0;
      final items =
          (res['items'] as List<dynamic>?)
              ?.map(
                (e) => CatalogoPrendaItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [];
      _prendas = items;
      _cargando = false;
      notifyListeners();
    } catch (e) {
      if (solicitud != _solicitud) return;
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> cargarPrendaDetalle(int id, {int? sucursalId}) async {
    _cargandoDetalle = true;
    _detalleSeleccionado = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (sucursalId != null) {
        queryParams['sucursal_id'] = sucursalId.toString();
      }

      final res = await ApiClient.get(
        ApiConstants.catalogoPrendaDetalle(id),
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        withAuth: false,
      );

      _detalleSeleccionado = CatalogoPrendaDetalle.fromJson(
        res as Map<String, dynamic>,
      );
      _disponibilidad = _detalleSeleccionado!.disponibilidad;
      _cargandoDetalle = false;
      notifyListeners();
    } catch (e) {
      _cargandoDetalle = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> cargarDisponibilidad(int prendaId, {int? sucursalId}) async {
    _cargandoDisponibilidad = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (sucursalId != null) {
        queryParams['sucursal_id'] = sucursalId.toString();
      }

      final res = await ApiClient.get(
        ApiConstants.catalogoDisponibilidad(prendaId),
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        withAuth: false,
      );

      final list =
          (res['disponibilidad'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CatalogoDisponibilidad.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [];
      _disponibilidad = list;
      _cargandoDisponibilidad = false;
      notifyListeners();
    } catch (e) {
      _cargandoDisponibilidad = false;
      notifyListeners();
    }
  }

  Future<void> cargarFiltros() async {
    try {
      final res = await ApiClient.get(
        ApiConstants.catalogoFiltros,
        withAuth: false,
      );
      if (res is Map<String, dynamic>) {
        tallas = (res['tallas'] as List? ?? [])
            .map(
              (e) =>
                  CatalogoTalla.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        colores = (res['colores'] as List? ?? [])
            .map(
              (e) =>
                  CatalogoColor.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        temporadas = (res['temporadas'] as List? ?? [])
            .map(
              (e) => CatalogoCategoria.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        colecciones = (res['colecciones'] as List? ?? [])
            .map(
              (e) => CatalogoCategoria.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        if (res['categorias'] != null) {
          _categorias = (res['categorias'] as List<dynamic>)
              .map((e) => CatalogoCategoria.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (res['sucursales'] != null) {
          _sucursales = (res['sucursales'] as List<dynamic>)
              .map((e) => CatalogoSucursal.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> cargarSucursales() async {
    await cargarFiltros();
  }

  void buscar(String query) {
    _filtroBusqueda = query.trim();
    cargarPrendas();
  }

  void filtrarPorCategoria(int? categoriaId) {
    _filtroCategoriaId = categoriaId;
    cargarPrendas();
  }

  void filtrarPorSucursal(int? sucursalId) {
    _filtroSucursalId = sucursalId;
    cargarPrendas();
  }

  void alternarSoloDisponibles() {
    _filtroSoloDisponibles = !_filtroSoloDisponibles;
    cargarPrendas();
  }

  void aplicarFiltrosAvanzados({
    int? talla,
    int? color,
    int? temporada,
    int? coleccion,
    double? minimo,
    double? maximo,
    String ordenElegido = 'relevancia',
  }) {
    tallaId = talla;
    colorId = color;
    temporadaId = temporada;
    coleccionId = coleccion;
    precioMin = minimo;
    precioMax = maximo;
    orden = ordenElegido;
    cargarPrendas();
  }

  void irPagina(int numero) {
    if (!_cargando && numero >= 1 && numero <= paginas) {
      cargarPrendas(pagina: numero);
    }
  }

  void limpiarFiltros() {
    tallaId = null;
    colorId = null;
    temporadaId = null;
    coleccionId = null;
    precioMin = null;
    precioMax = null;
    orden = 'relevancia';
    _filtroBusqueda = '';
    _filtroCategoriaId = null;
    _filtroSucursalId = null;
    _filtroSoloDisponibles = false;
    cargarPrendas();
  }
}
