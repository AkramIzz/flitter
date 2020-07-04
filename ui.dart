import 'geometry.dart';

class Window {
  Window._() {}

  Size get physicalSize => _physicalSize;
  Size _physicalSize = const Size(640.0, 480.0);

  double get devicePixelRation => _devicePixelRation;
  double _devicePixelRation = 1.0;

  scheduleFrame() {
    Future.delayed(Duration(seconds: 1), () => _onDrawFrame(0));
  }

  _onDrawFrame(num timestamp) {
    onDrawFrame();
  }

  void Function() onDrawFrame;
}

final window = Window._();
