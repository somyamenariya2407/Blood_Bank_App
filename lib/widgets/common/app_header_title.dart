import 'package:flutter/material.dart';

class AppLogoBadge extends StatelessWidget {
  final double size;
  final double radius;

  const AppLogoBadge({
    super.key,
    this.size = 34,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/app_logo.png',
        height: size,
        width: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class AppHeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double logoSize;

  const AppHeaderTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.logoSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    return Row(
      children: [
        AppLogoBadge(size: logoSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasSubtitle)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
