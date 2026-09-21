import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/carrito_models.dart';
import '../models/catalogo_models.dart';

class CarritoProvider extends ChangeNotifier {
  CarritoResponse? _carrito;
  bool _cargando = false;
  String? _error;

  CarritoResponse? get carrito => _carrito;
  bool get cargando => _cargando;
  String? get error => _error;

  int get cantidadTotal => _carrito?.totalItems ?? 0;
  double get totalMonto => _carrito?.total ?? 0.0;
  List<CarritoItemResponse> get items => _carrito?.items ?? [];
  List<CatalogoSucursal> get sucursalesDisponibles => _carrito?.sucursalesDisponibles ?? [];

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  void limpiarCarrito() {
    _carrito = null;
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarCarrito() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiConstants.carrito);
      _carrito = CarritoResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<bool> agregarItem({
    required int varianteId,
    required int cantidad,
    int? sucursalId,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiConstants.carritoItems,
        body: {
          'producto_variante_id': varianteId,
          'cantidad': cantidad,
          ...?sucursalId != null ? {'sucursal_id': sucursalId} : null,
        },
      );

      _carrito = CarritoResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarCantidad(int itemId, int cantidad) async {
    if (cantidad <= 0) {
      return eliminarItem(itemId);
    }

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.put(
        ApiConstants.carritoItem(itemId),
        body: {'cantidad': cantidad},
      );

      _carrito = CarritoResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarItem(int itemId) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.delete(ApiConstants.carritoItem(itemId));
      _carrito = CarritoResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> vaciarCarrito() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.delete(ApiConstants.carrito);
      _carrito = CarritoResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
