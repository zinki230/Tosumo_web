import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../../shared/models/patient.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/localization.dart';

class PremiumMedicalCard extends StatefulWidget {
  final String name;
  final String nationalId;
  final String dateOfBirth;
  final String bloodType;
  final String status;
  final bool verified;
  final String cardToken;
  final List<String> allergies;
  final List<String> chronicConditions;
  final EmergencyContact? emergencyContact;
  final String? gender;
  final AppLocalization? t;

  const PremiumMedicalCard({
    super.key,
    required this.name,
    required this.nationalId,
    required this.dateOfBirth,
    required this.bloodType,
    required this.status,
    this.verified = false,
    required this.cardToken,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.emergencyContact,
    this.gender,
    this.t,
  });

  @override
  State<PremiumMedicalCard> createState() => _PremiumMedicalCardState();
}

class _PremiumMedicalCardState extends State<PremiumMedicalCard> {
  bool _isFlipped = false;
  bool _entered = false;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _entered = true);
    });
  }

  void _handleFlip() {
    setState(() => _isFlipping = true);
    setState(() => _isFlipped = !_isFlipped);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isFlipping = false);
    });
  }

  void _openEnlargedQr() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      tooltip: widget.t?.t('common.close') ?? 'Close',
                      icon: const Icon(LucideIcons.x, size: 24, color: Color(0xFF1E3FAF)),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest.shortestSide - 48;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(26),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: (widget.cardToken.isNotEmpty && widget.cardToken != 'PENDING')
                                    ? QrImageView(
                                        data: widget.cardToken,
                                        version: QrVersions.auto,
                                        size: size.clamp(200, 420),
                                        eyeStyle: QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: const Color(0xFF1E3FAF),
                                        ),
                                        dataModuleStyle: const QrDataModuleStyle(
                                          dataModuleShape: QrDataModuleShape.square,
                                          color: Color(0xFF1E3FAF),
                                        ),
                                      )
                                    : SizedBox(
                                        width: size.clamp(200, 420),
                                        height: size.clamp(200, 420),
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                widget.t?.t('card.premiumCard.qrInstructions') ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  Color _statusColor() {
    if (widget.verified) return const Color(0xFF10B981);
    return const Color(0xFFF59E0B);
  }

  String _statusLabel() {
    return widget.verified
        ? (widget.t?.t('card.verified') ?? 'Vérifié')
        : (widget.t?.t('card.notVerified') ?? 'Non-vérifié');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: _entered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: AnimatedSlide(
            offset: _entered ? Offset.zero : const Offset(0, 0.05),
            duration: const Duration(milliseconds: 600),
            curve: const Cubic(0.34, 1.56, 0.64, 1),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: GestureDetector(
                onTap: _handleFlip,
                child: _build3dCard(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFlipButton(),
      ],
    );
  }

  Widget _build3dCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([]),
      builder: (context, child) {
        return _FlipContainer(
          isFlipped: _isFlipped,
          isFlipping: _isFlipping,
          front: _buildFront(),
          back: _buildBack(),
        );
      },
    );
  }

  Widget _buildFront() {
    final nameParts = widget.name.trim().split(RegExp(r'\s+'));
    final lastName = nameParts.length > 1
        ? nameParts.last.toUpperCase()
        : widget.name.toUpperCase();
    final firstNames = nameParts.length > 1
        ? nameParts.sublist(0, nameParts.length - 1).join(' ')
        : widget.name;
    final initials = _getInitials(widget.name);
    final displayId = widget.nationalId;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a2a6c), Color(0xFF2348D4), Color(0xFF152B80)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2348D4).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardWavePattern(),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white.withAlpha(13),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.4],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.activity,
                              size: 16,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.t?.t('brand.name') ?? 'TOSUMO',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                widget.t?.t('card.front.medicalIdentity') ?? '',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.white.withAlpha(128),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor().withAlpha(38),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.verified ? LucideIcons.badgeCheck : LucideIcons.alertTriangle,
                              size: 14,
                              color: _statusColor(),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _statusLabel(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(38),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white.withAlpha(64),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(38),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white.withAlpha(128),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              firstNames,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              height: 1,
                              color: AppColors.white.withAlpha(25),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            Text(
                              widget.t?.t('card.front.id') ?? 'ID',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: AppColors.white.withAlpha(102),
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              displayId,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white.withAlpha(230),
                                letterSpacing: 1,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.white.withAlpha(51),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                widget.bloodType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.t?.t('card.front.bloodGroup') ?? '',
                            style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.w500,
                              color: AppColors.white.withAlpha(102),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        widget.t?.t('card.front.gender', params: {'value': widget.gender ?? '—'}) ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.white.withAlpha(128),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 12,
                        color: AppColors.white.withAlpha(25),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.t?.t('card.front.dob', params: {'value': widget.dateOfBirth}) ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.white.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2F6B), Color(0xFF1E3FAF), Color(0xFF152B80)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3FAF).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardWavePattern(),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white.withAlpha(13),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.4],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = constraints.biggest.shortestSide;
                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: GestureDetector(
                                    onTap: _openEnlargedQr,
                                    child: Container(
                                      width: side,
                                      height: side,
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(51),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: (widget.cardToken.isNotEmpty && widget.cardToken != 'PENDING')
                                          ? QrImageView(
                                              data: widget.cardToken,
                                              version: QrVersions.auto,
                                              size: (side - 20).clamp(60.0, 420.0),
                                              eyeStyle: QrEyeStyle(
                                                eyeShape: QrEyeShape.square,
                                                color: const Color(0xFF1E3FAF),
                                              ),
                                              dataModuleStyle: const QrDataModuleStyle(
                                                dataModuleShape: QrDataModuleShape.square,
                                                color: Color(0xFF1E3FAF),
                                              ),
                                            )
                                          : SizedBox(
                                              width: (side - 20).clamp(60.0, 420.0),
                                              height: (side - 20).clamp(60.0, 420.0),
                                              child: const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.t?.t('card.front.tapToEnlarge') ?? 'Appuyez pour agrandir',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.emergencyContact != null) ...[
                            _backEmergency(),
                            const SizedBox(height: 8),
                          ],
                          if (widget.allergies.isNotEmpty) ...[
                            _backLabel(
                              widget.t?.t('card.front.criticalAllergies') ?? 'Allergies',
                              const Color(0xFFFCD34D),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                ...widget.allergies.take(4).map((a) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withAlpha(38),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      a,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  );
                                }),
                                if (widget.allergies.length > 4)
                                  Text(
                                    '+${widget.allergies.length - 4}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: AppColors.white.withAlpha(179),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (widget.chronicConditions.isNotEmpty) ...[
                            _backLabel(
                              widget.t?.t('card.front.conditions') ?? 'Conditions',
                              const Color(0xFF93C5FD),
                            ),
                            const SizedBox(height: 4),
                            ...widget.chronicConditions.take(4).map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.white.withAlpha(204),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 12,
                                    color: AppColors.white.withAlpha(179),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.t?.t('card.front.verifiedIdentity') ?? '',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white.withAlpha(179),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'TOSUMO',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.white.withAlpha(128),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backEmergency() {
    final ec = widget.emergencyContact!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFCA5A5).withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.heart,
            size: 14,
            color: const Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ec.name,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${ec.relationship} — ${ec.phone}',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.white.withAlpha(204),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }


  Widget _buildFlipButton() {
    return GestureDetector(
      onTap: _handleFlip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: _isFlipped ? 0.5 : 0,
              duration: const Duration(milliseconds: 500),
              child: Icon(
                LucideIcons.shieldCheck,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isFlipped ? (widget.t?.t('card.front.backToInfo') ?? '') : (widget.t?.t('card.front.viewQr') ?? ''),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _isFlipped ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                LucideIcons.chevronRight,
                size: 12,
                color: AppColors.mutedForeground.withAlpha(153),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlipContainer extends StatelessWidget {
  final bool isFlipped;
  final bool isFlipping;
  final Widget front;
  final Widget back;

  const _FlipContainer({
    required this.isFlipped,
    required this.isFlipping,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedFlip3D(
      isFlipped: isFlipped,
      front: front,
      back: back,
    );
  }
}

class _AnimatedFlip3D extends StatefulWidget {
  final bool isFlipped;
  final Widget front;
  final Widget back;

  const _AnimatedFlip3D({
    required this.isFlipped,
    required this.front,
    required this.back,
  });

  @override
  State<_AnimatedFlip3D> createState() => _AnimatedFlip3DState();
}

class _AnimatedFlip3DState extends State<_AnimatedFlip3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isFlipped) _controller.value = 1;
  }

  @override
  void didUpdateWidget(_AnimatedFlip3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 3.14159265;
        final isBack = _controller.value > 0.5;
        final scale = 1.0 - (_controller.value * 0.04);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..rotateY(angle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(isBack ? 3.14159265 : 0),
            child: isBack ? widget.back : widget.front,
          ),
        );
      },
    );
  }
}

class _CardWavePattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withAlpha(8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    for (var i = 0; i < 5; i++) {
      path.reset();
      final y = size.height * 0.2 + (i * size.height * 0.15);
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 2) {
        path.lineTo(
          x,
          y + (size.height * 0.04) * math.sin(x / size.width * 3.14159),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
