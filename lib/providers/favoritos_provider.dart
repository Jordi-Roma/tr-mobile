import 'package:flutter/material.dart';
import '../models/catalogo_models.dart';
import '../services/recomendacion_service.dart';

class FavoritosProvider extends ChangeNotifier {
  final Set<int> _favoritosIds = {};
  List<CatalogoPrendaItem> _favoritos = [];
  bool _cargando = false;
  String? _error;

  Set<int> get favoritosIds => _favoritosIds;
  List<CatalogoPrendaItem> get favoritos => _favoritos;
  bool get cargando => _cargando;
  String? get error => _error;
  int get cantidad => _favoritosIds.length;

  bool esFavorito(int productoId) => _favoritosIds.contains(productoId);

  void limpiar() {
    _favoritosIds.clear();
    _favoritos = [];
    _error = null;
    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarFavoritos() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final items = await RecomendacionService.listarFavoritos();
      _favoritos = items;
      _favoritosIds.clear();
      for (final it in items) {
        _favoritosIds.add(it.productoId);
      }
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _cargando = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> toggleFavorito(int productoId) async {
    final estaba = _favoritosIds.contains(productoId);

    // Actualización optimista inmediata
    if (estaba) {
      _favoritosIds.remove(productoId);
      _favoritos.removeWhere((it) => it.productoId == productoId);
    } else {
      _favoritosIds.add(productoId);
    }
    notifyListeners();

    try {
      final items = estaba
          ? await RecomendacionService.eliminarFavorito(productoId)
          : await RecomendacionService.agregarFavorito(productoId);

      _favoritos = items;
      _favoritosIds.clear();
      for (final it in items) {
        _favoritosIds.add(it.productoId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      // Revertir en caso de error
      if (estaba) {
        _favoritosIds.add(productoId);
      } else {
        _favoritosIds.remove(productoId);
      }
      notifyListeners();
      return false;
    }
  }
}
