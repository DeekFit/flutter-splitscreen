/// Copyright (c) Microsoft Corporation.
/// Licensed under the MIT License.

import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Extension method that helps with working with the hinge specifically.
extension MediaQueryHinge on MediaQueryData {
  /// The first fold; [hinge] remains restricted to physical hinges.
  DisplayFeature? get fold {
    for (final feature in displayFeatures) {
      if (feature.type == DisplayFeatureType.fold) return feature;
    }
    return null;
  }

  /// The first physical hinge. Continuous-screen folds, including native Duo
  /// divisions, are available through [fold] or [displayFeatures] instead.
  DisplayFeature? get hinge {
    for (final DisplayFeature e in displayFeatures) {
      if (e.type == DisplayFeatureType.hinge) {
        return e;
      }
    }
    return null;
  }
}
