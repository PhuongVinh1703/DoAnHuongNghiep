import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';

class LogItem {
  final String title;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color color;
  final String category; // e.g. 'order', 'points', 'system', 'menu'

  LogItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.category,
  });
}

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<LogItem> _logs = [];
  bool _isLoading = true;
  String _activeFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    if (user.role == 3) {
      // Customer
      final provider = context.read<CustomerProvider>();
      await provider.fetchTransactions();
      
      final realTxns = provider.transactions;
      final tempLogs = <LogItem>[];

      if (realTxns.isNotEmpty) {
        final formatter = DateFormat('dd/MM/yyyy HH:mm');
        for (var tx in realTxns) {
          final isAdd = tx.pointDelta > 0;
          tempLogs.add(LogItem(
            title: isAdd ? 'Tích lũy điểm thành công' : 'Đổi quà thành viên',
            description: tx.note.isNotEmpty ? tx.note : (isAdd ? 'Cộng điểm từ hoá đơn thanh toán' : 'Trừ điểm quy đổi voucher'),
            timestamp: formatter.format(tx.createdAt),
            icon: isAdd ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            color: isAdd ? Colors.green : AppColors.primary,
            category: 'points',
          ));
        }
      } else {
        // Fallback simulated logs if transactions list is empty
        tempLogs.addAll([
          LogItem(
            title: 'Tích điểm thành viên',
            description: 'Đã tích +52 điểm từ đơn hàng #1085 tại chi nhánh Quận 1',
            timestamp: 'Hôm nay - 20:32',
            icon: Icons.add_circle_outline_rounded,
            color: Colors.green,
            category: 'points',
          ),
          LogItem(
            title: 'Đặt bàn thành công',
            description: 'Đã hoàn thành bàn đặt trước lúc 19:00 tại chi nhánh Quận 1',
            timestamp: 'Hôm nay - 19:00',
            icon: Icons.event_available_rounded,
            color: Colors.blue,
            category: 'booking',
          ),
          LogItem(
            title: 'Đổi điểm nhận Voucher',
            description: 'Quy đổi -100 điểm để lấy Voucher giảm giá 20k',
            timestamp: 'Hôm qua - 14:15',
            icon: Icons.card_giftcard_rounded,
            color: AppColors.primary,
            category: 'points',
          ),
          LogItem(
            title: 'Đăng ký tài khoản',
            description: 'Chào mừng thành viên mới tham gia Reserve & Relish!',
            timestamp: '15/05/2026',
            icon: Icons.person_add_alt_1_rounded,
            color: Colors.purple,
            category: 'system',
          ),
        ]);
      }
      _logs = tempLogs;
    } else {
      // Employee timeline
      _logs = _getEmployeeLogs(user.role);
    }
    setState(() => _isLoading = false);
  }

  List<LogItem> _getEmployeeLogs(int role) {
    if (role == 1) {
      // Staff
      return [
        LogItem(
          title: 'Phục vụ bàn số 5 hoàn tất',
          description: 'Giao món "Cua Sốt Ớt" và hoàn tất phục vụ bàn 5',
          timestamp: 'Ca tối - 20:34',
          icon: Icons.restaurant_rounded,
          color: Colors.green,
          category: 'service',
        ),
        LogItem(
          title: 'Tạo đơn hàng mới',
          description: 'Lập đơn hàng #1092 cho Bàn 8 gồm 4 món ăn',
          timestamp: 'Ca tối - 20:10',
          icon: Icons.add_shopping_cart_rounded,
          color: Colors.blue,
          category: 'order',
        ),
        LogItem(
          title: 'Hỗ trợ thanh toán bàn 3',
          description: 'Thực hiện in hóa đơn tạm tính và hỗ trợ thanh toán bàn 3',
          timestamp: 'Ca tối - 19:45',
          icon: Icons.print_rounded,
          color: Colors.orange,
          category: 'service',
        ),
        LogItem(
          title: 'Bắt đầu ca làm việc',
          description: 'Điểm danh bắt đầu ca tối chi nhánh Quận 1',
          timestamp: 'Ca tối - 18:00',
          icon: Icons.login_rounded,
          color: Colors.purple,
          category: 'system',
        ),
      ];
    } else if (role == 2) {
      // Manager
      return [
        LogItem(
          title: 'Giải quyết cảnh báo AI',
          description: 'Đã xử lý cảnh báo AI số #42: Phê duyệt tăng tồn kho dự phòng Tôm Hùm',
          timestamp: 'Hôm nay - 20:45',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          category: 'system',
        ),
        LogItem(
          title: 'Phê duyệt huỷ món ăn',
          description: 'Duyệt yêu cầu huỷ "Súp Bào Ngư" trong đơn #1042 của nhân viên B',
          timestamp: 'Hôm nay - 19:50',
          icon: Icons.security_rounded,
          color: Colors.red,
          category: 'approval',
        ),
        LogItem(
          title: 'Thay đổi trạng thái món ăn',
          description: 'Tạm ngưng phục vụ món "Lẩu Cá Song" do hết hàng tươi sống',
          timestamp: 'Hôm nay - 18:30',
          icon: Icons.block_flipped,
          color: Colors.orange,
          category: 'menu',
        ),
        LogItem(
          title: 'Chốt doanh thu ca sáng',
          description: 'Xác nhận doanh thu ca sáng chi nhánh Quận 1 đạt 14.500.000đ',
          timestamp: 'Hôm nay - 14:05',
          icon: Icons.monetization_on_rounded,
          color: Colors.blue,
          category: 'finance',
        ),
      ];
    } else {
      // Owner (0)
      return [
        LogItem(
          title: 'Đóng ca quyết toán chi nhánh',
          description: 'Xác nhận báo cáo doanh thu cuối ngày chi nhánh Quận 1: 52.400.000đ',
          timestamp: 'Hôm nay - 21:00',
          icon: Icons.summarize_rounded,
          color: Colors.green,
          category: 'finance',
        ),
        LogItem(
          title: 'Cập nhật thông tin chi nhánh',
          description: 'Thay đổi số điện thoại hotline chi nhánh Quận 1',
          timestamp: 'Hôm nay - 15:30',
          icon: Icons.store_rounded,
          color: Colors.blue,
          category: 'system',
        ),
        LogItem(
          title: 'Tạo chiến dịch giảm giá mới',
          description: 'Khởi chạy chiến dịch khuyến mãi "Lễ hội Mùa Hè" giảm 15%',
          timestamp: 'Hôm qua - 09:00',
          icon: Icons.local_offer_rounded,
          color: Colors.purple,
          category: 'marketing',
        ),
        LogItem(
          title: 'Đăng ký tài khoản nhân viên mới',
          description: 'Tạo tài khoản quản lý chi nhánh mới cho Trần Văn C',
          timestamp: '20/05/2026',
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.teal,
          category: 'system',
        ),
      ];
    }
  }

  List<LogItem> get _filteredLogs {
    if (_activeFilter == 'Tất cả') return _logs;
    if (_activeFilter == 'Tích lũy' || _activeFilter == 'Phục vụ') {
      return _logs.where((l) => l.category == 'points' || l.category == 'service').toList();
    }
    if (_activeFilter == 'Hệ thống') {
      return _logs.where((l) => l.category == 'system').toList();
    }
    return _logs;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    final isCustomer = context.watch<AuthService>().currentUser?.role == 3;
    
    final filters = isCustomer
        ? ['Tất cả', 'Tích lũy', 'Hệ thống']
        : ['Tất cả', 'Phục vụ', 'Hệ thống'];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nhật Ký Hoạt Động', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Row(
              children: filters.map((f) {
                final selected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _activeFilter = f);
                    },
                    selectedColor: AppColors.primary.withAlpha(30),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Timeline Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isLast = index == filtered.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Timeline line and icon
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: item.color.withAlpha(20),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: item.color.withAlpha(80), width: 1.5),
                                      ),
                                      child: Icon(item.icon, size: 18, color: item.color),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: VerticalDivider(
                                          thickness: 2,
                                          color: AppColors.outlineVariant.withAlpha(80),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Timeline card details
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.outlineVariant.withAlpha(40)),
                                        boxShadow: AppTheme.shadowLevel1,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                item.timestamp,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.onSurfaceVariant.withAlpha(150),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.onSurfaceVariant,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.outlineVariant.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy lịch sử hoạt động',
            style: TextStyle(color: AppColors.onSurfaceVariant.withAlpha(150)),
          ),
        ],
      ),
    );
  }
}
