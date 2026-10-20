import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';

/// Widget hiển thị ảnh thực cho món ăn (hỗ trợ URL mạng, đường dẫn asset,
/// và tự động ánh xạ sang ảnh ẩm thực chất lượng cao nếu DB chưa có ImagePath).
class MenuItemImage extends StatelessWidget {
  final String? imagePath;
  final String itemName;
  final String emoji;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double emojiSize;

  const MenuItemImage({
    super.key,
    this.imagePath,
    required this.itemName,
    this.emoji = '🍽️',
    this.width,
    this.height,
    this.borderRadius,
    this.emojiSize = 32,
  });

  /// Tự động chọn ảnh món ăn thực tế chất lượng cao (Unsplash) dựa theo tên món hoặc emoji
  /// khi trường ImagePath trong CSDL đang để trống.
  static String resolveFoodImageUrl({
    String? imagePath,
    required String itemName,
    String emoji = '',
  }) {
    final trimmed = imagePath?.trim() ?? '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('assets/')) {
      return trimmed;
    }

    final n = itemName.toLowerCase();

    // 1. Hải sản (Tôm, Cua, Cá hồi, Mực, Hàu, Nghêu, Sò)
    if (n.contains('tôm') || n.contains('shrimp') || n.contains('prawn') || emoji.contains('🦐')) {
      return 'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('cá hồi') || n.contains('salmon') || n.contains('sashimi') || emoji.contains('🍣')) {
      return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('cua') || n.contains('ghẹ') || n.contains('crab') || emoji.contains('🦀')) {
      return 'https://images.unsplash.com/photo-1559737558-2f5a35f4523b?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('mực') || n.contains('bạch tuộc') || n.contains('squid') || n.contains('hải sản') || emoji.contains('🦑')) {
      return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80';
    }

    // 2. Bò / Steak / Sườn nướng
    if (n.contains('bò') || n.contains('steak') || n.contains('bít tết') || n.contains('wagyu') || emoji.contains('🥩')) {
      return 'https://images.unsplash.com/photo-1600891964092-4316c288032e?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('sườn') || n.contains('bbq') || n.contains('nướng') || n.contains('heo') || emoji.contains('🍖')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80';
    }

    // 3. Phở / Bún / Mì / Lẩu / Súp
    if (n.contains('phở') || n.contains('bún') || n.contains('hủ tiếu') || n.contains('ramen') || emoji.contains('🍜')) {
      return 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('lẩu') || n.contains('hotpot') || n.contains('canh') || n.contains('súp') || n.contains('soup') || emoji.contains('🍲')) {
      return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('mì ý') || n.contains('pasta') || n.contains('spaghetti') || emoji.contains('🍝')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3d5d6281298?auto=format&fit=crop&w=600&q=80';
    }

    // 4. Gà / Vịt / Cơm / Pizza / Burger
    if (n.contains('gà') || n.contains('vịt') || n.contains('chicken') || emoji.contains('🍗')) {
      return 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('cơm') || n.contains('rice') || emoji.contains('🍛') || emoji.contains('🍚')) {
      return 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('pizza') || emoji.contains('🍕')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('burger') || n.contains('bánh mì') || emoji.contains('🍔')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=600&q=80';
    }

    // 5. Khai vị / Salad / Gỏi / Khoai tây
    if (n.contains('salad') || n.contains('gỏi') || n.contains('rau') || emoji.contains('🥗')) {
      return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('chả giò') || n.contains('gỏi cuốn') || n.contains('khai vị') || n.contains('khoai')) {
      return 'https://images.unsplash.com/photo-1541529086526-db283c563270?auto=format&fit=crop&w=600&q=80';
    }

    // 6. Tráng miệng / Bánh / Kem
    if (n.contains('kem') || n.contains('bánh') || n.contains('chè') || n.contains('tráng miệng') ||
        n.contains('cake') || n.contains('tiramisu') || emoji.contains('🍰') || emoji.contains('🍨')) {
      return 'https://images.unsplash.com/photo-1551024601-bec78aea704b?auto=format&fit=crop&w=600&q=80';
    }

    // 7. Đồ uống / Trà / Cà phê / Nước ép / Rượu vang / Bia
    if (n.contains('rượu') || n.contains('vang') || n.contains('wine') || n.contains('cocktail') || emoji.contains('🍷') || emoji.contains('🍸')) {
      return 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('bia') || n.contains('beer') || emoji.contains('🍺')) {
      return 'https://images.unsplash.com/photo-1608270586620-248524c67de9?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('cà phê') || n.contains('coffee') || emoji.contains('☕')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('trà') || n.contains('nước') || n.contains('sinh tố') || n.contains('ép') ||
        n.contains('juice') || n.contains('tea') || emoji.contains('🍹') || emoji.contains('🧋')) {
      return 'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=600&q=80';
    }

    // Ảnh món ăn nhà hàng sang trọng mặc định
    final defaultPool = [
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80',
    ];
    final idx = itemName.hashCode.abs() % defaultPool.length;
    return defaultPool[idx];
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        emoji.isNotEmpty ? emoji : '🍽️',
        style: TextStyle(fontSize: emojiSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveFoodImageUrl(
      imagePath: imagePath,
      itemName: itemName,
      emoji: emoji,
    );
    final radius = borderRadius ?? BorderRadius.circular(12);

    Widget imgWidget;
    if (resolved.startsWith('assets/')) {
      imgWidget = Image.asset(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    } else {
      imgWidget = Image.network(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: imgWidget,
      ),
    );
  }
}

/// Widget hiển thị ảnh đại diện người dùng thực tế
class UserAvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final String fullName;
  final int role;
  final double size;

  const UserAvatarImage({
    super.key,
    this.avatarUrl,
    required this.fullName,
    this.role = 3,
    this.size = 56,
  });

  static String resolveAvatarUrl({
    String? avatarUrl,
    required String fullName,
    required int role,
  }) {
    final trimmed = avatarUrl?.trim() ?? '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    switch (role) {
      case 0: // Owner
        return 'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=300&q=80';
      case 2: // Manager
        return 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=300&q=80';
      case 1: // Staff
        return 'https://images.unsplash.com/photo-1583394838336-acd977736f90?auto=format&fit=crop&w=300&q=80';
      default: // Customer
        return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(
      avatarUrl: avatarUrl,
      fullName: fullName,
      role: role,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.aiGradient,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
