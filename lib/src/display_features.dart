import 'dart:ui';

/// A complete snapshot in Flutter-view logical coordinates.
class DisplayFeaturesSnapshot {
  DisplayFeaturesSnapshot(this.size, this.features);
  final Size size;
  final List<DisplayFeature> features;

  static double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static DisplayFeaturesSnapshot? decode(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    final width = _number(value['width']);
    final height = _number(value['height']);
    final records = value['features'];
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        records is! List<Object?>) {
      return null;
    }
    final features = <DisplayFeature>[];
    for (final record in records) {
      if (record is! Map<Object?, Object?>) return null;
      final left = _number(record['left']);
      final top = _number(record['top']);
      final right = _number(record['right']);
      final bottom = _number(record['bottom']);
      if (left == null ||
          top == null ||
          right == null ||
          bottom == null ||
          left < 0 ||
          top < 0 ||
          right > width ||
          bottom > height ||
          right < left ||
          bottom < top ||
          (left == right && top == bottom)) {
        return null;
      }
      features.add(
        DisplayFeature(
          bounds: Rect.fromLTRB(left, top, right, bottom),
          type: DisplayFeatureType.fold,
          state: switch (record['state']) {
            'halfOpened' => DisplayFeatureState.postureHalfOpened,
            'flat' => DisplayFeatureState.postureFlat,
            _ => DisplayFeatureState.unknown,
          },
        ),
      );
    }
    return DisplayFeaturesSnapshot(Size(width, height), features);
  }

  bool matches(Size viewport) =>
      (size.width - viewport.width).abs() <= 0.01 &&
      (size.height - viewport.height).abs() <= 0.01;
}
