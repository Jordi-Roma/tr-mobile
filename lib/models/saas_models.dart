class OpcionPlanSaas {
  final String clave, nombre, descripcion, unidad;
  final int minimo;
  final List<String> dependencias, requiereAlguna;
  OpcionPlanSaas.fromJson(Map<String, dynamic> j)
    : clave = j['clave'] as String,
      nombre = j['nombre'] as String,
      descripcion = j['descripcion'] as String? ?? '',
      unidad = j['unidad'] as String? ?? '',
      minimo = (j['minimo'] as num?)?.toInt() ?? 0,
      dependencias = (j['dependencias'] as List? ?? []).cast<String>(),
      requiereAlguna = (j['requiere_alguna'] as List? ?? []).cast<String>();
}

class CatalogoSaas {
  final List<OpcionPlanSaas> funciones, limites;
  CatalogoSaas.fromJson(Map<String, dynamic> j)
    : funciones = (j['funciones'] as List)
          .map((v) => OpcionPlanSaas.fromJson(v as Map<String, dynamic>))
          .toList(),
      limites = (j['limites'] as List)
          .map((v) => OpcionPlanSaas.fromJson(v as Map<String, dynamic>))
          .toList();
  String nombre(String clave) =>
      [
        ...funciones,
        ...limites,
      ].where((v) => v.clave == clave).firstOrNull?.nombre ??
      clave;
}

class PlanSaas {
  final int id, revision;
  final String codigo, nombre, descripcion, condiciones, precio, moneda;
  final bool activo, publico;
  final Map<String, int> limites;
  final Map<String, bool> funciones;
  PlanSaas.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num).toInt(),
      revision = (j['revision'] as num?)?.toInt() ?? 1,
      codigo = j['codigo'] as String,
      nombre = j['nombre'] as String,
      descripcion = j['descripcion'] as String? ?? '',
      condiciones = j['condiciones'] as String? ?? '',
      precio = (j['precio'] ?? 0).toString(),
      moneda = j['moneda'] as String? ?? 'BOB',
      activo = j['activo'] == true,
      publico = j['publico'] == true,
      limites = (j['limites'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      funciones = (j['funciones'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v == true),
      );
}

class PreviaPlanSaas {
  final String token;
  final Map<String, dynamic> propuesta;
  final List<Map<String, dynamic>> empresas;
  final int total;
  PreviaPlanSaas.fromJson(Map<String, dynamic> j)
    : token = j['token_previsualizacion'] as String,
      propuesta = j['propuesta'] as Map<String, dynamic>,
      empresas = ((j['impacto'] as Map)['empresas'] as List)
          .cast<Map<String, dynamic>>(),
      total = ((j['impacto'] as Map)['total_empresas'] as num).toInt();
}

class EmpresaSaas {
  final int id;
  final int? planId;
  final String nombre, codigo, estado;
  final String? planNombre,
      inicio,
      fin,
      suscripcionEstado,
      contacto,
      responsable;
  EmpresaSaas.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num).toInt(),
      planId = (j['plan_id'] as num?)?.toInt(),
      nombre = j['nombre'] as String,
      codigo = j['codigo'] as String,
      estado = j['estado'] as String,
      planNombre = j['plan_nombre'] as String?,
      inicio = j['fecha_inicio'] as String?,
      fin = j['fecha_vencimiento'] as String?,
      suscripcionEstado = j['suscripcion_estado'] as String?,
      contacto = j['correo_contacto'] as String?,
      responsable = j['responsable'] as String?;
}

class PaginaEmpresasSaas {
  final int total, pagina, tamano;
  final List<EmpresaSaas> empresas;
  PaginaEmpresasSaas.fromJson(Map<String, dynamic> j)
    : total = (j['total'] as num).toInt(),
      pagina = (j['pagina'] as num).toInt(),
      tamano = (j['tamano'] as num).toInt(),
      empresas = (j['empresas'] as List)
          .map((v) => EmpresaSaas.fromJson(v as Map<String, dynamic>))
          .toList();
}

/// Comprueba dependencias del catálogo sin deducir reglas del nombre de un plan.
String? validarPoliticaSaas(
  CatalogoSaas catalogo,
  Map<String, int> limites,
  Map<String, bool> funciones,
) {
  for (final f in catalogo.funciones) {
    if (funciones[f.clave] == true &&
        (f.dependencias.any((d) => funciones[d] != true) ||
            (f.requiereAlguna.isNotEmpty &&
                !f.requiereAlguna.any((d) => funciones[d] == true)))) {
      return 'Revisa las dependencias de ${f.nombre}.';
    }
  }
  if (funciones['reportes_programacion'] == true &&
      limites['reportes_programados'] == 0) {
    return 'La programación necesita un cupo mayor que cero.';
  }
  if (funciones['respaldos_manuales'] == true &&
      (limites['respaldos_manuales_semana'] ?? 0) < 1) {
    return 'Los respaldos manuales necesitan un cupo mayor que cero.';
  }
  return null;
}

/// Envía solo lo editado: una revisión nueva no debe pisar campos ajenos.
Map<String, dynamic> cambiosPlanSaas(
  PlanSaas plan,
  Map<String, dynamic> editado,
) {
  final original = <String, dynamic>{
    'codigo': plan.codigo,
    'nombre': plan.nombre,
    'descripcion': plan.descripcion,
    'condiciones': plan.condiciones,
    'precio': plan.precio,
    'moneda': plan.moneda,
    'activo': plan.activo,
    'publico': plan.publico,
  };
  final cambios = <String, dynamic>{};
  for (final e in original.entries) {
    if (editado.containsKey(e.key) && editado[e.key] != e.value) {
      cambios[e.key] = editado[e.key];
    }
  }
  final limites = <String, int>{};
  for (final e in (editado['limites'] as Map<String, int>).entries) {
    if (plan.limites[e.key] != e.value) limites[e.key] = e.value;
  }
  final funciones = <String, bool>{};
  for (final e in (editado['funciones'] as Map<String, bool>).entries) {
    if ((plan.funciones[e.key] ?? true) != e.value) funciones[e.key] = e.value;
  }
  if (limites.isNotEmpty) cambios['limites'] = limites;
  if (funciones.isNotEmpty) cambios['funciones'] = funciones;
  return cambios;
}
