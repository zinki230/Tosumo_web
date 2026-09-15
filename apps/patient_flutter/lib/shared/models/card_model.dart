import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_model.freezed.dart';
part 'card_model.g.dart';

@freezed
sealed class CardModel with _$CardModel {
  const factory CardModel({
    required String patientId,
    required String token,
    @Default('ACTIVE') String status,
    required String issuedAt,
  }) = _CardModel;

  factory CardModel.fromJson(Map<String, dynamic> json) =>
      _$CardModelFromJson(json);
}
