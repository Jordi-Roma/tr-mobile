class UsuarioAutenticado {
  final int id;
  final String nombre;
  final String apellido;
  final String username;
  final String correo;
  final List<String> roles;

  UsuarioAutenticado({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.username,
    required this.correo,
    required this.roles,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();
  bool get esCliente => roles.contains('CLIENTE');
  bool get esAdmin => roles.contains('ADMINISTRADOR');
  bool get esEncargado => roles.contains('ENCARGADO_SUCURSAL');
  bool get esCajero => roles.contains('CAJERO');
  bool get esAdminOEncargado => esAdmin || esEncargado;

  factory UsuarioAutenticado.fromJson(Map<String, dynamic> json) {
    return UsuarioAutenticado(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      username: json['username'] ?? '',
      correo: json['correo'] ?? '',
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'username': username,
      'correo': correo,
      'roles': roles,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final int usuarioId;
  final String nombre;
  final String apellido;
  final String username;
  final String correo;
  final List<String> roles;
  final String mensaje;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.username,
    required this.correo,
    required this.roles,
    required this.mensaje,
  });

  UsuarioAutenticado toUsuario() {
    return UsuarioAutenticado(
      id: usuarioId,
      nombre: nombre,
      apellido: apellido,
      username: username,
      correo: correo,
      roles: roles,
    );
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      usuarioId: json['usuario_id'] is int ? json['usuario_id'] : int.parse(json['usuario_id'].toString()),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      username: json['username'] ?? '',
      correo: json['correo'] ?? '',
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mensaje: json['mensaje'] ?? '',
    );
  }
}

class RegistroResponse {
  final int id;
  final String nombre;
  final String apellido;
  final String username;
  final String correo;
  final String rol;
  final String mensaje;

  RegistroResponse({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.username,
    required this.correo,
    required this.rol,
    required this.mensaje,
  });

  factory RegistroResponse.fromJson(Map<String, dynamic> json) {
    return RegistroResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      username: json['username'] ?? '',
      correo: json['correo'] ?? '',
      rol: json['rol'] ?? 'CLIENTE',
      mensaje: json['mensaje'] ?? '',
    );
  }
}
