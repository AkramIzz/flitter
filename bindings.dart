import 'render_object.dart';
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

  PipelineOwner get pipelineOwner => _pipelineOwner;
  PipelineOwner _pipelineOwner;

  RenderView renderView;

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
    _pipelineOwner = PipelineOwner();
    initRenderView();
  }

  void initRenderView() {
    renderView = RenderView(configuration: createViewConfiguration());
    // in flutter the next line is done in renderView property setter
    renderView.attach(pipelineOwner);
    renderView.prepareInitialFrame();
  }

  ViewConfiguration createViewConfiguration() {
    return ViewConfiguration(
      size: window.physicalSize,
      devicePixelRatio: window.devicePixelRation,
    );
  }

  void attachRootWidget(Widget app) {
    _rootElement = RootElementWidget(renderView: renderView, child: app)
        .attach(buildOwner);
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
    pipelineOwner.flushLayout();
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

class RootElementWidget extends RenderObjectWidget {
  RootElementWidget({this.renderView, this.child});

  final Widget child;
  final RenderView renderView;

  RootElement attach(BuildOwner owner) {
    final element = createElement();
    element.assignOwner(owner);
    owner.buildScope(null, () {
      element.mount(null);
    });
    return element;
  }

  @override
  RootElement createElement() => RootElement(this);

  @override
  RenderObject createRenderObject(Element context) => renderView;

  @override
  void didUnmountRenderObject(RenderObject renderObject) {}

  @override
  void updateRenderObject(Element context, RenderObject renderObject) {}
}

class RootElement extends RenderObjectElement {
  RootElement(RootElementWidget widget) : super(widget);

  RootElementWidget get widget => super.widget;

  RenderView get renderObject => super.renderObject;

  Element _child;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _rebuild();
  }

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    _rebuild();
  }

  void _rebuild() {
    _child = updateChild(_child, widget.child);
  }

  @override
  void performRebuild() {
    super.performRebuild();
  }

  @override
  void visitChildren(void Function(Element) visitor) {
    visitor(_child);
  }

  @override
  void insertChildRenderObject(RenderObject child) {
    renderObject.child = child;
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    renderObject.child = null;
  }
}
