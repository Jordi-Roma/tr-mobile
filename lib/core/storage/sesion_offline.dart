import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../models/auth_models.dart';
import '../../models/empresa_models.dart';

class SesionOffline {
  static bool get disponible => !kIsWeb && Platform.isAndroid;
  static const _almacen = FlutterSecureStorage();
  static const _clave = 'stylear_acceso_offline_v1';
  static const vigencia = Duration(hours: 24);

  final EmpresaPublica empresa;
  final UsuarioAutenticado usuario;
  final DateTime vence;

  SesionOffline(this.empresa, this.usuario, this.vence);

  String get ambito => '${empresa.id}:${usuario.id}';
  String get ambitoDatos {
    final roles = usuario.roles.toSet().toList()..sort();
    return '$ambito:${roles.join(',')}';
  }

  bool get vigente => DateTime.now().isBefore(vence);
  bool get puedeVender =>
      usuario.esAdmin || usuario.esEncargado || usuario.esCajero;
  bool get puedeReservar => usuario.esCliente && !puedeVender;

  static Future<void> habilitar(
    EmpresaPublica? empresa,
    UsuarioAutenticado usuario,
  ) async {
    if (!disponible || empresa == null) return;
    if (!(usuario.esCliente ||
        usuario.esAdmin ||
        usuario.esEncargado ||
        usuario.esCajero)) {
      await cerrar();
      return;
    }
    if (!await LocalAuthentication().isDeviceSupported()) return;
    await _almacen.write(
      key: _clave,
      value: jsonEncode({
        'empresa': {
          'id': empresa.id,
          'codigo': empresa.codigo,
          'nombre': empresa.nombre,
          'estado': empresa.estado,
        },
        'usuario': usuario.toJson(),
        'vence': DateTime.now().toUtc().add(vigencia).toIso8601String(),
      }),
    );
  }

  static Future<SesionOffline?> leer() async {
    if (!disponible) return null;
    final texto = await _almacen.read(key: _clave);
    if (texto == null) return null;
    try {
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      final empresa = EmpresaPublica.fromJson(
        datos['empresa'] as Map<String, dynamic>,
      );
      final usuario = UsuarioAutenticado.fromJson(
        datos['usuario'] as Map<String, dynamic>,
      );
      final acceso = SesionOffline(
        empresa,
        usuario,
        DateTime.parse(datos['vence'] as String),
      );
      return acceso.vigente &&
              empresa.estado == 'ACTIVA' &&
              usuario.empresaId == empresa.id &&
              usuario.empresaCodigo == empresa.codigo
          ? acceso
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static Future<bool> desbloquear() => LocalAuthentication().authenticate(
    localizedReason: 'Desbloquea el acceso offline de StyleAR',
  );

  static Future<void> cerrar() async {
    if (disponible) await _almacen.delete(key: _clave);
  }
}
