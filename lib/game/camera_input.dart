part of 'controller.dart';

/// Câmera (zoom, enquadrar, mão) e toques na bancada: um dedo constrói ou edita,
/// dois dedos fazem pinça, e o modo Mão ou o botão direito do mouse arrastam a tela.
mixin _CameraInput on GameState {
  bool panMode = false;
  final Map<int, Pt> _pointers = {};
  ({double d0, double z0, Pt wm})? _pinch;
  bool _pinchTail = false;

  // ---------- câmera ----------
  Pt toWorld(Pt sp) => Pt(cam.x + sp.x / cam.z, cam.y + sp.y / cam.z);

  void _clampCam() {
    cam.z = clampD(cam.z, 1, 4);
    cam.x = clampD(cam.x, 0, kW - kW / cam.z);
    cam.y = clampD(cam.y, 0, kH - kH / cam.z);
  }

  void zoomAt(Pt sp, double f) {
    final wp = toWorld(sp);
    cam.z = clampD(cam.z * f, 1, 4);
    cam.x = wp.x - sp.x / cam.z;
    cam.y = wp.y - sp.y / cam.z;
    _clampCam();
    notifyListeners();
  }

  void zoomIn() => zoomAt(Pt(kW / 2, kH / 2), 1.5);
  void zoomOut() => zoomAt(Pt(kW / 2, kH / 2), 1 / 1.5);

  void zoomFit() {
    cam = Cam();
    notifyListeners();
  }

  void zoomZone() {
    final z = cur.zone;
    cam.z = clampD(math.min(kW / (z.w + 80), kH / (z.h + 80)), 1, 4);
    cam.x = z.x + z.w / 2 - kW / (2 * cam.z);
    cam.y = z.y + z.h / 2 - kH / (2 * cam.z);
    _clampCam();
    notifyListeners();
  }

  void togglePan() {
    panMode = !panMode;
    notifyListeners();
  }

  // ---------- toques ----------
  bool hasPointer(int id) => _pointers.containsKey(id);

  /// [sp] em coordenadas da bancada (0..1000, 0..560) sem zoom.
  void pointerDown(int id, Pt sp, {bool secondary = false}) {
    _pointers[id] = sp;
    if (_pointers.length == 2) {
      _cancelBuildAction();
      final v = _pointers.values.toList(), mid = Pt((v[0].x + v[1].x) / 2, (v[0].y + v[1].y) / 2);
      _pinch = (d0: math.max(10, dist(v[0], v[1])), z0: cam.z, wm: toWorld(mid));
      return notifyListeners();
    }
    if (_pointers.length > 2 || _pinchTail) return;
    if (secondary || panMode || mode == Mode.run) {
      action = Act('pan')..last = sp;
      return;
    }
    final p = toWorld(sp);
    mode == Mode.edit ? _editDown(p) : _buildDown(p);
    notifyListeners();
  }

  void pointerMove(int id, Pt sp) {
    if (!_pointers.containsKey(id)) return;
    _pointers[id] = sp;
    final pinch = _pinch;
    if (pinch != null) {
      if (_pointers.length < 2) return;
      final v = _pointers.values.toList(), mid = Pt((v[0].x + v[1].x) / 2, (v[0].y + v[1].y) / 2);
      cam.z = clampD(pinch.z0 * dist(v[0], v[1]) / pinch.d0, 1, 4);
      cam.x = pinch.wm.x - mid.x / cam.z;
      cam.y = pinch.wm.y - mid.y / cam.z;
      _clampCam();
      return notifyListeners(); // atualiza o rótulo de zoom
    }
    final a = action;
    if (a == null) return;
    if (a.type == 'pan') {
      cam.x -= (sp.x - a.last!.x) / cam.z;
      cam.y -= (sp.y - a.last!.y) / cam.z;
      a.last = sp;
      _clampCam();
      return;
    }
    // só a bancada muda; o Flame redesenha a cada quadro
    final p = toWorld(sp);
    mode == Mode.edit ? _editMove(p) : _buildMove(p);
  }

  /// Soltar ou cancelar: termina a ação na última posição conhecida.
  void pointerUp(int id) {
    final last = _pointers.remove(id);
    if (last == null) return;
    if (_pinch != null) {
      if (_pointers.length < 2) {
        _pinch = null;
        _pinchTail = _pointers.isNotEmpty;
      }
      return;
    }
    if (_pinchTail) {
      if (_pointers.isEmpty) _pinchTail = false;
      return;
    }
    final a = action;
    if (a == null) return;
    if (a.type == 'pan') {
      action = null;
      return notifyListeners();
    }
    final p = toWorld(last);
    if (mode == Mode.edit) {
      _editMove(p);
      _editUp();
    } else {
      _buildMove(p);
      _buildUp();
    }
    notifyListeners();
  }
}
