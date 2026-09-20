import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class MenuTile extends StatelessWidget {
  const MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.isDanger = false,
    this.iconWidget,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDanger;
  /// Overrides the default PhosphorIcon(icon) rendering when set — used
  /// for a dashboard-uploaded custom icon image (nav_buttons' CUSTOM icon
  /// type) instead of a preset glyph. [icon] is still required as the
  /// fallback while the custom image loads/if it fails.
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDanger ? AppColors.errorRed : AppColors.textPrimary;
    final iconColor = isDanger ? AppColors.errorRed : AppColors.textPrimary;
    final chipColor =
        isDanger ? AppColors.orderStatusRedBg : const Color(0xFFF4F4F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: chipColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: iconWidget ??
                        PhosphorIcon(
                          icon,
                          size: 19.sp,
                          color: iconColor,
                        ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  trailing!,
                  Gap(8.w),
                ],
                PhosphorIcon(
                  PhosphorIcons.caretRight,
                  size: 16.sp,
                  color: isDanger
                      ? AppColors.errorRed
                      : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
