import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class Avatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final double size;
  final bool online;

  const Avatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 48,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.white, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
