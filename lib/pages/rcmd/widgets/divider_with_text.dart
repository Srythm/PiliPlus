import 'package:flutter/material.dart';

class DividerWithText extends StatelessWidget {
  const DividerWithText({
    super.key,
    required this.text,
    this.onTap,
    this.icon,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.4);
    final label = Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const .symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Divider(color: outline, height: 1)),
            const SizedBox(width: 10),
            if (icon != null) ...[
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            label,
            const SizedBox(width: 10),
            Expanded(child: Divider(color: outline, height: 1)),
          ],
        ),
      ),
    );
  }
}