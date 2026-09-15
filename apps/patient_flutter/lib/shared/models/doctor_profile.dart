import 'package:freezed_annotation/freezed_annotation.dart';

part 'doctor_profile.freezed.dart';
part 'doctor_profile.g.dart';

@freezed
sealed class DoctorProfile with _$DoctorProfile {
  const factory DoctorProfile({
    required String id,
    required String name,
    required String specialty,
    String? photoUrl,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    @Default(0) int yearsExperience,
    @Default(0) int patientCount,
    required String bio,
    @Default([]) List<String> languages,
    required String hospital,
    required String hospitalLocation,
    @Default([]) List<String> consultationTypes,
    required String nextAvailableSlot,
    @Default(false) bool availableToday,
    @Default([]) List<Review> reviews,
    @Default([]) List<String> credentials,
    @Default([]) List<String> expertise,
  }) = _DoctorProfile;

  factory DoctorProfile.fromJson(Map<String, dynamic> json) =>
      _$DoctorProfileFromJson(json);
}

@freezed
sealed class Review with _$Review {
  const factory Review({
    required String name,
    required double rating,
    required String text,
    required String date,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) =>
      _$ReviewFromJson(json);
}
