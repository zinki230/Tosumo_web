import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/emergency_session.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';
  Timer? _timer;
  int _elapsedSeconds = 0;

  EmergencySession? _activeSession;
  List<EmergencySession> _history = [];
  bool _loadingHistory = true;

  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadActiveSession(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadActiveSession() async {
    try {
      final session = await ref.read(emergencyRepositoryProvider).getActiveSession(_doctorId);
      if (mounted) setState(() { _activeSession = session; });
    } catch (e) {
      if (mounted) setState(() { });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await ref.read(emergencyRepositoryProvider).getEmergencyHistory(_doctorId);
      if (mounted) setState(() { _history = history; _loadingHistory = false; _historyError = null; });
    } catch (e) {
      if (mounted) setState(() { _historyError = ErrorMapper.fromException(e).message; _loadingHistory = false; });
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _refresh() async => _loadData();

  String get _formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                  top: MediaQuery.of(context).padding.top + 20,
                  bottom: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.destructive, Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.white),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.ambulance, size: 14, color: AppColors.white),
                              SizedBox(width: 6),
                              Text('Mode urgence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Urgences',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cas urgents - Intervention rapide',
                      style: TextStyle(fontSize: 14, color: AppColors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              if (_activeSession != null)
                _buildActiveSessionBanner(_activeSession!),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showStartEmergencyDialog(),
                    icon: const Icon(LucideIcons.ambulance, size: 20),
                    label: const Text('Démarrer une consultation d\'urgence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 4,
                      shadowColor: AppColors.destructive.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final patientId = _activeSession?.patientId;
                      if (patientId != null) context.go('/patient/$patientId');
                    },
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('Voir le dossier médical complet', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: const SectionHeader(title: 'Historique des sessions d\'urgence'),
              ),
              if (_loadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: ListSkeleton(count: 3),
                )
              else if (_historyError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: EmptyState(
                    icon: LucideIcons.alertCircle,
                    message: 'Erreur de chargement',
                    actionLabel: 'Réessayer',
                    onAction: _refresh,
                  ),
                )
              else if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: EmptyState(
                    icon: LucideIcons.ambulance,
                    message: 'Aucun historique d\'urgence',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: Column(
                    children: () {
                      final sorted = List<EmergencySession>.from(_history)
                        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
                      return sorted.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EmergencyHistoryCard(session: s),
                      )).toList();
                    }(),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionBanner(EmergencySession session) {
    final summary = session.patientSummary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.activity, size: 12, color: AppColors.destructive),
                    SizedBox(width: 6),
                    Text('Session active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.destructive)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formattedTime,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.destructive, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    summary.bloodType,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.destructive),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    const SizedBox(height: 4),
                    Text('${summary.age} ans, ${summary.gender}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    const SizedBox(height: 8),
                    if (summary.allergies.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4, runSpacing: 2,
                        children: summary.allergies.map((a) => Chip(
                          label: Text(a, style: const TextStyle(fontSize: 10, color: AppColors.white)),
                          backgroundColor: AppColors.alert,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        )).toList(),
                      ),
                    ],
                    if (summary.emergencyContact != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.phone, size: 14, color: AppColors.mutedForeground),
                          const SizedBox(width: 6),
                          Text(summary.emergencyContact!.name, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          const SizedBox(width: 4),
                          Text(summary.emergencyContact!.phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                          const SizedBox(width: 4),
                          Icon(LucideIcons.phoneCall, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ],
                    if (summary.chronicConditions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...summary.chronicConditions.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $c', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (summary.chiefComplaint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Motif principal', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  const SizedBox(height: 4),
                  Text(summary.chiefComplaint, style: const TextStyle(fontSize: 13, color: AppColors.foreground)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await ref.read(emergencyRepositoryProvider).completeEmergencySession(session.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session d\'urgence terminée')),
                          );
                        }
                        _refresh();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ErrorMapper.fromException(e).message)),
                          );
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.checkCircle, size: 16),
                    label: const Text('Terminer', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStartEmergencyDialog() {
    final patientSearchController = TextEditingController();
    final justificationController = TextEditingController();
    PatientSummary? selectedPatient;
    bool isStarting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(LucideIcons.ambulance, size: 20, color: AppColors.destructive),
                  SizedBox(width: 8),
                  Text('Nouvelle urgence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: patientSearchController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher un patient',
                  hintText: 'Nom ou ID du patient',
                ),
              ),
              const SizedBox(height: 12),
              if (selectedPatient != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.user, size: 16, color: AppColors.destructive),
                      const SizedBox(width: 8),
                      Expanded(child: Text(selectedPatient!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      GestureDetector(
                        onTap: () => setSheetState(() => selectedPatient = null),
                        child: const Icon(LucideIcons.x, size: 16, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: _PatientSearchList(
                    query: patientSearchController.text,
                    onSelected: (p) => setSheetState(() => selectedPatient = p),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: justificationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Justification',
                  hintText: 'Motif de la consultation d\'urgence...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isStarting || selectedPatient == null || justificationController.text.isEmpty
                      ? null
                      : () async {
                          setSheetState(() => isStarting = true);
                          try {
                            await ref.read(emergencyRepositoryProvider).startEmergencySession(
                              selectedPatient!.id,
                              _doctorId,
                              justificationController.text,
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session d\'urgence démarrée')),
                              );
                            }
                            _refresh();
                            _startTimerIfNeeded();
                          } catch (e) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ErrorMapper.fromException(e).message)),
                              );
                            }
                          } finally {
                            if (sheetContext.mounted) setSheetState(() => isStarting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isStarting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Text('Démarrer la session d\'urgence'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientSearchList extends ConsumerStatefulWidget {
  final String query;
  final ValueChanged<PatientSummary> onSelected;

  const _PatientSearchList({required this.query, required this.onSelected});

  @override
  ConsumerState<_PatientSearchList> createState() => _PatientSearchListState();
}

class _PatientSearchListState extends ConsumerState<_PatientSearchList> {
  List<PatientSummary>? _patients;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_PatientSearchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) _search();
  }

  Future<void> _search() async {
    if (widget.query.isEmpty) {
      setState(() { _patients = null; _loading = false; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final patients = await ref.read(patientRepositoryProvider).searchPatients(widget.query);
      if (mounted) setState(() { _patients = patients; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return const Center(child: Text('Erreur', style: TextStyle(color: AppColors.destructive)));

    final patients = _patients ?? [];
    final filtered = patients.where((p) =>
      p.name.toLowerCase().contains(widget.query.toLowerCase()) ||
      p.nationalId.contains(widget.query)
    ).toList();
    if (filtered.isEmpty) {
      return const Center(child: Text('Aucun patient trouvé', style: TextStyle(color: AppColors.mutedForeground)));
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => ListTile(
        dense: true,
        title: Text(filtered[i].name, style: const TextStyle(fontSize: 14)),
        subtitle: Text(filtered[i].nationalId, style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
        onTap: () => widget.onSelected(filtered[i]),
      ),
    );
  }
}

class _EmergencyHistoryCard extends StatelessWidget {
  final EmergencySession session;

  const _EmergencyHistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final summary = session.patientSummary;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: session.status == 'active'
                  ? AppColors.destructive.withValues(alpha: 0.1)
                  : AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              session.status == 'active' ? LucideIcons.activity : LucideIcons.checkCircle,
              color: session.status == 'active' ? AppColors.destructive : AppColors.mutedForeground,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(session.startedAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: session.status == 'active'
                  ? AppColors.destructive.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              session.status == 'active' ? 'Actif' : 'Terminé',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: session.status == 'active' ? AppColors.destructive : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
