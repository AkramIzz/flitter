import 'bindings.dart';

abstract class Widget {
  Element createElement();

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return oldWidget.runtimeType == newWidget.runtimeType;
  }
}

abstract class Element {
  Element(this._widget);

  Widget get widget => this._widget;
  Widget _widget;

  bool dirty = true;

  bool get active => _active;
  bool _active = false;

  int get depth => _depth;
  int _depth;

  Element get parent => _parent;
  Element _parent;

  BuildOwner get owner => _owner;
  BuildOwner _owner;

  void mount(Element parent) {
    _parent = parent;
    _depth = parent != null ? parent.depth + 1 : 1;
    if (parent != null) {
      _owner = parent.owner;
    }
    _active = true;
  }

  void activate() {
    _active = true;
    if (dirty) owner.scheduleBuildFor(this);
  }

  void deactivate() {
    _active = false;
  }

  void unmount() {}

  void assignOwner(BuildOwner owner) {
    _owner = owner;
  }

  void rebuild() {
    if (!_active || !dirty) {
      return;
    }
    performRebuild();
  }

  void performRebuild();

  Element updateChild(Element child, Widget newWidget) {
    if (newWidget == null && child == null) {
      return null;
    }

    if (newWidget == null && child != null) {
      deactivateChild(child);
      return null;
    }

    if (newWidget != null && child != null) {
      if (child.widget == newWidget) {
        return child;
      }
      if (Widget.canUpdate(child.widget, newWidget)) {
        child.update(newWidget);
        return child;
      }
      deactivateChild(child);
    }

    // if (newWidget != null && child == null)
    return inflateWidget(newWidget);
  }

  void deactivateChild(Element child) {
    child._parent = null;
    owner.inactiveElements.add(child);
    // in flutter adding to _inactiveElements calls deactivate
    // recursively on child and its descendents
    child.deactivateRecursively();
  }

  void deactivateRecursively() {
    deactivate();
    visitChildren((child) => child.deactivateRecursively());
  }

  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }

  Element inflateWidget(Widget widget) {
    Element newChild = widget.createElement();
    newChild.mount(this);
    return newChild;
  }

  void markNeedsBuild() {
    if (dirty) return;
    dirty = true;
    owner.scheduleBuildFor(this);
  }

  void visitChildren(void Function(Element) visitor);

  static int sortByDepthAscending(Element a, Element b) {
    if (a.depth < b.depth) return -1;
    if (b.depth < a.depth) return 1;
    if (b.dirty && !a.dirty) return -1;
    if (a.dirty && !b.dirty) return 1;
    return 0;
  }
}

class RootElementWidget extends Widget {
  RootElementWidget({this.child});

  final Widget child;

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
}

class RootElement extends Element {
  RootElement(RootElementWidget widget) : super(widget);

  RootElementWidget get widget => super.widget;

  Element _child;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _rebuild();
  }

  void _rebuild() {
    _child = updateChild(_child, widget.child);
  }

  @override
  void performRebuild() {
    dirty = false;
  }

  @override
  void visitChildren(void Function(Element) visitor) {
    visitor(_child);
  }
}

abstract class ComponentElement extends Element {
  ComponentElement(Widget widget) : super(widget);

  Element _child;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _firstBuild();
  }

  void _firstBuild() {
    rebuild();
  }

  @override
  void performRebuild() {
    final built = build(this);
    dirty = false;
    _child = updateChild(_child, built);
  }

  Widget build(Element context);

  @override
  void visitChildren(void Function(Element) visitor) {
    if (_child != null) visitor(_child);
  }
}

abstract class StatelessWidget extends Widget {
  @override
  Element createElement() => StatelessElement(this);

  Widget build(Element context);
}

class StatelessElement extends ComponentElement {
  StatelessElement(StatelessWidget widget) : super(widget);

  StatelessWidget get widget => super.widget;

  @override
  Widget build(Element context) => widget.build(context);
}

abstract class StatefulWidget extends Widget {
  @override
  Element createElement() => StatefulElement(this);

  State<StatefulWidget> createState();
}

class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget widget)
      : _state = widget.createState(),
        super(widget) {
    _state.widget = widget;
    _state.element = this;
  }

  State<StatefulWidget> get state => _state;
  State<StatefulWidget> _state;

  @override
  Widget build(Element context) => _state.build(context);

  @override
  void _firstBuild() {
    _state.initState();
    super._firstBuild();
  }

  @override
  void unmount() {
    super.unmount();
    _state.dispose();
    _state.element = null;
    _state.widget = null;
    _state = null;
  }

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    final oldWidget = _state.widget;
    _state.widget = widget;
    _state.didUpdateWidget(oldWidget);
  }
}

abstract class State<T extends StatefulWidget> {
  T widget;
  StatefulElement element;

  void setState(void Function() fn) {
    fn();
    element.markNeedsBuild();
  }

  void initState() {}

  void didUpdateWidget(T oldWidget) {}

  Widget build(Element context);

  void dispose() {}
}
