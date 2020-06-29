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
    if (element is LeafElement) {
      print(
          '${'  ' * depth}${element.runtimeType}: data => ${element.widget.data}');
    } else {
      print('${'  ' * depth}${element.runtimeType}');
    }
    elementsInThisDepth -= 1;
    if (elementsInThisDepth == 0) {
      depth += 1;
      elementsInThisDepth = elementsInNextDepth;
      elementsInNextDepth = 0;
    }
  }
}

class App extends StatelessWidget {
  @override
  Widget build(Element context) {
    return AppStatefulWidget("initial data");
  }
}

class AppStatefulWidget extends StatefulWidget {
  final String initialData;

  AppStatefulWidget(this.initialData);

  @override
  State<StatefulWidget> createState() => AppStatefulState();
}

class AppStatefulState extends State<AppStatefulWidget> {
  String data;

  @override
  void initState() {
    super.initState();
    data = widget.initialData;
  }

  @override
  Widget build(Element context) {
    return LeafElementWidget(data);
  }

  void onEvent() {
    setState(() {
      data = "new data";
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
