import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RegistrationStep {
  registration,
  otp,
  generatingIdentity,
  identityCreated,
  generatingCard,
  cardGenerated,
  selectingHospital,
  enrollmentComplete,
}

class RegistrationState {
  final RegistrationStep step;
  final String firstName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String city;
  final String role;
  final String phone;
  final double progress;

  const RegistrationState({
    this.step = RegistrationStep.registration,
    this.firstName = '',
    this.lastName = '',
    this.gender = '',
    this.dateOfBirth = '',
    this.city = '',
    this.role = 'patient',
    this.phone = '',
    this.progress = 0,
  });

  RegistrationState copyWith({
    RegistrationStep? step,
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? role,
    String? phone,
    double? progress,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      city: city ?? this.city,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      progress: progress ?? this.progress,
    );
  }
}

class RegistrationNotifier extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  void setStep(RegistrationStep step) {
    state = state.copyWith(step: step);
  }

  void setRegistrationData({
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? role,
    String? phone,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      city: city,
      role: role,
      phone: phone,
    );
  }

  void setProgress(double progress) {
    state = state.copyWith(progress: progress);
  }

  void reset() {
    state = const RegistrationState();
  }
}

final registrationProvider = NotifierProvider<RegistrationNotifier, RegistrationState>(
  RegistrationNotifier.new,
);
