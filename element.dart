import 'bindings.dart';
import 'render_object.dart';
import 'widget.dart';

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

class StatelessElement extends ComponentElement {
  StatelessElement(StatelessWidget widget) : super(widget);

  StatelessWidget get widget => super.widget;

  @override
  Widget build(Element context) => widget.build(context);
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

class MultiChildRenderObjectElement extends RenderObjectElement {
  MultiChildRenderObjectElement(MultiChildRenderObjectWidget widget)
      : super(widget);

  @override
  MultiChildRenderObjectWidget get widget => super.widget;

  @override
  ContainerRenderObjectMixin get renderObject => super.renderObject;

  Iterable<Element> get children => _children;
  List<Element> _children;

  @override
  void mount(Element parent) {
    super.mount(parent);
    _children = List<Element>(widget.children.length);
    for (final widget in widget.children) {
      _children.add(inflateWidget(widget));
    }
  }

  @override
  void insertChildRenderObject(RenderObject child) {
    renderObject.add(child);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    renderObject.remove(child);
  }

  @override
  void visitChildren(void Function(Element) visitor) {
    for (final child in _children) {
      visitor(child);
    }
  }

  @override
  void update(MultiChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    _children = updateChildren(_children, newWidget.children);
  }

  List<Element> updateChildren(
      List<Element> oldElements, List<Widget> newWidgets) {
    int newWidgetsTop = 0;
    int oldElementsTop = 0;
    int newWidgetsBottom = newWidgets.length - 1;
    int oldElementsBottom = oldElements.length - 1;

    final List<Element> newElements = oldElements.length == newWidgets.length
        ? oldElements
        : List<Element>(newWidgets.length);

    // TODO used for slot
    // Element slot;

    // update top of the children list
    while ((oldElementsTop <= oldElementsBottom) &&
        (newWidgetsTop <= newWidgetsBottom)) {
      final oldElement = oldElements[oldElementsTop];
      final newWidget = newWidgets[newWidgetsTop];
      if (!Widget.canUpdate(oldElement.widget, newWidget)) {
        // we can't update so we stop
        break;
      }
      final newElement = updateChild(oldElement, newWidget);
      newElements[newWidgetsTop] = newElement;
      newWidgetsTop += 1;
      oldElementsTop += 1;
    }

    // scan bottom of the children list
    while ((oldElementsTop <= oldElementsBottom) &&
        (newWidgetsTop <= newWidgetsBottom)) {
      final oldElement = oldElements[oldElementsBottom];
      final newWidget = newWidgets[newWidgetsBottom];
      if (!Widget.canUpdate(oldElement.widget, newWidget)) {
        // we can't update so we stop
        break;
      }
      // We should update from top to bottom so side effects from widgets happen in order.
      // So this just defines the boundaries of the middle elements. Updating the bottom of
      // the children list happens later after we go through the middle of the list.
      newWidgetsBottom -= 1;
      oldElementsBottom -= 1;
    }

    // update the old children in the middle of the list.
    // Deactivate the old elements.
    // TODO keys
    while (oldElementsTop <= oldElementsBottom) {
      final oldElement = oldElements[oldElementsTop];
      deactivateChild(oldElement);
      oldElementsTop += 1;
    }

    // at this point oldElementsTop = oldElementsBottom + 1,
    // note we haven't lost the index from where we need to update bottom of the list

    // Inflate widgets of new elements.
    while (newWidgetsTop <= newWidgetsBottom) {
      final newElement = updateChild(null, newWidgets[newWidgetsTop]);
      newElements[newWidgetsTop] = newElement;
      newWidgetsTop += 1;
    }

    // at this point newWidgetsTop = oldWidgetsTop + 1,
    // note we haven't lost the index from where we need to update bottom of the list

    oldElementsBottom = oldElements.length - 1;
    newWidgetsBottom = newWidgets.length - 1;
    // we restored the previous state with bottom pointing to end of list,
    // and top to the point where updating should start at.
    while ((oldElementsTop <= oldElementsBottom) &&
        (newWidgetsTop <= newWidgetsBottom)) {
      final newElement =
          updateChild(oldElements[oldElementsTop], newWidgets[newWidgetsTop]);
      newElements[newWidgetsTop] = newElement;
      newWidgetsTop += 1;
      oldElementsTop += 1;
    }

    return newElements;
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
