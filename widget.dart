import 'element.dart';
import 'render_object.dart';

abstract class Widget {
  Element createElement();

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return oldWidget.runtimeType == newWidget.runtimeType;
  }
}

abstract class StatelessWidget extends Widget {
  @override
  Element createElement() => StatelessElement(this);

  Widget build(Element context);
}

abstract class StatefulWidget extends Widget {
  @override
  Element createElement() => StatefulElement(this);

  State<StatefulWidget> createState();
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

abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  LeafRenderObjectElement createElement() => LeafRenderObjectElement(this);
}

abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  SingleChildRenderObjectWidget(this.child);

  final Widget child;

  @override
  RenderObjectElement createElement() => SingleChildRenderObjectElement(this);
}

abstract class MultiChildRenderObjectWidget extends RenderObjectWidget {
  MultiChildRenderObjectWidget(this.children);

  final List<Widget> children;

  @override
  RenderObjectElement createElement() => MultiChildRenderObjectElement(this);
}
