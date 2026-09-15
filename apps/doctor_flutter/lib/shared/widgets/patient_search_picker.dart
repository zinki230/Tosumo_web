import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../core/data/repositories/repository_providers.dart';
import 'avatar.dart';
import 'empty_state.dart';

class PatientSearchPicker extends ConsumerStatefulWidget {
  final void Function(PatientSummary patient) onSelected;
  final String hint;

  const PatientSearchPicker({
    super.key,
    required this.onSelected,
    this.hint = 'Rechercher un patient...',
  });

  @override
  ConsumerState<PatientSearchPicker> createState() => _PatientSearchPickerState();
}

class _PatientSearchPickerState extends ConsumerState<PatientSearchPicker> {
  final TextEditingController _controller = TextEditingController();
  List<PatientSummary> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    ref.read(patientRepositoryProvider).searchPatients(query).then((results) {
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }).catchError((Object _) {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                _isSearching ? LucideIcons.loader : LucideIcons.search,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              hintText: widget.hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_hasSearched && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: EmptyState(
              icon: LucideIcons.searchX,
              message: 'Aucun patient trouvé',
            ),
          )
        else if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _results.take(5).map((p) => ListTile(
                dense: true,
                leading: Avatar(
                  initials: _initials(p.name),
                  photoUrl: p.photoUrl,
                  size: 36,
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                subtitle: Text(
                  p.nationalId,
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                ),
                onTap: () {
                  _controller.clear();
                  setState(() {
                    _results = [];
                    _hasSearched = false;
                  });
                  widget.onSelected(p);
                },
              )).toList(),
            ),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }
}