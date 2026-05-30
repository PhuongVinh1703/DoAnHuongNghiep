import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class NotificationItem {
  final String id;
  final String title;
  final String content;
  final String time;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  // Preferences state
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _smsEnabled = false;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final role = auth.currentUser?.role ?? 3;

    // Load preferences
    final prefs = await SharedPreferences.getInstance();
    _pushEnabled = prefs.getBool('pref_push') ?? true;
    _emailEnabled = prefs.getBool('pref_email') ?? false;
    _smsEnabled = prefs.getBool('pref_sms') ?? false;
    _soundEnabled = prefs.getBool('pref_sound') ?? true;

    // Generate simulated role-specific notifications
    _notifications = _getNotificationsForRole(role);
    
    setState(() => _isLoading = false);
  }

  Future<void> _togglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'pref_push') _pushEnabled = value;
      if (key == 'pref_email') _emailEnabled = value;
      if (key == 'pref_sms') _smsEnabled = value;
      if (key == 'pref_sound') _soundEnabled = value;
    });
  }

  List<NotificationItem> _getNotificationsForRole(int role) {
    switch (role) {
      case 0: // Owner
        return [
          NotificationItem(
            id: 'o1',
            title: 'Doanh thu ngày vượt mốc chi nhánh',
            content: 'Chúc mừng! Chi nhánh Quận 1 đã vượt mốc doanh thu ngày 50.000.000đ vào lúc 20:30 hôm nay.',
            time: '10 phút trước',
            icon: Icons.stars_rounded,
            iconBg: const Color(0xFFFFF9C4),
            iconColor: const Color(0xFFFBC02D),
          ),
          NotificationItem(
            id: 'o2',
            title: 'Báo cáo tài chính tuần đã sẵn sàng',
            content: 'Báo cáo doanh thu từ 15/05 đến 22/05 của hệ thống đã sẵn sàng. Tăng trưởng hệ thống đạt 12.3% so với tuần trước.',
            time: '2 giờ trước',
            icon: Icons.insert_chart_rounded,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1976D2),
          ),
          NotificationItem(
            id: 'o3',
            title: 'Cảnh báo AI: Hiệu suất chuẩn bị món',
            content: 'Hệ thống AI phân tích: Thời gian làm món trung bình tại Chi nhánh 2 tăng 4.2 phút so với tuần trước. Đề xuất tối ưu quy trình bếp.',
            time: '1 ngày trước',
            icon: Icons.warning_amber_rounded,
            iconBg: const Color(0xFFFFE0B2),
            iconColor: const Color(0xFFF57C00),
            isRead: true,
          ),
          NotificationItem(
            id: 'o4',
            title: 'Yêu cầu phê duyệt chiến dịch tiếp thị',
            content: 'Quản lý Chi nhánh 1 đã tạo đề xuất chạy chiến dịch giảm 15% cho nhóm khách hàng đi từ 4 người trong tháng tới.',
            time: '2 ngày trước',
            icon: Icons.local_offer_outlined,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF388E3C),
            isRead: true,
          ),
        ];
      case 2: // Manager
        return [
          NotificationItem(
            id: 'm1',
            title: 'Cảnh báo AI: Nguy cơ thiếu nguyên liệu',
            content: 'Hệ thống AI dự báo: Nguyên liệu "Tôm Hùm" có thể bị thiếu hụt tối nay dựa trên lượng khách đặt bàn đột biến.',
            time: '5 phút trước',
            icon: Icons.warning_amber_rounded,
            iconBg: const Color(0xFFFFDAD6),
            iconColor: AppColors.error,
          ),
          NotificationItem(
            id: 'm2',
            title: 'Yêu cầu phê duyệt huỷ hoá đơn',
            content: 'Nhân viên Nguyễn Văn B gửi yêu cầu duyệt huỷ món "Súp Bào Ngư" trong hoá đơn #1042. Lý do: Khách đổi món khác.',
            time: '15 phút trước',
            icon: Icons.security_rounded,
            iconBg: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
          ),
          NotificationItem(
            id: 'm3',
            title: 'Đặt bàn VIP mới cần duyệt',
            content: 'Khách hàng VIP Trần Thị C vừa gửi yêu cầu đặt bàn 10 người cho tối mai tại phòng VIP 1.',
            time: '1 giờ trước',
            icon: Icons.star_rounded,
            iconBg: const Color(0xFFFFF9C4),
            iconColor: const Color(0xFFFBC02D),
            isRead: true,
          ),
          NotificationItem(
            id: 'm4',
            title: 'Báo cáo chốt doanh thu ca sáng',
            content: 'Báo cáo kết ca sáng của Chi nhánh 1 đã được gửi: Tổng doanh thu đạt 14.500.000đ.',
            time: '4 giờ trước',
            icon: Icons.monetization_on_outlined,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF388E3C),
            isRead: true,
          ),
        ];
      case 1: // Staff
        return [
          NotificationItem(
            id: 's1',
            title: 'Món ăn bàn số 5 đã chuẩn bị xong',
            content: 'Đầu bếp báo: Món "Cua Sốt Ớt" cho Bàn số 5 đã hoàn thành. Vui lòng nhận món và phục vụ khách!',
            time: '2 phút trước',
            icon: Icons.restaurant_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF388E3C),
          ),
          NotificationItem(
            id: 's2',
            title: 'Yêu cầu gọi thanh toán từ Bàn 3',
            content: 'Khách hàng tại Bàn 3 vừa bấm nút yêu cầu hỗ trợ thanh toán hoá đơn trên máy tính bảng bàn.',
            time: '12 phút trước',
            icon: Icons.info_outline_rounded,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1976D2),
          ),
          NotificationItem(
            id: 's3',
            title: 'Khách đặt bàn đã tới - Bàn 12',
            content: 'Yêu cầu chuẩn bị set up: Khách đặt bàn lúc 19:30 (Nguyễn Văn A) đã đến cửa chi nhánh.',
            time: '1 giờ trước',
            icon: Icons.access_time_rounded,
            iconBg: const Color(0xFFFFF9C4),
            iconColor: const Color(0xFFFBC02D),
            isRead: true,
          ),
          NotificationItem(
            id: 's4',
            title: 'Cập nhật ca làm việc tuần',
            content: 'Quản lý đã thêm bạn vào ca làm việc chiều tối nay (18:00 - 22:00). Hãy kiểm tra đúng giờ.',
            time: 'Hôm qua',
            icon: Icons.schedule_rounded,
            iconBg: const Color(0xFFECEFF1),
            iconColor: const Color(0xFF455A64),
            isRead: true,
          ),
        ];
      case 3: // Customer
      default:
        return [
          NotificationItem(
            id: 'c1',
            title: 'Đơn hàng #1085 đã hoàn thành',
            content: 'Cảm ơn bạn! Đơn hàng tại chi nhánh Quận 1 đã thanh toán thành công. Bạn đã nhận thêm +50 điểm tích luỹ thành viên.',
            time: '5 phút trước',
            icon: Icons.check_circle_outline_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF388E3C),
          ),
          NotificationItem(
            id: 'c2',
            title: 'Yêu cầu đặt bàn đã được xác nhận',
            content: 'Tuyệt vời! Đặt bàn trước lúc 19:00 hôm nay tại chi nhánh Quận 1 đã được nhân viên nhà hàng phê duyệt thành công.',
            time: '1 giờ trước',
            icon: Icons.event_available_rounded,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1976D2),
          ),
          NotificationItem(
            id: 'c3',
            title: 'Quà tặng sinh nhật: Giảm ngay 20%',
            content: 'Tặng riêng bạn mã sinh nhật HAPPYBDAY giảm 20% (tối đa 100k) trên tổng hoá đơn khi dùng bữa tại nhà hàng.',
            time: 'Hôm qua',
            icon: Icons.card_giftcard_rounded,
            iconBg: const Color(0xFFFCE3DA),
            iconColor: AppColors.primary,
            isRead: true,
          ),
          NotificationItem(
            id: 'c4',
            title: 'Chúc mừng thăng hạng thành viên',
            content: 'Bạn đã đạt mốc chi tiêu thăng hạng lên thành viên Bạc. Nhận thêm nhiều ưu đãi tích điểm x1.2 từ hôm nay!',
            time: '3 ngày trước',
            icon: Icons.stars_rounded,
            iconBg: const Color(0xFFFFF9C4),
            iconColor: const Color(0xFFFBC02D),
            isRead: true,
          ),
        ];
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
    AppSnackbar.showSuccess(context, 'Đã đánh dấu tất cả thông báo là đã đọc');
  }

  void _toggleRead(NotificationItem item) {
    setState(() {
      item.isRead = !item.isRead;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Thông Báo', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline_rounded), text: 'Hộp thư'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Cài đặt'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInboxTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildInboxTab() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_lock_rounded, size: 64, color: AppColors.outlineVariant.withAlpha(80)),
            const SizedBox(height: 16),
            Text('Hộp thư thông báo trống', style: TextStyle(color: AppColors.onSurfaceVariant.withAlpha(150))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chưa đọc (${_notifications.where((n) => !n.isRead).length})',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
              ),
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Đọc tất cả', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _notifications[index];
              return InkWell(
                onTap: () => _toggleRead(item),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: item.isRead ? Colors.white : const Color(0xFFFFF5F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.isRead 
                          ? AppColors.outlineVariant.withAlpha(50) 
                          : AppColors.primary.withAlpha(30),
                    ),
                    boxShadow: AppTheme.shadowLevel1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Dot
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(top: 14, right: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 16),
                      
                      // Notification Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 20, color: item.iconColor),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  item.time,
                                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant.withAlpha(150)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kênh Nhận Thông Báo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn cách bạn muốn nhận các cập nhật quan trọng từ hệ thống nhà hàng.',
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          _buildPreferenceTile(
            title: 'Thông báo trên điện thoại (Push Notification)',
            sub: 'Nhận các cảnh báo thời gian thực ngay trên thiết bị.',
            value: _pushEnabled,
            onChanged: (val) => _togglePreference('pref_push', val),
            icon: Icons.phone_android_rounded,
          ),
          _buildPreferenceTile(
            title: 'Thông báo qua Email',
            sub: 'Nhận báo cáo định kỳ và tóm tắt hoạt động chi nhánh.',
            value: _emailEnabled,
            onChanged: (val) => _togglePreference('pref_email', val),
            icon: Icons.alternate_email_rounded,
          ),
          _buildPreferenceTile(
            title: 'Thông báo qua tin nhắn SMS',
            sub: 'Chỉ gửi cho các cảnh báo khẩn cấp hoặc xác nhận giao dịch.',
            value: _smsEnabled,
            onChanged: (val) => _togglePreference('pref_sms', val),
            icon: Icons.sms_outlined,
          ),
          _buildPreferenceTile(
            title: 'Âm thanh cảnh báo',
            sub: 'Phát âm thanh khi có cảnh báo mới đến.',
            value: _soundEnabled,
            onChanged: (val) => _togglePreference('pref_sound', val),
            icon: Icons.volume_up_rounded,
          ),
          
          const SizedBox(height: 32),
          // Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1EC), Color(0xFFFFE9E1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mẹo: Bật "Thông báo đẩy" để không bỏ lỡ các cập nhật món ăn sẵn sàng từ bếp hoặc cảnh báo AI khẩn cấp.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary.withAlpha(100),
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
