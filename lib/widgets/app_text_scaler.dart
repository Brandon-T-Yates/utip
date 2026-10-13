import 'package:flutter/painting.dart';

/// Applies uTip's optional larger text on top of system accessibility scaling,
/// including the system's nonlinear scaling at different font sizes.
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.systemScaler, {this.multiplier = 1.3});

  final TextScaler systemScaler;
  final double multiplier;

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * multiplier;

  // Required by TextScaler for callers that still use the legacy estimate.
  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.systemScaler == systemScaler &&
      other.multiplier == multiplier;

  @override
  int get hashCode => Object.hash(systemScaler, multiplier);
}
