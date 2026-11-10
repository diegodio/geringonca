import 'package:flutter/material.dart';

/// Cores do caderno de laboratório, em claro e escuro (as mesmas da versão HTML).
class Palette {
  final Color bg, paper, grid, gridMajor, ink, muted, line, zone, goal, ground, ball, rod, water, cw, ccw, free, mN, mS, accent, lift, door, crate, medal, medalInk;
  const Palette({
    required this.bg,
    required this.paper,
    required this.grid,
    required this.gridMajor,
    required this.ink,
    required this.muted,
    required this.line,
    required this.zone,
    required this.goal,
    required this.ground,
    required this.ball,
    required this.rod,
    required this.water,
    required this.cw,
    required this.ccw,
    required this.free,
    required this.mN,
    required this.mS,
    required this.accent,
    required this.lift,
    required this.door,
    required this.crate,
    required this.medal,
    required this.medalInk,
  });

  static const light = Palette(
    bg: Color(0xffe7edef), paper: Color(0xfff3f6f6), grid: Color(0xffd3dee2), gridMajor: Color(0xffb9cbd2),
    ink: Color(0xff1b2a32), muted: Color(0xff5a6e78), line: Color(0xffc3d1d7),
    zone: Color(0xff2f9a5c), goal: Color(0xffd8322b), ground: Color(0xff8a9aa1), ball: Color(0xfff2bb12),
    rod: Color(0xff8b5a2b), water: Color(0xff4f9fd8), cw: Color(0xffe57421), ccw: Color(0xff6a48cc), free: Color(0xff557885),
    mN: Color(0xffd8322b), mS: Color(0xff1f62c9), accent: Color(0xff1f6fb0),
    lift: Color(0xff2a8a86), door: Color(0xff7b4fa0), crate: Color(0xffc9a468), medal: Color(0xffd9a414), medalInk: Color(0xff2a1d00),
  );

  static const dark = Palette(
    bg: Color(0xff0e1a22), paper: Color(0xff12222c), grid: Color(0xff1a2f3b), gridMajor: Color(0xff24404f),
    ink: Color(0xffe2ecf0), muted: Color(0xff91a7b1), line: Color(0xff27414f),
    zone: Color(0xff45c27a), goal: Color(0xfff0564e), ground: Color(0xff4b6370), ball: Color(0xffffd03a),
    rod: Color(0xffc18a52), water: Color(0xff6cb6ee), cw: Color(0xfff4913f), ccw: Color(0xff9a7ef0), free: Color(0xff7fa3b0),
    mN: Color(0xfff0564e), mS: Color(0xff4f8ff0), accent: Color(0xff5fb0ec),
    lift: Color(0xff3fb7b1), door: Color(0xffa97fcf), crate: Color(0xffb08a4e), medal: Color(0xffe8b93a), medalInk: Color(0xff2a1d00),
  );

  static Palette of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;

  Color wheel(String k) => k == 'cw' ? cw : k == 'ccw' ? ccw : free;
}
