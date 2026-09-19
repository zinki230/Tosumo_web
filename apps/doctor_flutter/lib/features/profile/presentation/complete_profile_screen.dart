import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../core/network/doctor_api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/doctor.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _cityController = TextEditingController();
  final _hospitalController = TextEditingController();
  
  // Multi-select
  final List<String> _selectedLanguages = [];
  final List<String> _selectedCredentials = [];
  
  bool _saving = false;
  String? _error;
  bool _loadingInstitutions = false;
  List<Map<String, dynamic>> _institutions = [];
  String? _selectedInstitutionId;

  final List<String> _availableLanguages = [
    'Français',
    'Anglais',
    'Duala',
    'Ewondo',
    'Fulfulde',
    'Bamun',
    'Bassa',
  ];

  final List<String> _availableCredentials = [
    'Doctorat en Médecine (MD)',
    'Diplôme d\'Études Spécialisées (DES)',
    'Master en Santé Publique',
    'Chirurgie Générale',
    'Pédiatrie',
    'Gynécologie-Obstétrique',
    'Cardiologie',
    'Neurologie',
  ];

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() => _loadingInstitutions = true);
    try {
      final response = await ref.read(apiClientProvider).dio.get(DoctorApiEndpoints.institutions);
      final items = (response.data as List).whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _institutions = items;
        _loadingInstitutions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMapper.fromException(e).message;
        _loadingInstitutions = false;
      });
    }
  }

  String get _selectedInstitutionName {
    final selectedId = _selectedInstitutionId;
    if (selectedId == null) return '';
    for (final institution in _institutions) {
      if (institution['id'] == selectedId) {
        return institution['name'] as String? ?? '';
      }
    }
    return '';
  }
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _specialtyController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _consultationFeeController.dispose();
    _experienceYearsController.dispose();
    _cityController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInstitutionId == null) {
      setState(() => _error = 'Veuillez selectionner un etablissement');
      return;
    }
    
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      
      // Create a doctor profile with available fields
      final doctor = Doctor(
        id: '', // Will be set by backend
        name: fullName,
        specialty: _specialtyController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        hospitalId: _selectedInstitutionId!,
        hospitalName: _selectedInstitutionName,
        photoUrl: '',
        credentials: _selectedCredentials,
        languages: _selectedLanguages,
        rating: 0.0,
        reviewCount: 0,
        isAvailable: true,
        expertise: [],
        workingHours: [],
        createdAt: DateTime.now(),
      );

      final result =
          await ref.read(doctorRepositoryProvider).updateProfile(doctor);
      
      // Update auth state
      ref.read(authProvider.notifier).refreshDoctor(result);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil complété avec succès')),
        );
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        setState(() {
          _error = failure.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compléter mon profil'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.foreground,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle,
                          color: AppColors.destructive, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.destructive,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error != null) const SizedBox(height: 16),
              
              // Personal Information
              _buildSection(
                'Informations personnelles',
                LucideIcons.user,
                [
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'Prénom *',
                    icon: LucideIcons.user,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Nom *',
                    icon: LucideIcons.user,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Téléphone *',
                    icon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email *',
                    icon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Champ requis';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v!)) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Professional Information
              _buildSection(
                'Informations professionnelles',
                LucideIcons.stethoscope,
                [
                  _buildTextField(
                    controller: _specialtyController,
                    label: 'Spécialité *',
                    icon: LucideIcons.stethoscope,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                  _buildTextField(
                    controller: _licenseNumberController,
                    label: 'Numéro de licence *',
                    icon: LucideIcons.badgeCheck,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                  _buildTextField(
                    controller: _experienceYearsController,
                    label: 'Années d\'expérience',
                    icon: LucideIcons.calendar,
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _consultationFeeController,
                    label: 'Frais de consultation (FCFA)',
                    icon: LucideIcons.coins,
                    keyboardType: TextInputType.number,
                  ),
                  _buildInstitutionField(),
                  _buildTextField(
                    controller: _cityController,
                    label: 'Ville *',
                    icon: LucideIcons.mapPin,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bio
              _buildSection(
                'Biographie',
                LucideIcons.fileText,
                [
                  _buildTextField(
                    controller: _bioController,
                    label: 'Parlez de vous et de votre pratique',
                    icon: LucideIcons.fileText,
                    maxLines: 4,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Languages
              _buildMultiSelectSection(
                'Langues parlées',
                LucideIcons.languages,
                _availableLanguages,
                _selectedLanguages,
              ),

              const SizedBox(height: 24),

              // Credentials
              _buildMultiSelectSection(
                'Diplômes et certifications',
                LucideIcons.graduationCap,
                _availableCredentials,
                _selectedCredentials,
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Enregistrer mon profil',
                onPressed: _saving ? null : _save,
                loading: _saving,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMultiSelectSection(
    String title,
    IconData icon,
    List<String> options,
    List<String> selected,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  });
                },
                backgroundColor: AppColors.card,
                selectedColor: AppColors.primary.withValues(alpha: 0.1),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.foreground,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: 1,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedInstitutionId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Etablissement/Hopital *',
                prefixIcon: const Icon(LucideIcons.building2, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.card,
              ),
              hint: Text(_loadingInstitutions ? 'Chargement...' : 'Selectionner un centre'),
              items: _institutions.map((institution) {
                final name = institution['name'] as String? ?? 'Centre sans nom';
                final city = institution['city'] as String?;
                return DropdownMenuItem<String>(
                  value: institution['id'] as String,
                  child: Text(city == null || city.isEmpty ? name : '$name - $city'),
                );
              }).toList(),
              onChanged: _loadingInstitutions
                  ? null
                  : (value) {
                      setState(() {
                        _selectedInstitutionId = value;
                        _hospitalController.text = _selectedInstitutionName;
                      });
                    },
              validator: (value) => value == null ? 'Champ requis' : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            width: 56,
            child: IconButton.filled(
              tooltip: 'Ajouter un centre',
              onPressed: _saving ? null : _showAddInstitutionDialog,
              icon: const Icon(LucideIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddInstitutionDialog() async {
    final nameController = TextEditingController();
    final cityController = TextEditingController(text: _cityController.text.trim());
    String type = 'clinic';
    String? error;

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ajouter un centre de sante'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du centre *',
                      prefixIcon: Icon(LucideIcons.building2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(LucideIcons.hospital),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'clinic', child: Text('Clinique')),
                      DropdownMenuItem(value: 'hospital', child: Text('Hopital')),
                      DropdownMenuItem(value: 'lab', child: Text('Laboratoire')),
                      DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacie')),
                    ],
                    onChanged: (value) => setDialogState(() => type = value ?? 'clinic'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      prefixIcon: Icon(LucideIcons.mapPin),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: AppColors.destructive)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() => error = 'Le nom du centre est requis');
                      return;
                    }
                    try {
                      final response = await ref.read(apiClientProvider).dio.post(
                        DoctorApiEndpoints.institutions,
                        data: {
                          'name': name,
                          'type': type,
                          if (cityController.text.trim().isNotEmpty) 'city': cityController.text.trim(),
                        },
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(response.data as Map<String, dynamic>);
                      }
                    } catch (e) {
                      setDialogState(() => error = ErrorMapper.fromException(e).message);
                    }
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    cityController.dispose();

    if (created == null || !mounted) return;
    setState(() {
      _institutions = [..._institutions, created]
        ..sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));
      _selectedInstitutionId = created['id'] as String?;
      _hospitalController.text = created['name'] as String? ?? '';
    });
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.card,
        ),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }
}
