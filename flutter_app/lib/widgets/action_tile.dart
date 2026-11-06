import 'package:flutter/material.dart';
import '../app_colors.dart';

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(31),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        // Flexible label to avoid overflow in narrow constraints
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8), child: content),
        ),
      ),
    );
  }
}
