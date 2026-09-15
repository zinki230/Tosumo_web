import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/imaging_request.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';

class ImagingRequestsScreen extends ConsumerStatefulWidget {
  const ImagingRequestsScreen({super.key});

  @override
  ConsumerState<ImagingRequestsScreen> createState() => _ImagingRequestsScreenState();
}

class _ImagingRequestsScreenState extends ConsumerState<ImagingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';

  List<ImagingRequest> _imagingRequests = [];
  bool _loadingImaging = true;
  String? _imagingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadImaging();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImaging() async {
    setState(() => _loadingImaging = true);
    try {
      final requests = await ref.read(imagingRepositoryProvider).getAllImagingRequests(_doctorId);
      if (mounted) setState(() { _imagingRequests = requests; _loadingImaging = false; _imagingError = null; });
    } catch (e) {
      if (mounted) setState(() { _imagingError = ErrorMapper.fromException(e).message; _loadingImaging = false; });
    }
  }

  Future<void> _refresh() async => _loadImaging();

  Widget _buildPendingTab() {
    final pending = _loadingImaging || _imagingError != null
        ? 0
        : _imagingRequests.where((i) => i.status == 'pending').length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('En attente'),
        if (pending > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$pending',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }

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
              title: 'Imagerie médicale',
              subtitle: 'Gérez les demandes d\'imagerie',
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
                  Tab(
                    child: _buildPendingTab(),
                  ),
                  const Tab(text: 'Terminées'),
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
            _buildImagingList('pending'),
            _buildImagingList('completed'),
            _buildImagingList(null),
          ],
        ),
      ),
    );
  }

  Widget _buildImagingList(String? statusFilter) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: _loadingImaging
          ? const ListSkeleton(count: 4)
          : _imagingError != null
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
              : _buildImagingListContent(statusFilter),
    );
  }

  Widget _buildImagingListContent(String? statusFilter) {
    var filtered = List<ImagingRequest>.from(_imagingRequests);
    if (statusFilter == 'pending') {
      filtered = filtered.where((i) => i.status == 'pending').toList();
    } else if (statusFilter == 'completed') {
      filtered = filtered.where((i) => i.status == 'completed').toList();
    }
    filtered.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    if (filtered.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: LucideIcons.scan,
            message: 'Aucune demande d\'imagerie',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: filtered.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ImagingRequestCard(
          request: filtered[index],
          onRefresh: _refresh,
        ),
      ),
    );
  }

  void _showNewRequestSheet() {
    final patientSearchController = TextEditingController();
    final bodyPartController = TextEditingController();
    final notesController = TextEditingController();
    PatientSummary? selectedPatient;
    String selectedType = 'X-Ray';
    bool isSaving = false;

    final types = ['X-Ray', 'MRI', 'CT', 'Ultrasound'];

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
                'Nouvelle demande d\'imagerie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  child: _ImagingPatientSearchList(
                    query: patientSearchController.text,
                    onSelected: (p) => setSheetState(() => selectedPatient = p),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: "Type d'imagerie"),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setSheetState(() => selectedType = v ?? 'X-Ray'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyPartController,
                decoration: const InputDecoration(labelText: 'Partie du corps'),
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
                  onPressed: isSaving || selectedPatient == null || bodyPartController.text.isEmpty
                      ? null
                      : () async {
                          setSheetState(() => isSaving = true);
                          try {
                            final request = ImagingRequest(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              patientId: selectedPatient!.id,
                              doctorId: _doctorId,
                              consultationId: '',
                              imagingType: selectedType,
                              bodyPart: bodyPartController.text,
                              status: 'pending',
                              orderedAt: DateTime.now(),
                              notes: notesController.text,
                            );
                            await ref.read(imagingRepositoryProvider).createImagingRequest(request);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Demande d\'imagerie envoyée')),
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

class _ImagingPatientSearchList extends ConsumerStatefulWidget {
  final String query;
  final ValueChanged<PatientSummary> onSelected;

  const _ImagingPatientSearchList({required this.query, required this.onSelected});

  @override
  ConsumerState<_ImagingPatientSearchList> createState() => _ImagingPatientSearchListState();
}

class _ImagingPatientSearchListState extends ConsumerState<_ImagingPatientSearchList> {
  List<PatientSummary>? _patients;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_ImagingPatientSearchList oldWidget) {
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

class _ImagingRequestCard extends ConsumerStatefulWidget {
  final ImagingRequest request;
  final VoidCallback onRefresh;

  const _ImagingRequestCard({required this.request, required this.onRefresh});

  @override
  ConsumerState<_ImagingRequestCard> createState() => _ImagingRequestCardState();
}

class _ImagingRequestCardState extends ConsumerState<_ImagingRequestCard> {
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
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(LucideIcons.scan, size: 20, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.imagingType} - ${r.bodyPart}',
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
                _ImagingStatusBadge(status: r.status),
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
            _ImagingDetailRow(label: "Type d'imagerie", value: r.imagingType),
            const SizedBox(height: 6),
            _ImagingDetailRow(label: 'Partie du corps', value: r.bodyPart),
            if (r.findings.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ImagingDetailRow(label: 'Résultats', value: r.findings),
            ],
            if (r.impression.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ImagingDetailRow(label: 'Impression', value: r.impression),
            ],
            const SizedBox(height: 6),
            _ImagingDetailRow(label: 'Date', value: DateFormat('dd/MM/yyyy HH:mm').format(r.orderedAt)),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ImagingDetailRow(label: 'Notes', value: r.notes),
            ],
            const SizedBox(height: 12),
            _buildActions(r),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(ImagingRequest r) {
    if (r.status == 'pending') {
      return SizedBox(
        width: double.infinity, height: 36,
        child: ElevatedButton.icon(
          onPressed: () => _showReportDialog(r),
          icon: const Icon(LucideIcons.fileText, size: 16),
          label: const Text('Saisir le rapport', style: TextStyle(fontSize: 12)),
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

  void _showReportDialog(ImagingRequest r) {
    final findingsController = TextEditingController(text: r.findings);
    final impressionController = TextEditingController(text: r.impression);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rapport d\'imagerie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findingsController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Résultats'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: impressionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Impression'),
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
                  await ref.read(imagingRepositoryProvider).updateImagingResults(
                    r.id,
                    findings: findingsController.text,
                    impression: impressionController.text,
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

class _ImagingStatusBadge extends StatelessWidget {
  final String status;
  const _ImagingStatusBadge({required this.status});

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

class _ImagingDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ImagingDetailRow({required this.label, required this.value});

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
