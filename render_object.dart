import 'framework.dart';
import 'geometry.dart';

abstract class RenderObject {
  int get depth => _depth;
  int _depth = 0;

  PipelineOwner get owner => _owner;
  PipelineOwner _owner;

  RenderObject get parent => _parent;
  RenderObject _parent;

  bool get attached => owner != null;

  bool _needsLayout = true;

  Constraints get constraints => _constraints;
  Constraints _constraints;

  RenderObject _relayoutBoundary;

  bool get sizedByParent => false;

  void attach(PipelineOwner owner) {
    _owner = owner;

    if (_needsLayout && _relayoutBoundary != null) {
      _needsLayout = false;
      markNeedsLayout();
    }
  }

  void detach() {
    _owner = null;
  }

  void redepthChild(RenderObject child) {
    if (child.depth <= depth) {
      child._depth = depth + 1;
      child.visitChildren((childChild) {
        child.redepthChild(childChild);
      });
    }
  }

  void visitChildren(void Function(RenderObject child) visitor);

  void adoptChild(RenderObject child) {
    markNeedsLayout();
    child._parent = this;
    if (attached) child.attach(owner);
    redepthChild(child);
  }

  void dropChild(RenderObject child) {
    child._cleanRelayoutBoundary();
    child._parent = null;
    if (attached) child.detach();
    markNeedsLayout();
  }

  void markNeedsLayout() {
    if (_needsLayout) return;
    if (_relayoutBoundary != this) {
      markParentNeedsLayout();
      return;
    }
    _needsLayout = true;
    owner._nodesNeedingLayout.add(this);
    owner.requestVisualUpdate();
  }

  void markParentNeedsLayout() {
    _needsLayout = true;
    // marked as needing layout but not added to owner._nodesNeedingLayout
    // since parent's layout will layout it's child too.
    parent.markNeedsLayout();
  }

  void _cleanRelayoutBoundary() {
    if (_relayoutBoundary != this) {
      _relayoutBoundary = null;
      _needsLayout = true;
      visitChildren((RenderObject child) {
        child._cleanRelayoutBoundary();
      });
    }
  }

  void _layoutWithoutResize() {
    performLayout();
    _needsLayout = false;
  }

  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    RenderObject relayoutBoundary;
    if (!parentUsesSize || sizedByParent || constraints.isTight) {
      relayoutBoundary = this;
    } else {
      relayoutBoundary = parent._relayoutBoundary;
    }
    if (!_needsLayout &&
        constraints == _constraints &&
        relayoutBoundary == _relayoutBoundary) {
      return;
    }
    _constraints = constraints;
    if (_relayoutBoundary != null && relayoutBoundary != _relayoutBoundary) {
      visitChildren((child) {
        child._cleanRelayoutBoundary();
      });
    }
    _relayoutBoundary = relayoutBoundary;
    if (sizedByParent) {
      performResize();
    }
    performLayout();
    _needsLayout = false;
  }

  void performLayout();

  void performResize();

  static int sortByDepthAscending(RenderObject a, RenderObject b) {
    return a.depth - b.depth;
  }
}

class ViewConfiguration {
  const ViewConfiguration({
    this.size = Size.zero,
    this.devicePixelRatio = 1.0,
  });

  final Size size;
  final double devicePixelRatio;
}

class RenderView extends RenderObject {
  RenderView({
    RenderObject child,
    ViewConfiguration configuration,
  }) : _configuration = configuration {
    this.child = child;
  }

  ViewConfiguration get configuration => _configuration;
  ViewConfiguration _configuration;

  RenderObject get child => _child;
  set child(RenderObject value) {
    if (_child != null) dropChild(child);
    _child = value;
    if (value != null) adoptChild(child);
  }

  RenderObject _child;

  Size get size => _size;
  Size _size = Size.zero;

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

  void prepareInitialFrame() {
    scheduleInitialLayout();
  }

  void scheduleInitialLayout() {
    _relayoutBoundary = this;
    owner._nodesNeedingLayout.add(this);
  }

  @override
  void performLayout() {
    _size = configuration.size;
    child?.layout(BoxConstraints.tight(_size));
  }

  @override
  void performResize() {
    assert(false);
  }
}

class PipelineOwner {
  // relayout boundary renderObjects
  List<RenderObject> _nodesNeedingLayout = <RenderObject>[];

  void requestVisualUpdate() {
    WidgetsBinding.instance.scheduleFrame();
  }

  void flushLayout() {
    while (_nodesNeedingLayout.isNotEmpty) {
      final dirtyNodes = _nodesNeedingLayout
        ..sort(RenderObject.sortByDepthAscending);
      _nodesNeedingLayout = <RenderObject>[];
      for (final node in dirtyNodes) {
        if (node._needsLayout && node.owner == this)
          node._layoutWithoutResize();
      }
    }
  }
}
