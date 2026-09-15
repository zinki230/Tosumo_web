import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/app_button.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  MobileScannerController? _scannerController;
  bool _isTorchOn = false;
  String? _scannedCode;
  String? _manualCode;
  String? _patientId;
  String? _patientName;
  String? _patientNationalId;
  PatientDetail? _patientDetail;
  bool _isVerified = false;
  bool _startingEmergency = false;
  bool _verifying = false;
  String? _scanError;
  bool _showManualEntry = false;
  bool _isLoading = false;
  
  // Cache des QR codes récemment scannés (évite recherches multiples)
  final Map<String, PatientDetail> _qrCache = {};
  Timer? _cacheCleanupTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
    
    // Nettoyer le cache toutes les 5 minutes
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _qrCache.clear(),
    );
  }

  Future<void> _initializeScanner() async {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } catch (e) {
      if (kDebugMode) print('[ScanScreen] Erreur init scanner: $e');
    }
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _scannerController?.dispose();
    _qrCache.clear();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scannedCode != null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final code = barcode!.rawValue!;
    
    // Validation basique du format avant lookup
    if (!_isValidQrFormat(code)) {
      setState(() {
        _scannedCode = code;
        _scanError = 'Format de QR code invalide';
        _isLoading = false;
        _isVerified = false;
      });
      return;
    }
    
    _lookupPatient(code);
  }

  /// Valide le format du QR code avant envoi au serveur
  bool _isValidQrFormat(String code) {
    // JWT token format (3 parties séparées par des points)
    if (code.contains('.') && code.split('.').length == 3) {
      return code.length > 20; // JWT minimum length
    }
    
    // Legacy card number format (TOS-YYYY-XXXXX ou numérique)
    if (code.startsWith('TOS-')) {
      return code.length >= 13; // TOS-2024-00001 = 13 chars minimum
    }
    
    // Format numérique pur (ancien système)
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return code.length >= 6;
    }
    
    return false;
  }

  Future<void> _lookupPatient(String code) async {
    setState(() {
      _scannedCode = code;
      _isLoading = true;
      _scanError = null;
    });
    
    // Vérifier le cache d'abord
    if (_qrCache.containsKey(code)) {
      final cached = _qrCache[code]!;
      if (mounted) {
        setState(() {
          _patientId = cached.id;
          _patientName = cached.name;
          _patientNationalId = cached.nationalId;
          _patientDetail = cached;
          _isVerified = true;
          _isLoading = false;
          _scanError = null;
        });
      }
      if (kDebugMode) print('[ScanScreen] ✓ Patient trouvé dans le cache');
      return;
    }
    
    try {
      // TIMEOUT RÉDUIT: 5 secondes au lieu de 15
      // Retry automatique intégré
      final patient = await _fetchWithRetry(code);
      
      if (mounted) {
        // Mettre en cache le résultat
        _qrCache[code] = patient;
        
        setState(() {
          _patientId = patient.id;
          _patientName = patient.name;
          _patientNationalId = patient.nationalId;
          _patientDetail = patient;
          _isVerified = true;
          _isLoading = false;
          _scanError = null;
          _retryCount = 0;
        });
        
        if (kDebugMode) print('[ScanScreen] ✓ Patient vérifié: ${patient.name}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patientId = null;
          _patientName = 'Patient inconnu';
          _patientNationalId = code;
          _patientDetail = null;
          _isVerified = false;
          _isLoading = false;
          _scanError = _extractQrError(e);
        });
        
        if (kDebugMode) print('[ScanScreen] ✗ Échec lookup: ${_scanError}');
      }
    }
  }

  /// Fetch avec retry automatique (max 2 tentatives)
  Future<PatientDetail> _fetchWithRetry(String code) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        _retryCount = attempt;
        
        final patient = await ref
            .read(patientRepositoryProvider)
            .getPatientByQrCode(code)
            .timeout(
              const Duration(seconds: 5), // 5 secondes au lieu de 15!
              onTimeout: () => throw Exception(
                'Délai d\'attente dépassé. Vérifiez votre connexion.'
              ),
            );
        
        return patient;
      } on DioException catch (e) {
        // Erreur réseau → retry
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          if (attempt < 1) {
            // Attendre 1 seconde avant retry
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }
        // Autres erreurs → ne pas retry
        rethrow;
      } catch (e) {
        // Exception autre que Dio → ne pas retry
        rethrow;
      }
    }
    
    throw Exception('Impossible de vérifier le QR code après 2 tentatives');
  }

  /// Surfaces a clear, user-facing message for QR scan failures (invalid,
  /// expired or already-used tokens) instead of a raw client error.
  String _extractQrError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    }
    return 'QR code non reconnu. Veuillez réessayer.';
  }

  Future<void> _openRecord() async {
    if (_patientId == null) return;
    context.go('/patient/$_patientId');
  }

  Future<void> _startEmergencyAccess() async {
    final patientId = _patientId;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient non identifié')),
      );
      return;
    }
    setState(() => _startingEmergency = true);
    try {
      await ref.read(emergencyRepositoryProvider).startEmergencySession(
        patientId,
        ref.read(currentDoctorIdProvider) ?? '',
        'Accès d\'urgence demandé par le médecin',
      ).timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) {
        setState(() => _startingEmergency = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session d\'urgence ouverte')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _startingEmergency = false);
        final failure = ErrorMapper.fromException(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }

  void _toggleTorch() {
    _scannerController?.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  void _resetScan() {
      setState(() {
        _scannedCode = null;
        _patientId = null;
        _patientName = null;
        _patientNationalId = null;
        _patientDetail = null;
        _isVerified = false;
        _verifying = false;
        _scanError = null;
        _showManualEntry = false;
        _manualCode = null;
      });
  }

  void _submitManualCode() {
    if (_manualCode == null || _manualCode!.trim().isEmpty) return;
    _lookupPatient(_manualCode!.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bool showResult = _scannedCode != null;
    final bool showManual = _showManualEntry && !showResult;
    final bool showScanner = !showResult && !showManual;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: !showScanner,
            child: IgnorePointer(
              ignoring: !showScanner,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
            ),
          ),
          if (showScanner) _buildScanOverlayAndBar(),
          if (showManual) _buildManualEntry(),
          if (showResult) _buildResultScreen(),
        ],
      ),
    );
  }

  Widget _buildScanOverlayAndBar() {
    return Stack(
      children: [
        _buildScanOverlay(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.white, size: 24),
                  onPressed: () => context.pop(),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                        color: AppColors.white,
                        size: 24,
                      ),
                      onPressed: _toggleTorch,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.keyboard, color: AppColors.white, size: 24),
                      onPressed: () => setState(() => _showManualEntry = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Center(
              child: Text(
                'TOSUMO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scannez le code QR du patient',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Placez le code dans le cadre',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // NOUVEAU: Indicateur de statut réseau
          if (!_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.wifiOff, size: 16, color: AppColors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Hors ligne - Vérifiez votre connexion',
                    style: TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // NOUVELLE MÉTHODE: État réseau
  bool get _isOnline {
    // TODO: Intégrer avec ConnectivityService
    return true;
  }

  Widget _buildManualEntry() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saisie manuelle'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => setState(() => _showManualEntry = false),
          color: AppColors.foreground,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Icon(LucideIcons.keyboard, size: 28, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Entrez le code manuellement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID médical ou code QR du patient',
                    style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: (v) => _manualCode = v,
                    decoration: const InputDecoration(
                      hintText: 'TOS-2024-XXXXX',
                      prefixIcon: Icon(LucideIcons.qrCode, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Rechercher',
                    loading: _isLoading,
                    onPressed: _submitManualCode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final patient = _patientDetail;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Résultat du scan'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: _resetScan,
          color: AppColors.foreground,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_scannedCode != null) await _lookupPatient(_scannedCode!);
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [AppShadows.card],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isVerified
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.alert.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Icon(
                      _isVerified ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                      size: 40,
                      color: _isVerified ? AppColors.success : AppColors.alert,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isVerified ? 'Patient vérifié' : 'Patient non vérifié',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _isVerified ? AppColors.success : AppColors.alert,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_patientName != null) ...[
                    Text(
                      _patientName!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _patientNationalId ?? '',
                      style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                    ),
                  ] else if (_isLoading)
                    const CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildVitalCard(patient),
            const SizedBox(height: 20),
            _buildEmergencyContactCard(patient),
            const SizedBox(height: 20),
            _buildAccessSection(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(LucideIcons.scanLine, size: 18),
                label: const Text('Scanner un autre code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCard(PatientDetail? patient) {
    if (patient == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.alert.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.alert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(LucideIcons.siren, size: 18, color: AppColors.alert),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations vitales',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                    ),
                    Text(
                      'À utiliser en cas d\'accident pour les premiers soins',
                      style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _VitalInfoTile(
                  label: 'Groupe sanguin',
                  value: patient.bloodType.isEmpty ? '—' : patient.bloodType,
                  icon: LucideIcons.droplet,
                  color: AppColors.alert,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Allergies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
          const SizedBox(height: 6),
          patient.allergies.isEmpty
              ? const Text('Aucune allergie connue', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: patient.allergies.map((a) => Chip(
                    label: Text(a, style: const TextStyle(fontSize: 11, color: AppColors.destructive)),
                    backgroundColor: AppColors.destructive.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
          const SizedBox(height: 12),
          const Text('Conditions chroniques', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
          const SizedBox(height: 6),
          patient.chronicConditions.isEmpty
              ? const Text('Aucune condition chronique', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: patient.chronicConditions.map((c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 11, color: AppColors.darkText)),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard(PatientDetail? patient) {
    if (patient == null || patient.emergencyContact == null) {
      return const SizedBox.shrink();
    }
    final contact = patient.emergencyContact!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.alert.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.alert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(LucideIcons.phoneCall, size: 18, color: AppColors.alert),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Contact d\'urgence',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: LucideIcons.user, label: 'Nom', value: contact.name),
          const Divider(height: 16),
          _InfoRow(icon: LucideIcons.heart, label: 'Relation', value: contact.relationship),
          const Divider(height: 16),
          _InfoRow(icon: LucideIcons.phone, label: 'Téléphone', value: contact.phone),
        ],
      ),
    );
  }

  Widget _buildAccessSection() {
    final bool canAccess = _patientId != null;
    final bool granted = _isVerified && _patientId != null;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: granted
                      ? AppColors.success.withValues(alpha: 0.12)
                      : canAccess
                          ? AppColors.alert.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  granted 
                      ? LucideIcons.lockOpen 
                      : canAccess 
                          ? LucideIcons.fileEdit 
                          : LucideIcons.lock,
                  size: 18,
                  color: granted 
                      ? AppColors.success 
                      : canAccess 
                          ? AppColors.alert 
                          : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  granted 
                      ? 'Accès autorisé' 
                      : canAccess 
                          ? 'Patient à vérifier' 
                          : 'Accès au dossier',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (granted) ...[
            Text(
              'Le QR code du patient a été vérifié et un accès temporaire à son dossier médical vous a été accordé.',
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
          ] else if (canAccess) ...[
            Text(
              'Patient identifié mais non vérifié. Vous pouvez accéder au dossier pour compléter ou vérifier les informations du patient.',
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
          ] else if (_scanError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.destructive),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Le QR code n\'a pas pu être vérifié. Scannez à nouveau la carte médicale du patient.',
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 16),
          if (canAccess) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: granted 
                    ? 'Ouvrir le dossier patient' 
                    : 'Compléter les informations',
                loading: _verifying,
                onPressed: _openRecord,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Réessayer le scan',
                fullWidth: false,
                onPressed: _resetScan,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _startingEmergency ? null : _startEmergencyAccess,
              child: _startingEmergency
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Accès urgence (session 24h)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VitalInfoTile extends StatelessWidget {
  const _VitalInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.foreground),
          ),
        ],
      ),
    );
  }
}
