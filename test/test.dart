import 'dart:collection';
import 'dart:math';

import 'package:flitter/framework.dart';

void main(List<String> args) {
  runApp(App());
  printTree(WidgetsBinding.instance.rootElement);
  print('');
  invokeEvent(WidgetsBinding.instance.rootElement);
  WidgetsBinding.instance.addPostFrameCallback(() {
    printTree(WidgetsBinding.instance.rootElement);
    print('');
    invokeEvent2(WidgetsBinding.instance.rootElement);
    WidgetsBinding.instance.addPostFrameCallback(() {
      printTree(WidgetsBinding.instance.rootElement);
      print('');
    });
  });
}

void invokeEvent(Element element) {
  if (element is StatefulElement && element.widget is AppStatefulWidget) {
    (element.state as AppStatefulState).onEvent();
    print('invoked Event');
    return;
  }
  element.visitChildren(invokeEvent);
}

void invokeEvent2(Element element) {
  if (element is StatefulElement && element.widget is WrapperStatefulWidget) {
    (element.state as WrapperStatefulState).onEvent();
    print('invoked Event 2');
    return;
  }
  element.visitChildren(invokeEvent2);
}

void printTree(Element child) {
  int depth = 0;
  int elementsInThisDepth = 1;
  int elementsInNextDepth = 0;
  Queue<Element> stack = Queue.from([child]);

  while (stack.isNotEmpty) {
    final element = stack.removeFirst();
    element.visitChildren((child) {
      elementsInNextDepth += 1;
      stack.addLast(child);
    });
    _printElement(element, depth);
    elementsInThisDepth -= 1;
    if (elementsInThisDepth == 0) {
      depth += 1;
      elementsInThisDepth = elementsInNextDepth;
      elementsInNextDepth = 0;
    }
  }
}

void _printElement(Element element, int depth) {
  if (element is LeafElement) {
    print(
        '${'  ' * depth}${element.hashCode}#${element.widget.runtimeType}: data => ${element.widget.data}');
  } else if (element is LeafRenderObjectElement) {
    print(
        '${'  ' * depth}${element.hashCode}#${element.widget.runtimeType}: size => ${(element.renderObject as LeafBoxRenderObject).size}');
  } else if (element is SingleChildRenderObjectElement) {
    print(
        '${'  ' * depth}${element.hashCode}#${element.widget.runtimeType}: size => ${(element.renderObject as BoxWithChildRenderObject).size}');
  } else {
    print('${'  ' * depth}${element.hashCode}#${element.widget.runtimeType}');
  }
}

class App extends StatelessWidget {
  @override
  Widget build(Element context) {
    return WrapperStatefulWidget();
  }
}

class WrapperStatefulWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => WrapperStatefulState();
}

class WrapperStatefulState extends State<WrapperStatefulWidget> {
  bool state = false;

  @override
  Widget build(Element context) {
    return AppStatefulWidget(state);
  }

  void onEvent() {
    setState(() {
      state = true;
    });
  }
}

class AppStatefulWidget extends StatefulWidget {
  final bool initialState;

  AppStatefulWidget(this.initialState);

  @override
  State<StatefulWidget> createState() => AppStatefulState();
}

class AppStatefulState extends State<AppStatefulWidget> {
  bool useParent;
  bool changeSize;

  @override
  void initState() {
    super.initState();
    useParent = widget.initialState;
    changeSize = widget.initialState;
  }

  @override
  void didUpdateWidget(AppStatefulWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('didUpdateWidget');
    changeSize = widget.initialState;
  }

  @override
  Widget build(Element context) {
    if (useParent) {
      return BoxWithChildWidget(
        changeSize ? LeafBoxWidget(480.0, 360.0) : LeafBoxWidget(360.0, 480.0),
      );
    } else {
      return LeafBoxWidget(320.0, 240.0);
    }
  }

  void onEvent() {
    setState(() {
      useParent = true;
    });
  }
}

class LeafElementWidget<T> extends Widget {
  final T data;

  LeafElementWidget(this.data);

  @override
  Element createElement() => LeafElement(this);
}

class LeafElement extends Element {
  LeafElement(Widget widget) : super(widget);

  @override
  LeafElementWidget get widget => super.widget;

  @override
  void performRebuild() {
    dirty = false;
  }

  @override
  void visitChildren(void Function(Element) visitor) {
    return;
  }

  @override
  void update(LeafElementWidget newWidget) {
    final oldWidget = widget;
    super.update(newWidget);
    if (oldWidget.data != widget.data) {
      print(
          "widget with data=${oldWidget.data} has been updated to data=${widget.data}");
    }
  }
}

class LeafBoxWidget extends LeafRenderObjectWidget {
  final double width, height;

  LeafBoxWidget(this.width, this.height);

  @override
  RenderObject createRenderObject(Element context) => LeafBoxRenderObject(_additionalConstraints);

  @override
  void updateRenderObject(Element context, LeafBoxRenderObject renderObject) {
    renderObject
      ..additionalConstraints = _additionalConstraints;
  }

  BoxConstraints get _additionalConstraints {
    return BoxConstraints.tight(Size(width, height));
  }

  @override
  void didUnmountRenderObject(RenderObject renderObject) {}
}

class LeafBoxRenderObject extends RenderObject {
  LeafBoxRenderObject(this._additionalConstraints);

  @override
  bool get sizedByParent => false;

  @override
  BoxConstraints get constraints => super.constraints;

  Size get size => _size;
  Size _size;

  BoxConstraints _additionalConstraints;
  BoxConstraints get additionalConstraints => _additionalConstraints;
  void set additionalConstraints(BoxConstraints val) {
    if (val != _additionalConstraints) {
      _additionalConstraints = val;
      markNeedsLayout();
    }
  }

  @override
  void performResize() { }

  @override
  void performLayout() {
    final computed = BoxConstraints(
      maxHeight: min(constraints.maxHeight, additionalConstraints.maxHeight),
      minHeight: max(constraints.minHeight, additionalConstraints.minHeight),
      maxWidth: min(constraints.maxWidth, additionalConstraints.maxWidth),
      minWidth: max(constraints.minWidth, additionalConstraints.minWidth),
    );
    _size = Size(computed.maxWidth, computed.maxHeight);
  }

  @override
  void visitChildren(void Function(RenderObject child) visitor) {
    return;
  }
}

class BoxWithChildWidget extends SingleChildRenderObjectWidget {
  BoxWithChildWidget(Widget child) : super(child);

  @override
  BoxWithChildRenderObject createRenderObject(Element context) =>
      BoxWithChildRenderObject();

  @override
  void updateRenderObject(
      Element context, RenderObjectWithChild renderObject) {}

  @override
  void didUnmountRenderObject(RenderObject renderObject) {}
}

class BoxWithChildRenderObject extends RenderObject with RenderObjectWithChild {
  @override
  RenderObject get child => super.child;

  @override
  BoxConstraints get constraints => super.constraints;

  Size get size => _size;
  Size _size;

  @override
  void performLayout() {
    child.layout(constraints, parentUsesSize: true);
    Size size;
    if (child is BoxWithChildRenderObject) {
      size = (child as BoxWithChildRenderObject).size;
    } else {
      size = (child as LeafBoxRenderObject).size;
    }
    _size = Size(3 / 2 * size.width, 3 / 2 * size.height);
  }

  @override
  void performResize() {}
}
