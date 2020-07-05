import 'dart:collection';

import 'framework.dart';

void main(List<String> args) {
  runApp(App());
  printTree(WidgetsBinding.instance.rootElement);
  invokeEvent(WidgetsBinding.instance.rootElement);
  WidgetsBinding.instance.addPostFrameCallback(() {
    printTree(WidgetsBinding.instance.rootElement);
  });
}

void invokeEvent(Element element) {
  if (element is StatefulElement && element.widget is AppStatefulWidget) {
    (element.state as AppStatefulState).onEvent();
    return;
  }
  element.visitChildren(invokeEvent);
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
        '${'  ' * depth}${element.runtimeType}: data => ${element.widget.data}');
  } else if (element is LeafRenderObjectElement) {
    print(
        '${'  ' * depth}${element.runtimeType}: size => ${(element.renderObject as LeafBoxRenderObject).size}');
  } else if (element is SingleChildRenderObjectElement) {
    print(
        '${'  ' * depth}${element.runtimeType}: size => ${(element.renderObject as BoxWithChildRenderObject).size}');
  } else {
    print('${'  ' * depth}${element.runtimeType}');
  }
}

class App extends StatelessWidget {
  @override
  Widget build(Element context) {
    return AppStatefulWidget(false);
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

  @override
  void initState() {
    super.initState();
    useParent = widget.initialState;
  }

  @override
  Widget build(Element context) {
    if (useParent) {
      return BoxWithChildWidget(
        LeafBoxWidget(),
      );
    } else {
      return LeafBoxWidget();
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
  @override
  RenderObject createRenderObject(Element context) => LeafBoxRenderObject();

  @override
  void updateRenderObject(Element context, RenderObject renderObject) {}

  @override
  void didUnmountRenderObject(RenderObject renderObject) {}
}

class LeafBoxRenderObject extends RenderObject {
  @override
  bool get sizedByParent => true;

  @override
  BoxConstraints get constraints => super.constraints;

  Size get size => _size;
  Size _size;

  @override
  void performLayout() {}

  @override
  void performResize() {
    _size = Size(constraints.maxWidth / 2, constraints.maxHeight / 2);
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
