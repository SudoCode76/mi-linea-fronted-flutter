import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double sheetRadius;

  const AppShapes({
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.sheetRadius,
  });

  factory AppShapes.defaults() => const AppShapes(
    radiusXs: 4,
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 16,
    radiusXl: 24,
    sheetRadius: 28,
  );

  @override
  AppShapes copyWith({
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? sheetRadius,
  }) {
    return AppShapes(
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      sheetRadius: sheetRadius ?? this.sheetRadius,
    );
  }

  @override
  AppShapes lerp(ThemeExtension<AppShapes>? other, double t) {
    if (other is! AppShapes) return this;
    return AppShapes(
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
    );
  }
}

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const AppSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  factory AppSpacing.defaults() => const AppSpacing(
    xxs: 2,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 20,
    xl: 32,
  );

  @override
  AppSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return AppSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  ThemeExtension<AppSpacing> lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
    );
  }
}

@immutable
class AppDurations extends ThemeExtension<AppDurations> {
  final Duration fast;
  final Duration normal;
  final Duration slow;

  const AppDurations({
    required this.fast,
    required this.normal,
    required this.slow,
  });

  factory AppDurations.defaults() => const AppDurations(
    fast: Duration(milliseconds: 120),
    normal: Duration(milliseconds: 260),
    slow: Duration(milliseconds: 500),
  );

  @override
  AppDurations copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
  }) {
    return AppDurations(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
    );
  }

  @override
  ThemeExtension<AppDurations> lerp(
      ThemeExtension<AppDurations>? other, double t) {
    if (other is! AppDurations) return this;
    return AppDurations(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
    );
  }
}

@immutable
class AppGlass extends ThemeExtension<AppGlass> {
  final Color surface;
  final Color border;
  final double blurSigma;
  final double opacity;

  const AppGlass({
    required this.surface,
    required this.border,
    required this.blurSigma,
    required this.opacity,
  });

  factory AppGlass.light() => AppGlass(
    surface: Colors.white,
    border: Colors.white.withValues(alpha: .18),
    blurSigma: 12,
    opacity: .92,
  );

  factory AppGlass.dark() => AppGlass(
    surface: const Color(0xFF1F2228),
    border: Colors.white.withValues(alpha: .08),
    blurSigma: 16,
    opacity: .92, // un poco más clara
  );

  @override
  AppGlass copyWith({
    Color? surface,
    Color? border,
    double? blurSigma,
    double? opacity,
  }) {
    return AppGlass(
      surface: surface ?? this.surface,
      border: border ?? this.border,
      blurSigma: blurSigma ?? this.blurSigma,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  ThemeExtension<AppGlass> lerp(
      ThemeExtension<AppGlass>? other, double t) {
    if (other is! AppGlass) return this;
    return AppGlass(
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      opacity: lerpDouble(opacity, other.opacity, t)!,
    );
  }
}