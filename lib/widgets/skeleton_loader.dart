import 'package:flutter/material.dart';

/// A shimmer/skeleton loading widget — similar to Instagram's loading UI
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE2E8F0).withOpacity(_animation.value),
                const Color(0xFFCBD5E1).withOpacity(_animation.value * 0.7),
                const Color(0xFFE2E8F0).withOpacity(_animation.value),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card for the hostel list
class HostelCardSkeleton extends StatelessWidget {
  const HostelCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: SkeletonBox(
              width: double.infinity,
              height: 180,
              borderRadius: 0,
            ),
          ),
          // Details placeholder
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 18),
                    SkeletonBox(width: 60, height: 28, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 10),
                SkeletonBox(width: 180, height: 13),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 90, height: 22),
                    SkeletonBox(width: 100, height: 36, borderRadius: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// List of skeleton cards (Instagram-style loading)
class HostelListSkeleton extends StatelessWidget {
  final int count;
  const HostelListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const HostelCardSkeleton(),
    );
  }
}
