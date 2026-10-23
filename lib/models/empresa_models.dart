class EmpresaPublica {
  final int id;
  final String codigo;
  final String nombre;
  final String estado;
  const EmpresaPublica({required this.id, required this.codigo, required this.nombre, required this.estado});
  factory EmpresaPublica.fromJson(Map<String, dynamic> json) => EmpresaPublica(
    id: (json['id'] as num).toInt(), codigo: json['codigo'] as String,
    nombre: json['nombre'] as String, estado: json['estado'] as String,
  );
}
