class Size {
  const Size(this.width, this.height);

  final double width;
  final double height;

  static const Size zero = Size(0.0, 0.0);

  @override
  String toString() {
    return '$runtimeType(width: $width, height: $height)';
  }
}

abstract class Constraints {
  const Constraints();

  bool get isTight;
}

class BoxConstraints extends Constraints {
  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });

  final double minWidth, maxWidth, minHeight, maxHeight;

  BoxConstraints.tight(Size size)
      : minWidth = size.width,
        maxWidth = size.width,
        minHeight = size.height,
        maxHeight = size.height;

  @override
  bool get isTight => minWidth >= maxWidth && minHeight >= maxHeight;
}
