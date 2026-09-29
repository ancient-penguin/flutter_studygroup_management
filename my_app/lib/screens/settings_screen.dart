import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';

/// 8. 설정: 기본값, 저장 위치, 클라우드 동기화(6단계 백엔드 연동 진입점).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cloudSync = false;
  bool _notify = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            Text('설정', style: AppText.display(size: 28)),
            const SizedBox(height: 18),
            _SettingsCard(children: [
              _SettingsRow(label: '기본 시급', value: '35,000원'),
              _SettingsRow(label: '기본 수업 시간', value: '120분', showDivider: false),
            ]),
            const SizedBox(height: 18),
            Text('데이터', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.mutedDark)),
            const SizedBox(height: 8),
            _SettingsCard(children: [
              const _SettingsRow(label: '저장 위치', value: '이 기기'),
              _SettingsSwitchRow(
                label: '클라우드 동기화',
                sub: '서버 연동 후 사용할 수 있습니다',
                value: _cloudSync,
                onChanged: (v) => setState(() => _cloudSync = v),
              ),
              const _SettingsRow(label: '백업 파일 내보내기', value: '', showDivider: false),
            ]),
            const SizedBox(height: 18),
            Text('기타', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.mutedDark)),
            const SizedBox(height: 8),
            _SettingsCard(children: [
              _SettingsSwitchRow(
                label: '수업 시작 알림',
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              const _SettingsRow(label: '앱 버전', value: '0.1.0', showDivider: false),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.settings),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;
  const _SettingsRow({required this.label, required this.value, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: showDivider ? AppColors.divider : Colors.transparent)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(size: 15)),
          if (value.isNotEmpty)
            Text(value, style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.mutedDark))
          else
            const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchRow({required this.label, this.sub, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(size: 15)),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!, style: AppText.body(size: 12, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accent),
        ],
      ),
    );
  }
}
