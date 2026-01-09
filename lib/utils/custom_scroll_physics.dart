import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom scroll physics that allows minimal overscroll
/// Provides a small amount of overscroll for better UX while preventing excessive scrolling
class MinimalOverscrollPhysics extends ScrollPhysics {
  const MinimalOverscrollPhysics({super.parent});

  @override
  MinimalOverscrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MinimalOverscrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Allow minimal overscroll (20 pixels max)
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      // Overscrolling at the top
      return value - position.pixels;
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      // Overscrolling at the bottom
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      // Hit the top edge
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent && position.maxScrollExtent > position.pixels) {
      // Hit the bottom edge
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Use clamping physics for ballistic simulation but with minimal overscroll tolerance
    final tolerance = this.tolerance;
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;
}

/// Enhanced scroll physics with natural feel and better overscroll handling
/// Similar to iOS/Material but with more controlled overscroll
class EnhancedScrollPhysics extends ScrollPhysics {
  /// Maximum overscroll distance in pixels
  final double maxOverscroll;
  
  /// Overscroll resistance factor (0.0 = no resistance, 1.0 = full resistance)
  final double overscrollResistance;

  const EnhancedScrollPhysics({
    this.maxOverscroll = 80.0,
    this.overscrollResistance = 0.6,
    super.parent,
  });

  @override
  EnhancedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EnhancedScrollPhysics(
      maxOverscroll: maxOverscroll,
      overscrollResistance: overscrollResistance,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      // Overscrolling at the top
      final overscroll = position.minScrollExtent - value;
      if (overscroll > maxOverscroll) {
        return value - position.pixels + (overscroll - maxOverscroll) * overscrollResistance;
      }
      return value - position.pixels;
    }
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      // Overscrolling at the bottom
      final overscroll = value - position.maxScrollExtent;
      if (overscroll > maxOverscroll) {
        return value - position.pixels - (overscroll - maxOverscroll) * overscrollResistance;
      }
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      // Hit the top edge
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent && position.maxScrollExtent > position.pixels) {
      // Hit the bottom edge
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = this.tolerance;
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        tolerance: tolerance,
        friction: 0.015, // Smooth friction for natural feel
      );
    }
    return null;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.outOfRange) {
      // Apply resistance when out of bounds for natural feel
      final double overscroll = math.max(
        position.pixels - position.maxScrollExtent,
        position.minScrollExtent - position.pixels,
      );
      if (overscroll > maxOverscroll) {
        final resistanceFactor = overscrollResistance * 
            (1.0 - (maxOverscroll / math.max(overscroll, maxOverscroll + 1)));
        return offset * (1.0 - resistanceFactor);
      }
    }
    return offset;
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;
  
  @override
  double carriedMomentum(double currentVelocity) {
    // Smooth momentum for natural scrolling feel
    return currentVelocity.sign * 
        math.min(0.000816 * currentVelocity.abs(), 4000.0);
  }
}

