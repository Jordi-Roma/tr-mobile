import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/reserva_models.dart';

class ReservaProvider extends ChangeNotifier {
  List<ReservaResponse> _misReservas = [];
  List<ReservaResponse> _reservasAdmin = [];
  ReservaResponse? _reservaDetalle;
  bool _cargando = false;
  String? _error;

  List<ReservaResponse> get misReservas => _misReservas;
  List<ReservaResponse> get reservasAdmin => _reservasAdmin;
  ReservaResponse? get reservaDetalle => _reservaDetalle;
  bool get cargando => _cargando;
  String? get error => _error;

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  Future<ReservaResponse?> crearReservaDesdeCarrito({
    required int sucursalId,
    required String fechaCita,
    String? observacion,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiConstants.reservasDesdeCarrito,
        body: {
          'sucursal_id': sucursalId,
          'fecha_cita': fechaCita,
          if (observacion != null && observacion.isNotEmpty) 'observacion': observacion,
        },
      );

      final nuevaReserva = ReservaResponse.fromJson(res as Map<String, dynamic>);
      _misReservas.insert(0, nuevaReserva);
      _cargando = false;
      notifyListeners();
      return nuevaReserva;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> cargarMisReservas() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiConstants.misReservas);
      _misReservas = (res as List<dynamic>?)
              ?.map((e) => ReservaResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> cargarReservasAdmin({String? estado, int? sucursalId}) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (estado != null && estado.isNotEmpty) queryParams['estado'] = estado;
      if (sucursalId != null) queryParams['sucursal_id'] = sucursalId.toString();

      final res = await ApiClient.get(
        ApiConstants.reservas,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      _reservasAdmin = (res as List<dynamic>?)
              ?.map((e) => ReservaResponse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> cargarReservaDetalle(int id) async {
    _cargando = true;
    _reservaDetalle = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiConstants.reservaDetalle(id));
      _reservaDetalle = ReservaResponse.fromJson(res as Map<String, dynamic>);
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<bool> cancelarReserva(int id) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.patch(ApiConstants.reservaCancelar(id), body: {});
      final actualizada = ReservaResponse.fromJson(res as Map<String, dynamic>);

      // Actualizar en listas locales
      final index = _misReservas.indexWhere((r) => r.id == id);
      if (index != -1) _misReservas[index] = actualizada;

      final adminIndex = _reservasAdmin.indexWhere((r) => r.id == id);
      if (adminIndex != -1) _reservasAdmin[adminIndex] = actualizada;

      if (_reservaDetalle?.id == id) _reservaDetalle = actualizada;

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

  Future<bool> cambiarEstado(int id, String nuevoEstado) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.patch(
        ApiConstants.reservaEstado(id),
        body: {'estado': nuevoEstado},
      );
      final actualizada = ReservaResponse.fromJson(res as Map<String, dynamic>);

      final adminIndex = _reservasAdmin.indexWhere((r) => r.id == id);
      if (adminIndex != -1) _reservasAdmin[adminIndex] = actualizada;

      if (_reservaDetalle?.id == id) _reservaDetalle = actualizada;

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

  Future<bool> finalizarComoVenta({
    required int id,
    required String metodoPago,
    String? observacion,
    required Map<int, int> cantidades,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiConstants.reservaFinalizarVenta(id),
        body: {
          'metodo_pago': metodoPago,
          if (observacion != null && observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
          'items': cantidades.entries
              .map((entry) => {
                    'reserva_detalle_id': entry.key,
                    'cantidad': entry.value,
                  })
              .toList(),
        },
      );
      final actualizada = ReservaResponse.fromJson(res as Map<String, dynamic>);

      final adminIndex = _reservasAdmin.indexWhere((r) => r.id == id);
      if (adminIndex != -1) {
        if (['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(actualizada.estado)) {
          _reservasAdmin.removeAt(adminIndex);
        } else {
          _reservasAdmin[adminIndex] = actualizada;
        }
      }
      final misIndex = _misReservas.indexWhere((r) => r.id == id);
      if (misIndex != -1) _misReservas[misIndex] = actualizada;
      if (_reservaDetalle?.id == id) _reservaDetalle = actualizada;

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

  Future<ReservaPagoResponse?> pagarAnticipoStripe(int id) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(ApiConstants.reservaAnticipoStripe(id), body: {});
      final respuesta = ReservaPagoResponse.fromJson(res as Map<String, dynamic>);
      _actualizarReservaLocal(respuesta.reserva);
      _cargando = false;
      notifyListeners();
      return respuesta;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ReservaPagoResponse?> finalizarMiReserva({
    required int id,
    required String metodoPago,
    String? observacion,
    required Map<int, int> cantidades,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiConstants.reservaFinalizarCliente(id),
        body: {
          'metodo_pago': metodoPago,
          if (observacion != null && observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
          'items': cantidades.entries
              .map((entry) => {
                    'reserva_detalle_id': entry.key,
                    'cantidad': entry.value,
                  })
              .toList(),
        },
      );
      final respuesta = ReservaPagoResponse.fromJson(res as Map<String, dynamic>);
      _actualizarReservaLocal(respuesta.reserva);
      _cargando = false;
      notifyListeners();
      return respuesta;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  void _actualizarReservaLocal(ReservaResponse actualizada) {
    final misIndex = _misReservas.indexWhere((r) => r.id == actualizada.id);
    if (misIndex != -1) _misReservas[misIndex] = actualizada;

    final adminIndex = _reservasAdmin.indexWhere((r) => r.id == actualizada.id);
    if (adminIndex != -1) {
      if (['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(actualizada.estado)) {
        _reservasAdmin.removeAt(adminIndex);
      } else {
        _reservasAdmin[adminIndex] = actualizada;
      }
    }

    if (_reservaDetalle?.id == actualizada.id) _reservaDetalle = actualizada;
  }
}
