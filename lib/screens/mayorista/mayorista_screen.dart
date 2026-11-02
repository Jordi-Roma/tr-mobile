import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/catalogo_models.dart';
import '../../services/mayorista_service.dart';
import '../../providers/carrito_provider.dart';
import '../../core/session/contexto_sesion.dart';
import '../../core/network/api_exceptions.dart';

class MayoristaScreen extends StatefulWidget {
  final CatalogoPrendaDetalle detalle;
  const MayoristaScreen({super.key, required this.detalle});
  @override
  State<MayoristaScreen> createState() => _MayoristaScreenState();
}

class _MayoristaScreenState extends State<MayoristaScreen> {
  int? sucursal;
  OpcionesMayorista? datos;
  OpcionMayorista? opcion;
  final cantidades = <int, int>{};
  bool ocupado = false, cargando = false;
  String? error, aviso;
  int solicitud = 0, generacion = 0;
  Map<int, String> get sucursales => {
    for (final d in widget.detalle.disponibilidad)
      d.sucursalId: '${d.ciudad} · ${d.sucursal}',
  };
  @override
  void initState() {
    super.initState();
    generacion = ContextoSesion.instance.generacion;
    ContextoSesion.instance.addListener(cambio);
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(cambio);
    super.dispose();
  }

  void cambio() {
    if (mounted && generacion != ContextoSesion.instance.generacion) {
      generacion = ContextoSesion.instance.generacion;
      solicitud++;
      setState(() {
        datos = null;
        opcion = null;
        cantidades.clear();
        error = 'La sesión cambió. Actualiza la selección de sucursal.';
        cargando = false;
      });
    }
  }

  Future<void> cargar(int sid) async {
    final n = ++solicitud;
    setState(() {
      sucursal = sid;
      datos = null;
      opcion = null;
      cantidades.clear();
      cargando = true;
      error = null;
      aviso = null;
    });
    try {
      final d = await MayoristaService.opciones(widget.detalle.productoId, sid);
      if (mounted && n == solicitud) setState(() => datos = d);
    } catch (e) {
      if (mounted && n == solicitud) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No se pudieron consultar los paquetes.',
        );
      }
    } finally {
      if (mounted && n == solicitud) setState(() => cargando = false);
    }
  }

  int get total => cantidades.values.fold(0, (a, b) => a + b);
  double get monto =>
      datos?.variantes.fold<double>(
        0.0,
        (s, v) =>
            s + (opcion?.precio(v.precioBase) ?? 0) * (cantidades[v.id] ?? 0),
      ) ??
      0;
  Future<void> agregar() async {
    final p = opcion, sid = sucursal;
    if (p == null || sid == null || ocupado || total != p.cantidad) return;
    if (ContextoSesion.instance.usuario == null) {
      setState(
        () => error = 'Inicia sesión como cliente para agregar un paquete.',
      );
      return;
    }
    final n = solicitud;
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await MayoristaService.agregar(
        widget.detalle.productoId,
        sid,
        p.tipo,
        cantidades,
      );
      if (!mounted || n != solicitud) return;
      await context.read<CarritoProvider>().cargarCarrito();
      if (mounted && n == solicitud) {
        setState(() {
          aviso = 'Paquete agregado. Puedes combinarlo con unidades normales.';
          cantidades.clear();
        });
      }
    } catch (e) {
      if (mounted && n == solicitud) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No se confirmó la operación. Reintenta la misma selección.',
        );
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comprar por mayor')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.detalle.nombre,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Paquetes de 3, 6 o 12 prendas. Los porcentajes se aplican por variante y no se acumulan con promociones.',
        ),
        DropdownButtonFormField<int>(
          initialValue: sucursal,
          decoration: const InputDecoration(
            labelText: 'Sucursal para el paquete',
          ),
          items: sucursales.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: ocupado
              ? null
              : (v) {
                  if (v != null) cargar(v);
                },
        ),
        if (cargando) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          if (sucursal != null)
            TextButton(
              onPressed: ocupado ? null : () => cargar(sucursal!),
              child: const Text('Actualizar paquetes'),
            ),
        ],
        if (aviso != null) Text(aviso!),
        for (final p in datos?.paquetes ?? <OpcionMayorista>[])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.nombre} · ${p.cantidad} prendas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    p.descuento == null
                        ? 'Sin porcentaje configurado'
                        : '${p.descuento}% de descuento por prenda',
                  ),
                  Text(p.regla),
                  if (p.motivo != null) Text(p.motivo!),
                  TextButton(
                    onPressed: !p.disponible || ocupado
                        ? null
                        : () => setState(() {
                            opcion = p;
                            cantidades.clear();
                            error = null;
                            aviso = null;
                          }),
                    child: Text('Armar ${p.nombre}'),
                  ),
                ],
              ),
            ),
          ),
        if (opcion != null) ...[
          Text(
            '${opcion!.nombre}: selecciona exactamente ${opcion!.cantidad} prendas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(opcion!.regla),
          for (final v in datos!.variantes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                key: ValueKey('${opcion!.tipo}-${v.id}-$aviso'),
                initialValue: '${cantidades[v.id] ?? 0}',
                keyboardType: TextInputType.number,
                enabled: !ocupado && v.stock > 0 && v.precioBase > 0,
                decoration: InputDecoration(
                  labelText: '${v.talla} / ${v.color}',
                  helperText:
                      'Stock ${v.stock} · ${opcion!.precio(v.precioBase).toStringAsFixed(2)} Bs por prenda',
                ),
                onChanged: (s) {
                  final q = int.tryParse(s);
                  setState(
                    () => cantidades[v.id] = q != null && q >= 0 && q <= 12
                        ? q
                        : 0,
                  );
                },
              ),
            ),
          Text(
            'Seleccionadas: $total de ${opcion!.cantidad}. Total: ${monto.toStringAsFixed(2)} Bs.',
          ),
          ElevatedButton(
            onPressed: ocupado || total != opcion!.cantidad ? null : agregar,
            child: Text(
              ocupado ? 'Agregando paquete…' : 'Agregar paquete al carrito',
            ),
          ),
        ],
      ],
    ),
  );
}
