import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/discount_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/discount/discount_campaign.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:intl/intl.dart';

class DiscountManagementScreen extends StatefulWidget {
  const DiscountManagementScreen({super.key});

  @override
  State<DiscountManagementScreen> createState() => _DiscountManagementScreenState();
}

class _DiscountManagementScreenState extends State<DiscountManagementScreen> {
  final DiscountService _svc = DiscountService();
  bool _isLoading = true;
  List<DiscountCampaign> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final res = await _svc.getCampaigns();
    if (res.isSuccess) {
      setState(() {
        _campaigns = res.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  Future<void> _toggleStatus(DiscountCampaign campaign) async {
    final res = await _svc.toggleStatus(campaign.campaignId);
    if (res.isSuccess) {
      _loadData();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  void _showForm(DiscountCampaign? campaign) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiscountFormSheet(
        campaign: campaign,
        service: _svc,
        onSaved: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    if (user?.role != AppConstants.roleOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Khuyến Mãi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Bạn không có quyền truy cập hoặc chỉnh sửa chiến dịch khuyến mãi.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quản lý Khuyến Mãi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? const Center(child: Text('Chưa có mã khuyến mãi nào'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.marginMobile),
                    itemCount: _campaigns.length,
                    itemBuilder: (context, index) {
                      final item = _campaigns[index];
                      return _DiscountCard(
                        campaign: item,
                        onToggle: () => _toggleStatus(item),
                        onEdit: () => _showForm(item),
                      );
                    },
                  ),
                ),
    );
  }
}

class _DiscountCard extends StatelessWidget {
  final DiscountCampaign campaign;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _DiscountCard({required this.campaign, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final discountText = campaign.discountType == 0 
        ? '${campaign.discountValue.toStringAsFixed(0)}%' 
        : MoneyFormatter.format(campaign.discountValue);

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: campaign.isActive 
              ? AppColors.primary.withAlpha(50) 
              : AppColors.outlineVariant.withAlpha(50)
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          campaign.code,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: campaign.isActive ? AppColors.successContainer : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          campaign.isActive ? 'Đang chạy' : 'Đã dừng',
                          style: TextStyle(
                            color: campaign.isActive ? AppColors.success : AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giảm $discountText',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (campaign.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      campaign.description,
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'HSD: ${format.format(campaign.startDate)} - ${format.format(campaign.endDate)}',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đã dùng: ${campaign.usedCount}/${campaign.usageLimit > 0 ? campaign.usageLimit : "∞"} | Đơn tối thiểu: ${MoneyFormatter.format(campaign.minOrderValue)}',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: campaign.isActive,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountFormSheet extends StatefulWidget {
  final DiscountCampaign? campaign;
  final DiscountService service;
  final VoidCallback onSaved;

  const _DiscountFormSheet({this.campaign, required this.service, required this.onSaved});

  @override
  State<_DiscountFormSheet> createState() => _DiscountFormSheetState();
}

class _DiscountFormSheetState extends State<_DiscountFormSheet> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxDiscCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      final c = widget.campaign!;
      _codeCtrl.text = c.code;
      _valueCtrl.text = c.discountValue.toString();
      _minOrderCtrl.text = c.minOrderValue.toString();
      _maxDiscCtrl.text = c.maxDiscountAmount?.toString() ?? '';
      _limitCtrl.text = c.usageLimit.toString();
      _descCtrl.text = c.description;
      _start = c.startDate;
      _end = c.endDate;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscCtrl.dispose();
    _limitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeCtrl.text.isEmpty || _valueCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    
    final data = {
      'code': _codeCtrl.text.toUpperCase(),
      'discountPercent': double.tryParse(_valueCtrl.text) ?? 0,
      'description': _descCtrl.text.trim(),
      'minOrderValue': double.tryParse(_minOrderCtrl.text) ?? 0,
      'maxDiscountAmount': _maxDiscCtrl.text.isEmpty ? null : double.tryParse(_maxDiscCtrl.text),
      'usageLimit': _limitCtrl.text.isEmpty ? null : int.tryParse(_limitCtrl.text),
      'startDate': _start.toIso8601String(),
      'endDate': _end.toIso8601String(),
      'isActive': widget.campaign?.isActive ?? true,
      'branchId': widget.campaign?.branchId,
    };

    final isUpdate = widget.campaign != null;
    final res = isUpdate 
        ? await widget.service.updateCampaign(widget.campaign!.campaignId, data)
        : await widget.service.createCampaign(data);

    setState(() => _saving = false);
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa mã ${widget.campaign!.code}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      )
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    final res = await widget.service.deleteCampaign(widget.campaign!.campaignId);
    setState(() => _saving = false);
    
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _start = date;
        } else {
          _end = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.campaign == null ? 'Thêm Khuyến Mãi' : 'Sửa Khuyến Mãi',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Mã Code
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã Code (vd: TET2026)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              
              // Mô tả
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chiến dịch',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              
              // Mức giảm (%) + Giới hạn số lượng dùng
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mức giảm (%)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _limitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giới hạn dùng (Để trống = ∞)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Đơn tối thiểu + Giảm tối đa
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minOrderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Đơn tối thiểu (VNĐ)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxDiscCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giảm tối đa (VNĐ)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Ngày bắt đầu + kết thúc
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Bắt đầu: ${format.format(_start)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Kết thúc: ${format.format(_end)}'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  if (widget.campaign != null) ...[
                    OutlinedButton(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Icon(Icons.delete),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ) 
                        : Text(widget.campaign == null ? 'Tạo khuyến mãi' : 'Lưu thay đổi'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
