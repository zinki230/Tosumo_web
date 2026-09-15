import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../domain/models/appointment.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/empty_state.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? get _doctorId => ref.read(currentDoctorIdProvider);

  Map<String, dynamic>? _stats;
  List<Appointment>? _appointments;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doctorId = _doctorId ?? '';
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ref.read(analyticsRepositoryProvider).getDoctorStats(doctorId),
        ref.read(appointmentRepositoryProvider).getAppointments(doctorId, limit: 200),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _appointments = results[1] as List<Appointment>;
          _loading = false;
        });
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() { _error = failure.message; _loading = false; });
    }
  }

  Future<void> _refresh() async => _loadData();

  List<Map<String, dynamic>> _diagnosisDistribution() {
    final counts = <String, int>{};
    for (final a in _appointments ?? <Appointment>[]) {
      final key = a.type.isEmpty ? 'Consultation' : a.type;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .map((e) => {'diagnosis': e.key, 'count': e.value})
        .toList();
  }

  Map<String, dynamic> _completion() {
    final total = _appointments?.length ?? 0;
    final completed = _appointments?.where((a) => a.status == 'completed').length ?? 0;
    final cancelled = _appointments?.where((a) => a.status == 'cancelled').length ?? 0;
    final noShow = _appointments?.where((a) => a.status == 'no-show').length ?? 0;
    return {
      'total': total,
      'completed': completed,
      'cancelled': cancelled,
      'noShow': noShow,
    };
  }

  List<Map<String, dynamic>> _weeklyTrends() {
    final now = DateTime.now();
    final weeks = <String, int>{};
    for (final a in _appointments ?? <Appointment>[]) {
      final d = a.date;
      final diff = now.difference(DateTime(d.year, d.month, d.day)).inDays;
      final weekIndex = (diff / 7).ceil();
      if (weekIndex > 8) continue;
      final label = 'S-${8 - weekIndex}';
      weeks[label] = (weeks[label] ?? 0) + 1;
    }
    final entries = weeks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => {'week': e.key, 'appointments': e.value})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Statistiques',
                subtitle: 'Analyse de votre activité',
                showBack: false,
                showNotification: true,
              ),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(2, (_) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Skeleton(height: 80, borderRadius: AppRadius.lg),
                          ),
                        )),
                      ),
                      SizedBox(height: 16),
                      Skeleton(height: 180, borderRadius: AppRadius.xl),
                    ],
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                  child: EmptyState(
                    icon: LucideIcons.alertCircle,
                    message: _error!,
                    actionLabel: 'Réessayer',
                    onAction: _refresh,
                  ),
                )
              else
                _buildContent(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats ?? const {};
    final completion = _completion();
    final total = completion['total'] as int;
    final completed = completion['completed'] as int;
    final cancelled = completion['cancelled'] as int;
    final noShow = completion['noShow'] as int;
    final others = total - completed - cancelled - noShow;
    final completionRate = total > 0 ? (completed / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _StatTile(
                    icon: LucideIcons.calendarDays,
                    label: 'Rendez-vous',
                    value: '${stats['totalAppointments'] ?? total}',
                    color: AppColors.primary,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(
                    icon: LucideIcons.checkCircle,
                    label: 'Complétés',
                    value: '${stats['completedAppointments'] ?? completed}',
                    color: AppColors.success,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatTile(
                    icon: LucideIcons.xCircle,
                    label: 'Annulés',
                    value: '${stats['cancelledAppointments'] ?? cancelled}',
                    color: AppColors.destructive,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(
                    icon: LucideIcons.star,
                    label: 'Note moyenne',
                    value: (stats['averageRating'] as num?)?.toStringAsFixed(1) ?? '—',
                    color: AppColors.gold,
                  )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Taux de complétion'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        Flexible(
                          flex: total > 0 ? (completed / total * 100).round() : 0,
                          child: Container(color: AppColors.success),
                        ),
                        Flexible(
                          flex: total > 0 ? (cancelled / total * 100).round() : 0,
                          child: Container(color: AppColors.destructive),
                        ),
                        Flexible(
                          flex: total > 0 ? (noShow / total * 100).round() : 0,
                          child: Container(color: AppColors.alert),
                        ),
                        Flexible(
                          flex: total > 0 ? (others / total * 100).round() : 1,
                          child: Container(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _LegendItem(color: AppColors.success, label: 'Complétés', value: '$completed'),
                    const SizedBox(width: 16),
                    _LegendItem(color: AppColors.destructive, label: 'Annulés', value: '$cancelled'),
                    const SizedBox(width: 16),
                    _LegendItem(color: AppColors.alert, label: 'Absents', value: '$noShow'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendItem(color: AppColors.muted, label: 'Autres', value: '$others'),
                    const Spacer(),
                    Text(
                      '${completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: const SectionHeader(title: 'Répartition par type de consultation'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: _buildDistribution(),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: const SectionHeader(title: 'Rendez-vous par semaine'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: _buildTrends(),
        ),
      ],
    );
  }

  Widget _buildDistribution() {
    final diagnoses = _diagnosisDistribution();
    if (diagnoses.isEmpty) {
      return const AppCard(
        child: Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucune donnée', style: TextStyle(color: AppColors.mutedForeground, fontSize: 14)),
        )),
      );
    }
    final maxCount = diagnoses.fold<int>(0, (max, d) {
      final c = d['count'] as int? ?? 0;
      return c > max ? c : max;
    });
    return AppCard(
      child: Column(
        children: diagnoses.map((d) {
          final label = d['diagnosis'] as String? ?? 'Inconnu';
          final count = d['count'] as int? ?? 0;
          final percentage = maxCount > 0 ? count / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.muted,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrends() {
    final trends = _weeklyTrends();
    if (trends.isEmpty) {
      return const AppCard(
        child: Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucune donnée', style: TextStyle(color: AppColors.mutedForeground, fontSize: 14)),
        )),
      );
    }
    final maxVal = trends.fold<int>(0, (max, t) {
      final count = t['appointments'] as int? ?? 0;
      return count > max ? count : max;
    });
    return AppCard(
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(trends.length, (i) {
            final val = trends[i]['appointments'] as int? ?? 0;
            final height = maxVal > 0 ? (val / maxVal) * 120.0 : 0.0;
            final label = trends[i]['week'] as String? ?? '';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$val', style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                    const SizedBox(height: 2),
                    Container(
                      height: height.clamp(4.0, 120.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.foreground)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.foreground)),
      ],
    );
  }
}
