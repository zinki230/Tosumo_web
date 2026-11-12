import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/theme/app_colors.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _gender = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _bloodType = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _medications = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyRelationship = TextEditingController();
  final _emergencyPhone = TextEditingController();
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final patient = ref.read(patientProvider).patient;
    if (patient == null) return;
    final parts = patient.name.trim().split(RegExp(r'\s+'));
    _firstName.text = parts.isEmpty ? '' : parts.first;
    _lastName.text = parts.length < 2 ? '' : parts.skip(1).join(' ');
    _gender.text = patient.gender ?? '';
    _city.text = patient.city;
    _address.text = patient.address;
    _bloodType.text = patient.bloodType;
    _allergies.text = patient.allergies.join(', ');
    _conditions.text = patient.chronicConditions.join(', ');
    _medications.text = patient.currentMeds.join(', ');
    _emergencyName.text = patient.emergencyContactName;
    _emergencyRelationship.text = patient.emergencyContactRelationship;
    _emergencyPhone.text = patient.emergencyContactPhone;
    _dateOfBirth = patient.dateOfBirth;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _gender.dispose();
    _city.dispose();
    _address.dispose();
    _bloodType.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _medications.dispose();
    _emergencyName.dispose();
    _emergencyRelationship.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  List<String> _splitList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Choisir une date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (selected != null && mounted) setState(() => _dateOfBirth = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final date = _dateOfBirth;
    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez choisir votre date de naissance.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(patientProvider.notifier)
          .updateProfile(
            firstName: _firstName.text,
            lastName: _lastName.text,
            dateOfBirth: date,
            gender: _gender.text,
            city: _city.text,
            address: _address.text,
            bloodType: _bloodType.text,
            allergies: _splitList(_allergies.text),
            chronicConditions: _splitList(_conditions.text),
            currentMeds: _splitList(_medications.text),
            emergencyContactName: _emergencyName.text,
            emergencyContactRelationship: _emergencyRelationship.text,
            emergencyContactPhone: _emergencyPhone.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’enregistrer le profil : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider).patient;
    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifier mon profil')),
        body: const Center(child: Text('Profil patient introuvable.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        backgroundColor: AppColors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Informations personnelles',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _field(_firstName, 'Prénom', requiredField: true),
            _field(_lastName, 'Nom', requiredField: true),
            Card(
              child: ListTile(
                title: const Text('Date de naissance'),
                subtitle: Text(_dateLabel(_dateOfBirth)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _chooseDate,
              ),
            ),
            _field(_gender, 'Genre'),
            _field(_city, 'Ville'),
            _field(_address, 'Adresse'),
            const SizedBox(height: 12),
            const Text(
              'Informations de santé',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _field(_bloodType, 'Groupe sanguin'),
            _field(
              _allergies,
              'Allergies (séparées par des virgules)',
              maxLines: 2,
            ),
            _field(
              _conditions,
              'Maladies chroniques (séparées par des virgules)',
              maxLines: 2,
            ),
            _field(
              _medications,
              'Traitements (séparés par des virgules)',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text(
              'Contact d’urgence',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _field(_emergencyName, 'Nom du contact'),
            _field(_emergencyRelationship, 'Lien avec le contact'),
            _field(
              _emergencyPhone,
              'Téléphone du contact',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer mes modifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: requiredField
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Champ obligatoire'
                  : null
            : null,
      ),
    );
  }
}
