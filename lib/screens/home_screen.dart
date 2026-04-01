import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'registration_form_screen.dart';
import 'dashboard_screen.dart';
import 'statistics_screen.dart';
import 'pin_lock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // 관리현황·통계 탭 잠금 상태 (앱 세션 동안 유지)
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primaryLighter,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            label: '관리 현황',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppTheme.primary),
            label: '통계',
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _buildBody() {
    // 홈 탭
    if (_currentIndex == 0) return const _HomeTab();

    // 관리현황 탭 — PIN 인증 필요
    if (_currentIndex == 1) {
      if (!_isUnlocked) {
        return PinLockScreen(
          title: '관리 현황',
          onUnlocked: () => setState(() => _isUnlocked = true),
        );
      }
      return const DashboardScreen();
    }

    // 통계 탭 — PIN 없이 바로 접근
    return const StatisticsScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 홈 탭
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Consumer<DataService>(
          builder: (context, service, _) {
            final stats     = service.statusStats;
            final total     = service.requests.length;
            final completed = stats['설치완료'] ?? 0;
            final onHold    = stats['설치보류'] ?? 0;
            final active    = total
                - completed
                - onHold
                - (stats['접수취소'] ?? 0);

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (total > 0) ...[
                          const Text('전체 현황',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _MiniStatCard(
                                label: '전체 접수', count: total,
                                color: AppTheme.secondary, icon: Icons.list_alt_rounded)),
                              const SizedBox(width: 8),
                              Expanded(child: _MiniStatCard(
                                label: '진행 중', count: active,
                                color: const Color(0xFF0284C7), icon: Icons.pending_actions_rounded)),
                              const SizedBox(width: 8),
                              Expanded(child: _MiniStatCard(
                                label: '설치 완료', count: completed,
                                color: AppTheme.primary, icon: Icons.check_circle_rounded)),
                              const SizedBox(width: 8),
                              Expanded(child: _MiniStatCard(
                                label: '설치 보류', count: onHold,
                                color: const Color(0xFFEA580C), icon: Icons.pause_circle_outline_rounded)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        _buildRegisterCard(context),
                        const SizedBox(height: 16),
                        _buildGuideSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('한국지역난방공사',
              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          const Text('무선모뎀\n신규설치 접수',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.3)),
          const SizedBox(height: 8),
          Text('열량계 무선검침 사업\n새로운 사이트 설치를 신청해주세요',
            style: TextStyle(fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildRegisterCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegistrationFormScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.add_circle_outline_rounded,
                  size: 26, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('신규 설치 접수 신청',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  Text('4단계 입력으로 간편하게 신청하세요',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('진행 절차',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...[
          ('01', '접수 신청',   '지사 선택 후 설치 정보를 입력합니다',        Icons.edit_note_rounded),
          ('02', 'KT 중계기 확인', '건물 내 KT 중계기 설치 여부를 확인합니다', Icons.router_rounded),
          ('03', '설치 일정 조율', '담당 엔지니어가 설치 일정을 연락드립니다', Icons.event_available_rounded),
          ('04', '설치 완료',  '현장 설치 완료 후 관리자가 완료 처리합니다', Icons.check_circle_rounded),
        ].asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: i == 3 ? AppTheme.primaryLighter : AppTheme.background,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(item.$4, size: 16,
                    color: i == 3 ? AppTheme.primary : AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(item.$1, style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                        const SizedBox(width: 6),
                        Text(item.$2, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                      ]),
                      Text(item.$3, style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text('설치 접수 문의: 무선검침 담당팀',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 미니 통계 카드
// ─────────────────────────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniStatCard({
    required this.label, required this.count,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text('$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
