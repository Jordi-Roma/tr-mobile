class PerfilResponse {
  final int id;
  final String nombre;
  final String apellido;
  final String username;
  final String correo;
  final String? telefono;
  final List<String> roles;

  PerfilResponse({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.username,
    required this.correo,
    this.telefono,
    required this.roles,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  factory PerfilResponse.fromJson(Map<String, dynamic> json) {
    return PerfilResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      username: json['username'] ?? '',
      correo: json['correo'] ?? '',
      telefono: json['telefono'],
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class Direccion {
  final int id;
  final String direccion;
  final int ciudadId;
  final String ciudad;
  final String? referencia;
  final bool esPrincipal;

  Direccion({
    required this.id,
    required this.direccion,
    required this.ciudadId,
    required this.ciudad,
    this.referencia,
    required this.esPrincipal,
  });

  factory Direccion.fromJson(Map<String, dynamic> json) {
    return Direccion(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      direccion: json['direccion'] ?? '',
      ciudadId: json['ciudad_id'] is int ? json['ciudad_id'] : int.parse(json['ciudad_id'].toString()),
      ciudad: json['ciudad'] ?? '',
      referencia: json['referencia'],
      esPrincipal: json['es_principal'] ?? false,
    );
  }
}
