import 'package:flutter/material.dart';

import '../app_colors.dart';

final ValueNotifier<int> dashboardNavigationSignal = ValueNotifier<int>(0);

/// SiRT emblem. Tapping it returns to the account's dashboard.
class SirtLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final VoidCallback? onTap;

  const SirtLogo({
    super.key,
    this.size = 32,
    this.showName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap ?? () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          dashboardNavigationSignal.value++;
        },
        borderRadius: BorderRadius.circular(size * .22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(size * .22),
              child: Image.asset(
                'assets/images/sirt_logo.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                semanticLabel: 'Logo SiRT',
              ),
            ),
            if (showName) ...[
              const SizedBox(width: 8),
              const Text(
                'SiRT',
                style: TextStyle(
                  color: appGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      );
}
