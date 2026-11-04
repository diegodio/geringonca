// Seno e cosseno determinísticos.
//
// math.sin e math.cos do Dart chamam a biblioteca matemática de cada sistema
// (glibc, Bionic no Android, libm da Apple, Math.sin do navegador), que podem
// diferir na última casa decimal. Na física isso cresce a cada passo e a mesma
// engenhoca pode terminar diferente no celular e na web. Aqui só há soma,
// multiplicação e arredondamento, que o IEEE 754 garante iguais em toda parte
// (o Dart não funde multiplicação com soma).
const double _halfPi = 1.5707963267948966;
const double _halfPiHi = 1.5707963267341256; // 33 bits: q * hi é exato para |q| < 2^20
const double _halfPiLo = 6.077100506506192e-11;

/// Reduz [x] a r em [-π/4, π/4] e devolve (r, quadrante 0..3).
(double, int) _reduce(double x) {
  final q = (x / _halfPi).roundToDouble();
  final r = (x - q * _halfPiHi) - q * _halfPiLo;
  return (r, q.toInt() & 3);
}

// Séries de Taylor até r^17: erro < 1e-16 para |r| ≤ π/4.
double _sinPoly(double r) {
  final r2 = r * r;
  return r *
      (1 +
          r2 *
              (-1 / 6 +
                  r2 *
                      (1 / 120 +
                          r2 *
                              (-1 / 5040 +
                                  r2 *
                                      (1 / 362880 +
                                          r2 *
                                              (-1 / 39916800 +
                                                  r2 * (1 / 6227020800 + r2 * (-1 / 1307674368000 + r2 * (1 / 355687428096000)))))))));
}

double _cosPoly(double r) {
  final r2 = r * r;
  return 1 +
      r2 *
          (-1 / 2 +
              r2 *
                  (1 / 24 +
                      r2 *
                          (-1 / 720 +
                              r2 *
                                  (1 / 40320 +
                                      r2 *
                                          (-1 / 3628800 +
                                              r2 * (1 / 479001600 + r2 * (-1 / 87178291200 + r2 * (1 / 20922789888000))))))));
}

double dsin(double x) {
  final (r, q) = _reduce(x);
  return switch (q) { 0 => _sinPoly(r), 1 => _cosPoly(r), 2 => -_sinPoly(r), _ => -_cosPoly(r) };
}

double dcos(double x) {
  final (r, q) = _reduce(x);
  return switch (q) { 0 => _cosPoly(r), 1 => -_sinPoly(r), 2 => -_cosPoly(r), _ => _sinPoly(r) };
}
