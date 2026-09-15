import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/search_input.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/avatar.dart';

const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String get _doctorId => ref.read(currentDoctorIdProvider) ?? '';
  String _selectedFilter = 'Name';
  String _searchQuery = '';
  List<PatientSummary> _searchResults = [];
  List<PatientSummary> _recentPatients = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _loadingRecent = true;
  String? _recentError;

  // Attribute filters
  String? _fBlood;
  String? _fGender;
  bool? _fVerified;
  String? _fCondition;

  final List<String> _filters = ['Name', 'Medical ID', 'Phone', 'National ID'];

  @override
  void initState() {
    super.initState();
    _loadRecentPatients();
  }

  List<PatientSummary> get _source =>
      _searchQuery.isNotEmpty ? _searchResults : _recentPatients;

  int get _activeFilterCount =>
      (_fBlood != null ? 1 : 0) +
      (_fGender != null ? 1 : 0) +
      (_fVerified != null ? 1 : 0) +
      (_fCondition != null ? 1 : 0);

  List<PatientSummary> get _visiblePatients =>
      _source.where((p) {
        if (_fBlood != null && p.bloodType != _fBlood) return false;
        if (_fGender != null && p.gender != _fGender) return false;
        if (_fVerified != null && p.verified != _fVerified) return false;
        if (_fCondition != null && !p.conditions.contains(_fCondition)) return false;
        return true;
      }).toList();

  List<String> get _availableConditions {
    final set = <String>{};
    for (final p in _source) {
      for (final c in p.conditions) {
        set.add(c);
      }
    }
    return set.toList()..sort();
  }

  Future<void> _loadRecentPatients() async {
    setState(() { _loadingRecent = true; _recentError = null; });
    try {
      final patients = await ref.read(patientRepositoryProvider).getRecentPatients(_doctorId);
      if (mounted) setState(() { _recentPatients = patients; _loadingRecent = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingRecent = false; _recentError = ErrorMapper.fromException(e).message; });
    }
  }

  Future<void> _refresh() async {
    await _loadRecentPatients();
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    ref.read(patientRepositoryProvider).searchPatients(value).then((results) {
      if (mounted) {
        setState(() {
          _searchResults = results;
          _hasSearched = true;
          _isSearching = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  void _clearFilters() => setState(() {
    _fBlood = null;
    _fGender = null;
    _fVerified = null;
    _fCondition = null;
  });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = _visiblePatients;
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
                title: 'Patients',
                subtitle: 'Rechercher et gérer vos patients',
                showBack: false,
                showNotification: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: SearchInput(
                  value: _searchQuery,
                  onChanged: _onSearchChanged,
                  placeholder: 'Rechercher un patient...',
                  onFilterClick: () => _showFilterPicker(),
                  filterBadge: _activeFilterCount,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f, style: const TextStyle(fontSize: 12)),
                          selected: _selectedFilter == f,
                          onSelected: (_) => setState(() => _selectedFilter = f),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_activeFilterCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_fBlood != null)
                        _activeChip('Groupe: $_fBlood', () => setState(() => _fBlood = null)),
                      if (_fGender != null)
                        _activeChip('Sexe: ${_fGender == 'Male' ? 'Homme' : 'Femme'}',
                            () => setState(() => _fGender = null)),
                      if (_fVerified != null)
                        _activeChip(_fVerified! ? 'Vérifié' : 'Non vérifié',
                            () => setState(() => _fVerified = null)),
                      if (_fCondition != null)
                        _activeChip(_fCondition!, () => setState(() => _fCondition = null)),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(LucideIcons.x, size: 14),
                        label: const Text('Effacer', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              _buildBody(patients),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/scan'),
        backgroundColor: AppColors.primary,
        child: const Icon(LucideIcons.qrCode, color: AppColors.white),
      ),
    );
  }

  Widget _buildBody(List<PatientSummary> patients) {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: ListSkeleton(count: 3),
      );
    }
    if (_hasSearched) {
      if (patients.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: EmptyState(icon: LucideIcons.searchX, message: 'Aucun patient trouvé'),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${patients.length} résultat(s)',
                style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
          ),
          ...patients.map((p) => _PatientCard(patient: p)),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Patients récents'),
          if (_loadingRecent)
            const ListSkeleton(count: 3)
          else if (_recentError != null)
            EmptyState(
              icon: LucideIcons.alertCircle,
              message: 'Erreur de chargement',
              actionLabel: 'Réessayer',
              onAction: _loadRecentPatients,
            )
          else if (_recentPatients.isEmpty)
            const EmptyState(icon: LucideIcons.users, message: 'Aucun patient récent')
          else if (patients.isEmpty)
            const EmptyState(
              icon: LucideIcons.filterX,
              message: 'Aucun patient ne correspond aux filtres',
            )
          else
            Column(children: patients.map((p) => _PatientCard(patient: p)).toList()),
        ],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: GestureDetector(
        onTap: onRemove,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            const SizedBox(width: 6),
            const Icon(LucideIcons.x, size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showFilterPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtrer les patients',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                    ),
                    if (_activeFilterCount > 0)
                      TextButton(
                        onPressed: () {
                          _clearFilters();
                          setSheet(() {});
                        },
                        child: const Text('Effacer tout'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Groupe sanguin', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bloodGroups.map((b) => FilterChip(
                    label: Text(b),
                    selected: _fBlood == b,
                    onSelected: (_) => setSheet(() => _fBlood = _fBlood == b ? null : b),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Sexe', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _sheetChoice('Homme', _fGender == 'Male',
                        () => setSheet(() => _fGender = _fGender == 'Male' ? null : 'Male')),
                    _sheetChoice('Femme', _fGender == 'Female',
                        () => setSheet(() => _fGender = _fGender == 'Female' ? null : 'Female')),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Statut', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _sheetChoice('Vérifié', _fVerified == true,
                        () => setSheet(() => _fVerified = _fVerified == true ? null : true)),
                    _sheetChoice('Non vérifié', _fVerified == false,
                        () => setSheet(() => _fVerified = _fVerified == false ? null : false)),
                  ],
                ),
                if (_availableConditions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Maladie / condition', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableConditions.map((c) => FilterChip(
                      label: Text(c),
                      selected: _fCondition == c,
                      onSelected: (_) => setSheet(() => _fCondition = _fCondition == c ? null : c),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetChoice(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final PatientSummary patient;

  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 4),
      child: AppCard(
        onTap: () => context.go('/patient/${patient.id}'),
        child: Row(
          children: [
            Avatar(
              initials: _getInitials(patient.name),
              photoUrl: patient.photoUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      if (patient.verified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text(
                            'Vérifié',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.mutedForeground.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text(
                            'Non vérifié',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          patient.nationalId,
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          patient.bloodType,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        patient.gender == 'Male' ? LucideIcons.mars : LucideIcons.venus,
                        size: 12,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        patient.gender == 'Male' ? 'Homme' : 'Femme',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  if (patient.conditions.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      patient.conditions.join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (patient.lastVisit != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(LucideIcons.calendar, size: 10, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(
                          'Dernière visite: ${DateFormat('dd/MM/yyyy').format(patient.lastVisit!)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                patient.isFavorite ? LucideIcons.star : LucideIcons.star,
                size: 20,
                color: patient.isFavorite ? AppColors.gold : AppColors.mutedForeground,
              ),
              onPressed: () {
                ref.read(patientRepositoryProvider).toggleFavorite(
                  patient.id,
                  !patient.isFavorite,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }
}
