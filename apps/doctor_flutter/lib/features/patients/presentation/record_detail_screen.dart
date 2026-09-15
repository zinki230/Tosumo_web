import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import 'record_card.dart';

class RecordDetailScreen extends StatelessWidget {
  final dynamic record;
  final RecordType type;

  const RecordDetailScreen({
    required this.record,
    required this.type,
    super.key,
  });

  static String titleFor(RecordType type) {
    return switch (type) {
      RecordType.consultation => 'Consultation',
      RecordType.lab => 'Analyse de laboratoire',
      RecordType.imaging => 'Imagerie médicale',
      RecordType.prescription => 'Ordonnance',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.foreground),
          onPressed: () => context.pop(),
        ),
        title: Text(
          titleFor(type),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.foreground),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(child: RecordDetailContent(record: record, type: type)),
      ),
    );
  }
}
