import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';

/// Bộ khung hiệu ứng tải Skeleton Shimmer đồng bộ cho toàn hệ thống POS
class AppShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? const Color(0xFFE8E5E2),
      highlightColor: highlightColor ?? const Color(0xFFF7F5F3),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Khối hộp chữ nhật shimmer tùy chỉnh kích thước và bo góc
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Khối hình tròn shimmer (avatar, icon badge, table tròn)
class ShimmerCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton hiển thị khi tải sơ đồ bàn (Floor Plan)
class TableGridShimmer extends StatelessWidget {
  final int count;

  const TableGridShimmer({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
        child: Column(
          children: [
            // Header stats skeleton
            Row(
              children: List.generate(
                3,
                (index) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: ShimmerBox(width: double.infinity, height: 60, borderRadius: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Filter chips skeleton
            Row(
              children: List.generate(
                4,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ShimmerBox(width: 72, height: 34, borderRadius: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Table items grid skeleton
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: AppTheme.gutterCard,
                  mainAxisSpacing: AppTheme.gutterCard,
                ),
                itemCount: count,
                itemBuilder: (context, index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton hiển thị khi tải danh sách Order / Menu / KDS tickets
class CardListShimmer extends StatelessWidget {
  final int count;
  final double cardHeight;

  const CardListShimmer({
    super.key,
    this.count = 5,
    this.cardHeight = 90,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}

/// Skeleton hiển thị thẻ chỉ số Dashboard KPI
class DashboardStatShimmer extends StatelessWidget {
  const DashboardStatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 200, borderRadius: 16),
        ],
      ),
    );
  }
}
