import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';

class FaceScanDialog extends StatefulWidget {
  const FaceScanDialog({super.key});

  @override
  State<FaceScanDialog> createState() => _FaceScanDialogState();
}

class _FaceScanDialogState extends State<FaceScanDialog> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isScanning = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _simulateScan();
  }

  void _simulateScan() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _isSuccess = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isScanning ? 'AI Face Scanning...' : 'Success!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withAlpha(50), width: 4),
                  ),
                  child: const Icon(Icons.person, size: 80, color: Colors.grey),
                ),
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      return Positioned(
                        top: 150 * _ctrl.value,
                        child: Container(
                          width: 140,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if (_isSuccess)
                  const Icon(Icons.check_circle_rounded, size: 100, color: AppColors.success),
              ],
            ),
            const SizedBox(height: 32),
            if (_isScanning)
              const Text(
                'Please keep your face within the frame',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            if (_isScanning)
              const SizedBox(height: 16),
            if (_isScanning)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
