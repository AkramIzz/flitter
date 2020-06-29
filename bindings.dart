import 'ui.dart' as ui;
import 'trees.dart';

void runApp(Widget app) {
  WidgetsBinding.ensureInitialized()
    ..attachRootWidget(app)
    ..warmupFrame();
}

class WidgetsBinding {
  WidgetsBinding._();

  static WidgetsBinding get instance => _instance;
  static WidgetsBinding _instance;

  ui.Window get window => ui.window;

  bool get hasScheduledFrame => _hasScheduledFrame;
  bool _hasScheduledFrame = false;

  BuildOwner get buildOwner => _buildOwner;
  BuildOwner _buildOwner;

  Element get rootElement => _rootElement;
  Element _rootElement;

  List<void Function()> _postFrameCallbacks = <void Function()>[];

  static WidgetsBinding ensureInitialized() {
    if (_instance == null) {
      _instance = WidgetsBinding._();
      instance.initInstance();
    }
    return instance;
  }

  void initInstance() {
    _buildOwner = BuildOwner();
  }

  void attachRootWidget(Widget app) {
    _rootElement = RootElementWidget(child: app).attach(buildOwner);
  }

  void warmupFrame() {
    handleDrawFrame();
  }

  void scheduleFrame() {
    if (hasScheduledFrame) return;

    ensureFrameCallbacksRegistered();
    window.scheduleFrame();
    _hasScheduledFrame = true;
  }

  void ensureFrameCallbacksRegistered() {
    window.onDrawFrame = handleDrawFrame;
  }

  void handleDrawFrame() {
    drawFrame();

    final postFrameCallbacks = List<void Function()>.from(_postFrameCallbacks);
    _postFrameCallbacks.clear();
    postFrameCallbacks.forEach((callback) {
      callback();
    });
  }

  void drawFrame() {
    _hasScheduledFrame = false;
    buildOwner.buildScope(_rootElement);
    buildOwner.finalizeTree();
  }

  void addPostFrameCallback(void Function() callback) {
    _postFrameCallbacks.add(callback);
  }
}

class BuildOwner {
  List<Element> _dirtyElements = <Element>[];

  bool _scheduledFlushDirtyElements = false;

  Set<Element> inactiveElements = <Element>{};

  void scheduleBuildFor(Element element) {
    if (!_scheduledFlushDirtyElements) {
      _scheduledFlushDirtyElements = true;
      // flutter calls onBuildScheduled which eventually call scheduleFrame
      WidgetsBinding.instance.scheduleFrame();
    }
    _dirtyElements.add(element);
  }

  void buildScope(Element context, [void Function() callback]) {
    if (callback != null) {
      callback();
    }

    int index = 0;
    _dirtyElements.sort(Element.sortByDepthAscending);
    while (index < _dirtyElements.length) {
      _dirtyElements[index].rebuild();
      index += 1;
    }
    _dirtyElements.clear();
    _scheduledFlushDirtyElements = false;
  }

  void finalizeTree() {
    inactiveElements.toList()
      ..sort(Element.sortByDepthAscending)
      ..reversed.forEach(_unmountTreeElement);
  }

  void _unmountTreeElement(Element e) {
    e.visitChildren((c) => _unmountTreeElement(c));
    e.unmount();
  }
}
