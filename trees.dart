import 'bindings.dart';
import 'render_object.dart';

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
    child.detachRenderObject();
    owner.inactiveElements.add(child);
    // in flutter adding to _inactiveElements calls deactivate
    // recursively on child and its descendents
    child.deactivateRecursively();
  }

  void detachRenderObject() {
    visitChildren((child) {
      child.detachRenderObject();
    });
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

abstract class RenderObjectWidget extends Widget {
  @override
  RenderObjectElement createElement();

  RenderObject createRenderObject(Element context);

  void updateRenderObject(Element context, covariant RenderObject renderObject);

  void didUnmountRenderObject(covariant RenderObject renderObject);
}

abstract class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget widget) : super(widget);

  @override
  RenderObjectWidget get widget => super.widget;

  RenderObject get renderObject => _renderObject;
  RenderObject _renderObject;

  RenderObjectElement _ancestorRenderObjectElement;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _renderObject = widget.createRenderObject(this);
    attachRenderObject();
    dirty = false;
  }

  void attachRenderObject() {
    _ancestorRenderObjectElement = _findAncestorRenderObjectElement();
    _ancestorRenderObjectElement?.insertChildRenderObject(renderObject);
  }

  RenderObjectElement _findAncestorRenderObjectElement() {
    var ancestor = parent;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      ancestor = ancestor.parent;
    }
    return ancestor;
  }

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    widget.updateRenderObject(this, renderObject);
    dirty = false;
  }

  @override
  void performRebuild() {
    widget.updateRenderObject(this, renderObject);
    dirty = false;
  }

  @override
  void detachRenderObject() {
    if (_ancestorRenderObjectElement != null) {
      _ancestorRenderObjectElement.removeChildRenderObject(renderObject);
      _ancestorRenderObjectElement = null;
    }
  }

  @override
  void unmount() {
    super.unmount();
    // renderObject should be detached here => owner == null.
    // in deactivateChild the detachRenderObject is called. This sets the ancestor renderObject's child (this)
    // to null using a property setter which detaches the renderObject (owner = null)
    widget.didUnmountRenderObject(renderObject);
  }

  // add RenderObject to renderObjects tree. Called by attachRenderObject <- mount
  void insertChildRenderObject(RenderObject child);

  // remove RenderObject from renderObjects tree. Called by detachRenderObject <- deactivateChild <- updateChild
  void removeChildRenderObject(RenderObject child);
}

abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  LeafRenderObjectElement createElement() => LeafRenderObjectElement(this);
}

class LeafRenderObjectElement extends RenderObjectElement {
  LeafRenderObjectElement(LeafRenderObjectWidget widget) : super(widget);

  @override
  void visitChildren(void Function(Element) visitor) {
    return;
  }

  @override
  void insertChildRenderObject(RenderObject child) {
    assert(false);
  }

  @override
  void removeChildRenderObject(RenderObject renderObject) {
    assert(false);
  }
}

abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  SingleChildRenderObjectWidget(this.child);

  final Widget child;

  @override
  RenderObjectElement createElement() => SingleChildRenderObjectElement(this);
}

class SingleChildRenderObjectElement extends RenderObjectElement {
  SingleChildRenderObjectElement(SingleChildRenderObjectWidget widget)
      : super(widget);

  Element _child;

  SingleChildRenderObjectWidget get widget => super.widget;

  @override
  RenderObjectWithChild get renderObject => super.renderObject;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _child = updateChild(_child, widget.child);
  }

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    _child = updateChild(_child, widget.child);
  }

  @override
  void insertChildRenderObject(RenderObject child) {
    renderObject.child = child;
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    renderObject.child = null;
  }

  @override
  void visitChildren(void Function(Element) visitor) {
    if (_child != null) {
      visitor(_child);
    }
  }
}

mixin RenderObjectWithChild on RenderObject {
  RenderObject get child => _child;
  void set child(RenderObject value) {
    if (value == null) dropChild(child);
    _child = value;
    if (value != null) adoptChild(child);
  }

  RenderObject _child;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    child?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    child?.detach();
  }

  @override
  void visitChildren(void Function(RenderObject child) visitor) {
    if (child != null) {
      visitor(child);
    }
  }
}
