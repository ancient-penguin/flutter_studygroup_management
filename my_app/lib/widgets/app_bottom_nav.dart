import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppTab { students, schedule, settlement, settings }

/// 8개 화면 중 4개(학생/일정/정산/설정)에서 같이 쓰는 하단 탭바.
class AppBottomNav extends StatelessWidget {
  final AppTab current;
  const AppBottomNav({super.key, required this.current});

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.people_outline,
            label: '학생',
            active: current == AppTab.students,
            onTap: () => _go(context, '/'),
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: '일정',
            active: current == AppTab.schedule,
            onTap: () => _go(context, '/schedule'),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: '정산',
            active: current == AppTab.settlement,
            onTap: () => _go(context, '/settlement'),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: '설정',
            active: current == AppTab.settings,
            onTap: () => _go(context, '/settings'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.body(
                size: 12,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
