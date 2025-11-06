import 'package:flutter/material.dart';
import '../utils/prototype_animations.dart';

/// Staggered Card List Widget
/// Animates cards with stagger effect (slide from left + fade)
class StaggeredCardList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final TickerProvider vsync;

  const StaggeredCardList({
    super.key,
    required this.vsync,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final staggeredAnimations = StaggeredListAnimations(
      vsync: vsync,
      itemCount: itemCount,
    );

    return ListView.builder(
      padding: padding,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return staggeredAnimations.buildAnimatedItem(
          index,
          itemBuilder(context, index),
        );
      },
    );
  }
}

/// Staggered Card Grid Widget
class StaggeredCardGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final TickerProvider vsync;

  const StaggeredCardGrid({
    super.key,
    required this.vsync,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final staggeredAnimations = StaggeredListAnimations(
      vsync: vsync,
      itemCount: itemCount,
    );

    return GridView.builder(
      padding: padding,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return staggeredAnimations.buildAnimatedItem(
          index,
          itemBuilder(context, index),
        );
      },
    );
  }
}


