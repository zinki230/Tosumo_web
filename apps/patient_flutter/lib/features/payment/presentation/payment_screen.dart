import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../shared/widgets/app_back_button.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String doctorName;
  final String specialty;
  final String location;
  final String date;
  final String doctorId;
  final String startTime;
  final String endTime;
  final String reason;

  const PaymentScreen({
    super.key,
    required this.doctorName,
    required this.specialty,
    required this.location,
    required this.date,
    required this.doctorId,
    this.startTime = '',
    this.endTime = '',
    this.reason = '',
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _selected = 'orange';
  String _status = 'idle';

  Future<void> _handlePay() async {
    setState(() => _status = 'processing');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await ref.read(patientProvider.notifier).bookAppointment(
        doctorName: widget.doctorName,
        specialty: widget.specialty,
        location: widget.location,
        date: widget.date,
        doctorId: widget.doctorId,
        startTime: widget.startTime,
        endTime: widget.endTime,
        reason: widget.reason,
      );
      if (!mounted) return;
      setState(() => _status = 'success');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'idle');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    if (_status == 'success') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.checkCircle, size: 40, color: AppColors.accent),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t?.t('payment.success') ?? 'Paiement réussi !',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t?.t('payment.successDescription') ?? 'Votre rendez-vous a été confirmé.',
                    style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/patient/home'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(t?.t('payment.backToHome') ?? 'Retour à l\'accueil'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              t?.t('payment.title') ?? '',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Text(
              widget.doctorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.specialty,
              style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                children: [
                  _PaymentMethod(
                    label: t?.t('payment.orangeMoney') ?? 'Orange Money',
                    badge: 'OM',
                    badgeColor: const Color(0xFFFFF3E0),
                    badgeTextColor: const Color(0xFFF57C00),
                    isSelected: _selected == 'orange',
                    onTap: () => setState(() => _selected = 'orange'),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethod(
                    label: t?.t('payment.momo') ?? 'MOMO',
                    badge: 'MoMo',
                    badgeColor: const Color(0xFFFFF9C4),
                    badgeTextColor: const Color(0xFF1565C0),
                    isSelected: _selected == 'momo',
                    onTap: () => setState(() => _selected = 'momo'),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _status == 'processing' ? null : _handlePay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  disabledBackgroundColor: AppColors.primary.withAlpha(128),
                ),
                child: _status == 'processing'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(t?.t('payment.processing') ?? 'Traitement...'),
                        ],
                      )
                    : Text(t?.t('payment.pay') ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  final String label;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethod({
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.accent.withAlpha(25), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
              size: 24,
              color: isSelected ? AppColors.accent : AppColors.mutedForeground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.foreground : AppColors.mutedForeground,
                ),
              ),
            ),
            Container(
              width: 48, height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
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
