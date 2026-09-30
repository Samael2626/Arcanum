// Aritmetica con la semantica de JavaScript.
//
// El motor nace en el prototipo HTML (arcanum-sigil-prototype/js) y los tests
// comparan este puerto con la salida del prototipo. Donde Dart y JS difieren
// (redondeo, resto, formato de -0) se imita a JS para que el mismo sigilo
// salga con los mismos numeros en los dos lados.
import 'dart:math' as math;

const double kPi = math.pi;

double rad(double d) => d * math.pi / 180;

/// Math.round de JS: el medio redondea hacia +infinito (-2.5 -> -2).
double jsRound(double x) => (x + 0.5).floorToDouble();

/// Operador % de JS: el resto conserva el signo del dividendo.
double jsRem(double a, double b) => a.remainder(b);

/// Math.hypot para dos valores.
double hypot(double x, double y) => math.sqrt(x * x + y * y);

/// Number.prototype.toFixed(2). JS escribe -0 como "0.00".
String f2(double v) => (v == 0 ? 0.0 : v).toStringAsFixed(2);

/// Firma de dos decimales del prototipo: (Math.round(v*100)/100 + 0).toFixed(2).
String r2(double v) => f2(jsRound(v * 100) / 100 + 0);

/// Formato de numero de JS para cadenas (String(n)): enteros sin ".0".
String jsNum(num v) {
  if (v is int) return '$v';
  final d = v.toDouble();
  if (d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}

double cosD(double deg) => math.cos(rad(deg));
double sinD(double deg) => math.sin(rad(deg));
