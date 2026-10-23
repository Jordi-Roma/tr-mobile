String? validarPasswordCuenta(String? valor) {
  final texto = valor ?? '';
  if (texto.length < 8 ||
      !RegExp('[A-Z]').hasMatch(texto) ||
      !RegExp('[a-z]').hasMatch(texto) ||
      !RegExp('[0-9]').hasMatch(texto) ||
      !RegExp(r'[^A-Za-z0-9]').hasMatch(texto)) {
    return 'Usa al menos 8 caracteres, mayúscula, minúscula, número y símbolo.';
  }
  return null;
}

String? validarCorreoCuenta(String? valor) {
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((valor ?? '').trim())) {
    return 'Ingresa un correo válido.';
  }
  return null;
}

String? validarUsuarioCuenta(String? valor) {
  if (!RegExp(r'^[a-zA-Z0-9_.-]{4,80}$').hasMatch((valor ?? '').trim())) {
    return 'Usa de 4 a 80 letras, números, punto o guion.';
  }
  return null;
}
