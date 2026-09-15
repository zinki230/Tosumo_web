import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';

enum BrandLogoSize { sm, md, lg }

class BrandLogo extends ConsumerWidget {
  final BrandLogoSize size;
  final bool showTagline;

  const BrandLogo({
    super.key,
    this.size = BrandLogoSize.md,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));

    final logoHeight = switch (size) {
      BrandLogoSize.sm => 48.0,
      BrandLogoSize.md => 72.0,
      BrandLogoSize.lg => 96.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/TOSUMO.png',
          height: logoHeight,
          fit: BoxFit.contain,
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            locAsync.asData?.value.t('app.tagline') ?? '',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.cardBlueMid,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
