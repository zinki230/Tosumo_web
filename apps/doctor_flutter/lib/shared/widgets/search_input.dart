import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class SearchInput extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? placeholder;
  final VoidCallback? onFilterClick;
  final int filterBadge;

  const SearchInput({
    super.key,
    this.value,
    this.onChanged,
    this.placeholder,
    this.onFilterClick,
    this.filterBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: value != null ? TextEditingController(text: value) : null,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: placeholder ?? '',
                hintStyle: const TextStyle(color: AppColors.mutedForeground),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Icon(LucideIcons.search, size: 20, color: AppColors.mutedForeground),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        if (onFilterClick != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onFilterClick,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Icon(LucideIcons.slidersHorizontal, color: AppColors.white, size: 20),
                  if (filterBadge > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          filterBadge.toString(),
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
