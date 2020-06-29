class Window {
  Window._() {}

  scheduleFrame() {
    Future.delayed(Duration(seconds: 1), () => _onDrawFrame(0));
  }

  _onDrawFrame(num timestamp) {
    onDrawFrame();
  }

  void Function() onDrawFrame;
}

final window = Window._();
