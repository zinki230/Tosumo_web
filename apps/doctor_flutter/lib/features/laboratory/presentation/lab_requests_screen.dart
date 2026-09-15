import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';

class LabRequestsScreen extends ConsumerStatefulWidget {
  const LabRequestsScreen({super.key});

  @override
  ConsumerState<LabRequestsScreen> createState() => _LabRequestsScreenState();
}

class _LabRequestsScreenState extends ConsumerState<LabRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  List<LabRequest> _labRequests = [];
  bool _loadingLab = true;
  String? _labError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLab();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLab() async {
    setState(() => _loadingLab = true);
    try {
      final requests = await ref.read(laboratoryRepositoryProvider).getAllLabRequests(_doctorId);
      if (mounted) setState(() { _labRequests = requests; _loadingLab = false; _labError = null; });
    } catch (e) {
      if (mounted) setState(() { _labError = ErrorMapper.fromException(e).message; _loadingLab = false; });
    }
  }

  Future<void> _refresh() async => _loadLab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewRequestSheet(),
        backgroundColor: AppColors.primary,
        child: const Icon(LucideIcons.plus, color: AppColors.white),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Analyses laboratoire',
              subtitle: 'Gérez les demandes d\'analyses',
              showBack: false,
              showNotification: true,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.mutedForeground,
                tabs: [
                  Tab(child: _buildPendingTab()),
                  Tab(child: _buildCompletedTab()),
                  const Tab(text: 'Toutes'),
                ],
              ),
              color: AppColors.background,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildLabList('pending'),
            _buildLabList('completed'),
            _buildLabList(null),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('En attente'),
        if (!_loadingLab && _labError == null && _labRequests.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '${_labRequests.length}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedTab() {
    final completed = _loadingLab || _labError != null
        ? 0
        : _labRequests.where((l) => l.status == 'completed').length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Terminées'),
        if (completed > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$completed',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabList(String? statusFilter) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: _loadingLab
          ? const ListSkeleton(count: 4)
          : _labError != null
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: LucideIcons.alertCircle,
                      message: 'Erreur de chargement',
                      actionLabel: 'Réessayer',
                      onAction: _refresh,
                    ),
                  ],
                )
              : _buildLabListContent(statusFilter),
    );
  }

  Widget _buildLabListContent(String? statusFilter) {
    var filtered = List<LabRequest>.from(_labRequests);
    if (statusFilter == 'pending') {
      filtered = filtered.where((l) => l.status == 'pending').toList();
    } else if (statusFilter == 'completed') {
      filtered = filtered.where((l) => l.status == 'completed').toList();
    }
    filtered.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    if (filtered.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const EmptyState(
            icon: LucideIcons.beaker,
            message: 'Aucune demande d\'analyse',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: filtered.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _LabRequestCard(
          request: filtered[index],
          onRefresh: _refresh,
        ),
      ),
    );
  }

  void _showNewRequestSheet() {
    final patientSearchController = TextEditingController();
    final testNameController = TextEditingController();
    final testTypeController = TextEditingController();
    final notesController = TextEditingController();
    PatientSummary? selectedPatient;
    bool isSaving = false;

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
              const Text(
                'Nouvelle demande d\'analyse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: patientSearchController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher un patient',
                  hintText: 'Nom ou ID du patient',
                ),
                onChanged: (v) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              if (selectedPatient != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.user, size: 16, color: AppColors.primary),
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
                  child: _LabPatientSearchList(
                    query: patientSearchController.text,
                    onSelected: (p) => setSheetState(() => selectedPatient = p),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: testNameController,
                decoration: const InputDecoration(labelText: 'Nom du test'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: testTypeController,
                decoration: const InputDecoration(labelText: 'Type de test'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving || selectedPatient == null || testNameController.text.isEmpty
                      ? null
                      : () async {
                          setSheetState(() => isSaving = true);
                          try {
                            final request = LabRequest(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              patientId: selectedPatient!.id,
                              doctorId: _doctorId,
                              consultationId: '',
                              testName: testNameController.text,
                              testType: testTypeController.text,
                              status: 'pending',
                              orderedAt: DateTime.now(),
                              notes: notesController.text,
                            );
                            await ref.read(laboratoryRepositoryProvider).createLabRequest(request);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Analyse demandée')),
                              );
                            }
                            _refresh();
                          } finally {
                            if (sheetContext.mounted) setSheetState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Text('Créer la demande'),
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

class _LabPatientSearchList extends ConsumerStatefulWidget {
  final String query;
  final ValueChanged<PatientSummary> onSelected;

  const _LabPatientSearchList({required this.query, required this.onSelected});

  @override
  ConsumerState<_LabPatientSearchList> createState() => _LabPatientSearchListState();
}

class _LabPatientSearchListState extends ConsumerState<_LabPatientSearchList> {
  List<PatientSummary>? _patients;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_LabPatientSearchList oldWidget) {
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

class _LabRequestCard extends ConsumerStatefulWidget {
  final LabRequest request;
  final VoidCallback onRefresh;

  const _LabRequestCard({required this.request, required this.onRefresh});

  @override
  ConsumerState<_LabRequestCard> createState() => _LabRequestCardState();
}

class _LabRequestCardState extends ConsumerState<_LabRequestCard> {
  bool _isExpanded = false;
  PatientDetail? _patient;
  bool _loadingPatient = true;
  String? _patientError;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() => _loadingPatient = true);
    try {
      final patient = await ref.read(patientRepositoryProvider).getPatientById(widget.request.patientId);
      if (mounted) setState(() { _patient = patient; _loadingPatient = false; _patientError = null; });
    } catch (e) {
      if (mounted) setState(() { _patientError = e.toString(); _loadingPatient = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Container(
                  width: 4, height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor(r.status),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(LucideIcons.beaker, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.testName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 2),
                      _loadingPatient
                          ? const Text('...', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground))
                          : _patientError != null || _patient == null
                              ? Text(r.patientId, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground))
                              : Text(
                                  _patient!.name,
                                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                                ),
                    ],
                  ),
                ),
                _StatusBadge(status: r.status),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18, color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DetailRow(label: 'Type', value: r.testType),
            if (r.referenceRange.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(label: 'Référence', value: r.referenceRange),
            ],
            if (r.resultValue.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(label: 'Résultat', value: r.resultValue),
            ],
            if (r.interpretation.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(label: 'Interprétation', value: r.interpretation),
            ],
            const SizedBox(height: 6),
            _DetailRow(
              label: 'Date',
              value: DateFormat('dd/MM/yyyy HH:mm').format(r.orderedAt),
            ),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              _DetailRow(label: 'Notes', value: r.notes),
            ],
            const SizedBox(height: 12),
            _buildActions(r),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(LabRequest r) {
    if (r.status == 'pending') {
      return SizedBox(
        width: double.infinity, height: 36,
        child: ElevatedButton.icon(
          onPressed: () => _showResultsDialog(r),
          icon: const Icon(LucideIcons.fileInput, size: 16),
          label: const Text('Saisir les résultats', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showResultsDialog(LabRequest r) {
    final resultController = TextEditingController(text: r.resultValue);
    final interpretationController = TextEditingController(text: r.interpretation);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Résultats d\'analyse'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resultController,
                decoration: const InputDecoration(labelText: 'Valeur du résultat'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interpretationController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Interprétation'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: AppColors.mutedForeground)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                try {
                  await ref.read(laboratoryRepositoryProvider).updateLabResults(
                    r.id,
                    resultValue: resultController.text,
                    interpretation: interpretationController.text,
                    status: 'completed',
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  widget.onRefresh();
                } finally {
                  if (dialogContext.mounted) setDialogState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: isSaving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.accent;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.destructive;
      default: return AppColors.mutedForeground;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.accent;
        label = 'En attente';
      case 'completed':
        color = AppColors.success;
        label = 'Terminé';
      case 'cancelled':
        color = AppColors.destructive;
        label = 'Annulé';
      default:
        color = AppColors.mutedForeground;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground)),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  _TabBarDelegate(this.tabBar, {required this.color});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
