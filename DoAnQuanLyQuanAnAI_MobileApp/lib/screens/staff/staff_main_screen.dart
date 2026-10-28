import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_tables_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/kds_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/menu_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/profile_screen.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/app_bottom_nav.dart';
import 'package:doanquanlyquananai_mobileapp/services/locale_service.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/booking_notification_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _currentIndex = 0;
  String? _branchName;

  @override
  void initState() {
    super.initState();
    _loadBranchName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaffTasks();
    });
  }

  Future<void> _loadStaffTasks() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      final branchId = user.branchId ?? 1;
      await context.read<BookingNotificationProvider>().fetchStaffTasks(
        user.fullName,
        branchId,
      );
    }
  }

  Future<void> _loadBranchName() async {
    final user = context.read<AuthService>().currentUser;
    if (user?.branchId != null) {
      try {
        final res = await BranchService().getBranches();
        if (res.isSuccess && res.data != null) {
          final branch = res.data!.firstWhere(
            (b) => b.branchId == user!.branchId,
          );
          setState(() => _branchName = branch.name);
        }
      } catch (_) {}
    }
  }

  final _screens = const [
    StaffTablesScreen(),
    StaffOrderScreen(),
    MenuScreen(),
    ProfileScreen(),
  ];

  void _showStaffTasksBottomSheet(BuildContext parentContext) {
    final user = parentContext.read<AuthService>().currentUser;
    if (user == null) return;

    // Refresh tasks when opening bottom sheet
    parentContext.read<BookingNotificationProvider>().fetchStaffTasks(
      user.fullName,
      user.branchId ?? 1,
    );

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: parentContext.read<BookingNotificationProvider>(),
            ),
          ],
          child: Consumer<BookingNotificationProvider>(
            builder: (context, notiProvider, child) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nhiệm Vụ Ca Trực Của Bạn',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nhân viên: ${user.fullName}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),

                    if (notiProvider.isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (notiProvider.assignedTasks.isEmpty)
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => notiProvider.fetchStaffTasks(
                            user.fullName,
                            user.branchId ?? 1,
                          ),
                          color: AppColors.primary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.2,
                              ),
                              const Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 70,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  'Tuyệt vời! Bạn chưa có nhiệm vụ nào được giao.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Center(
                                child: Text(
                                  'Kéo xuống để làm mới.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => notiProvider.fetchStaffTasks(
                            user.fullName,
                            user.branchId ?? 1,
                          ),
                          color: AppColors.primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: notiProvider.assignedTasks.length,
                            itemBuilder: (context, index) {
                              final reservation =
                                  notiProvider.assignedTasks[index];
                              return TaskReservationCard(
                                reservation: reservation,
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final notiProvider = context.watch<BookingNotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (user != null)
              Text(
                '${user.fullName}${_branchName != null ? ' - $_branchName' : (user.branchId != null ? ' - Chi nhánh ${user.branchId}' : '')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // KDS (Bếp) shortcut
          IconButton(
            icon: const Icon(Icons.restaurant_menu_rounded),
            tooltip: 'Màn hình bếp (KDS)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KdsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded),
            onPressed: () => context.read<LocaleService>().toggleLocale(),
            tooltip: AppLocalizations.of(context).translate('language'),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => _showStaffTasksBottomSheet(context),
              ),
              if (notiProvider.assignedTasks.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notiProvider.assignedTasks.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class TaskReservationCard extends StatefulWidget {
  final Reservation reservation;
  const TaskReservationCard({super.key, required this.reservation});

  @override
  State<TaskReservationCard> createState() => _TaskReservationCardState();
}

class _TaskReservationCardState extends State<TaskReservationCard> {
  final Map<String, bool> _checkedTasks = {};

  @override
  void initState() {
    super.initState();
    final parsed = _parseManagerNote(widget.reservation.managerNote ?? '');
    final List<String> tasks = List<String>.from(parsed['tasks'] ?? []);
    for (var task in tasks) {
      if (task.isNotEmpty && task != 'Hỗ trợ phục vụ bàn') {
        _checkedTasks[task] = false;
      }
    }
  }

  Map<String, dynamic> _parseManagerNote(String note) {
    String staffName = '';
    String shift = '';
    List<String> tasks = [];
    String customNote = '';

    final matchBracket = RegExp(r'\[Giao việc:\s*([^|\]]+?)\s*\|\s*([^\]]+)\]');
    final match = matchBracket.firstMatch(note);
    if (match != null) {
      staffName = match.group(1)?.trim() ?? '';
      shift = match.group(2)?.trim() ?? '';
    }

    final tasksIndex = note.indexOf('Nhiệm vụ:');
    if (tasksIndex != -1) {
      int endTasksIndex = note.indexOf('. Ghi chú thêm:', tasksIndex);
      if (endTasksIndex == -1) {
        endTasksIndex = note.indexOf('.', tasksIndex);
      }
      if (endTasksIndex == -1) {
        endTasksIndex = note.length;
      }

      String tasksStr = note.substring(tasksIndex + 9, endTasksIndex).trim();
      if (tasksStr.endsWith('.')) {
        tasksStr = tasksStr.substring(0, tasksStr.length - 1);
      }
      if (tasksStr.isNotEmpty) {
        tasks = tasksStr
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    }

    final noteIndex = note.indexOf('Ghi chú thêm:');
    if (noteIndex != -1) {
      customNote = note.substring(noteIndex + 13).trim();
    }

    return {
      'staffName': staffName,
      'shift': shift,
      'tasks': tasks,
      'customNote': customNote,
    };
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseManagerNote(widget.reservation.managerNote ?? '');
    final shift = parsed['shift'] as String;
    final List<String> tasks = List<String>.from(parsed['tasks'] ?? []);
    final customNote = parsed['customNote'] as String;

    final revenueTasks = tasks
        .where(
          (t) =>
              t.toLowerCase().contains('upsell') ||
              t.toLowerCase().contains('tráng miệng') ||
              t.toLowerCase().contains('vip') ||
              t.toLowerCase().contains('tư vấn') ||
              t.toLowerCase().contains('doanh thu'),
        )
        .toList();

    final experienceTasks = tasks
        .where(
          (t) =>
              t.toLowerCase().contains('bàn sạch') ||
              t.toLowerCase().contains('đón') ||
              t.toLowerCase().contains('pre-order') ||
              t.toLowerCase().contains('ra món') ||
              t.toLowerCase().contains('trải nghiệm'),
        )
        .toList();

    final commonTasks = tasks
        .where((t) => !revenueTasks.contains(t) && !experienceTasks.contains(t))
        .toList();

    final reservedHour = widget.reservation.reservedAt.hour.toString().padLeft(
      2,
      '0',
    );
    final reservedMinute = widget.reservation.reservedAt.minute
        .toString()
        .padLeft(2, '0');
    final reservedDay = widget.reservation.reservedAt.day.toString().padLeft(
      2,
      '0',
    );
    final reservedMonth = widget.reservation.reservedAt.month
        .toString()
        .padLeft(2, '0');
    final reservedTimeStr =
        '$reservedHour:$reservedMinute - $reservedDay/$reservedMonth';

    final allCompleted =
        _checkedTasks.isNotEmpty && _checkedTasks.values.every((val) => val);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: allCompleted
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: allCompleted
                        ? AppColors.success
                        : AppColors.primary,
                    radius: 16,
                    child: Icon(
                      allCompleted ? Icons.check : Icons.restaurant_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.reservation.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SĐT: ${widget.reservation.customerPhone} | Khách: ${widget.reservation.guestCount}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      reservedTimeStr,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (shift.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.watch_later_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shift,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (revenueTasks.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Tối ưu doanh thu (Lợi nhuận)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...revenueTasks.map((t) => _buildCheckItem(t)),
                    const SizedBox(height: 12),
                  ],

                  if (experienceTasks.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Tối ưu trải nghiệm (Giữ chân khách)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...experienceTasks.map((t) => _buildCheckItem(t)),
                    const SizedBox(height: 12),
                  ],

                  if (commonTasks.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 16,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Nhiệm vụ phục vụ bàn',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...commonTasks.map((t) => _buildCheckItem(t)),
                    const SizedBox(height: 12),
                  ],

                  if (tasks.isEmpty) ...[
                    _buildCheckItem('Hỗ trợ phục vụ bàn'),
                    const SizedBox(height: 12),
                  ],

                  if (customNote.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFBE096)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.feedback_outlined,
                            size: 16,
                            color: Color(0xFFB78103),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ghi chú thêm từ Quản lý:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF8F6300),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  customNote,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (widget.reservation.note != null &&
                      widget.reservation.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ghi chú của Khách hàng:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.reservation.note!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String task) {
    final isChecked = _checkedTasks[task] ?? false;
    return InkWell(
      onTap: () {
        setState(() {
          _checkedTasks[task] = !isChecked;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: isChecked ? AppColors.success : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task,
                style: TextStyle(
                  fontSize: 13,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked ? Colors.grey[500] : Colors.black87,
                  fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
