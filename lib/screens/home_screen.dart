import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_responsive.dart';
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
  bool _isUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final rp = AppResponsive.of(context);
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.primaryLighter,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: rp.bottomNavHeight,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: rp.bottomNavIconSz),
            selectedIcon: Icon(Icons.home_rounded,
                size: rp.bottomNavIconSz, color: AppTheme.primary),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: rp.bottomNavIconSz),
            selectedIcon: Icon(Icons.dashboard_rounded,
                size: rp.bottomNavIconSz, color: AppTheme.primary),
            label: '관리 현황',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, size: rp.bottomNavIconSz),
            selectedIcon: Icon(Icons.bar_chart_rounded,
                size: rp.bottomNavIconSz, color: AppTheme.primary),
            label: '통계',
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) => setState(() => _currentIndex = index);

  Widget _buildBody() {
    if (_currentIndex == 0) return const _HomeTab();
    if (_currentIndex == 1) {
      if (!_isUnlocked) {
        return PinLockScreen(
          title: '관리 현황',
          onUnlocked: () => setState(() => _isUnlocked = true),
        );
      }
      return const DashboardScreen();
    }
    return const StatisticsScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final rp = AppResponsive.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Consumer<DataService>(
          builder: (context, service, _) {
            final stats     = service.statusStats;
            final total     = service.requests.length;
            final completed = stats['설치완료'] ?? 0;
            final onHold    = stats['설치보류'] ?? 0;
            final active    = total - completed - onHold - (stats['접수취소'] ?? 0);

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context, rp),
                  SizedBox(height: rp.spaceLg),
                  Padding(
                    padding: rp.paddingH,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (total > 0) ...[
                          Text('전체 현황',
                            style: TextStyle(
                              fontSize: rp.fontLg,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            )),
                          SizedBox(height: rp.spaceMd),
                          Row(
                            children: [
                              Expanded(child: _MiniStatCard(
                                label: '전체 접수', count: total,
                                color: AppTheme.secondary,
                                icon: Icons.list_alt_rounded, rp: rp)),
                              SizedBox(width: rp.spaceSm),
                              Expanded(child: _MiniStatCard(
                                label: '진행 중', count: active,
                                color: const Color(0xFF0284C7),
                                icon: Icons.pending_actions_rounded, rp: rp)),
                              SizedBox(width: rp.spaceSm),
                              Expanded(child: _MiniStatCard(
                                label: '설치 완료', count: completed,
                                color: AppTheme.primary,
                                icon: Icons.check_circle_rounded, rp: rp)),
                              SizedBox(width: rp.spaceSm),
                              Expanded(child: _MiniStatCard(
                                label: '설치 보류', count: onHold,
                                color: const Color(0xFFEA580C),
                                icon: Icons.pause_circle_outline_rounded, rp: rp)),
                            ],
                          ),
                          SizedBox(height: rp.spaceLg),
                        ],
                        _buildRegisterCard(context, rp),
                        SizedBox(height: rp.spaceMd),
                        _buildGuideSection(rp),
                        SizedBox(height: rp.spaceXl),
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

  Widget _buildHeader(BuildContext context, AppResponsive rp) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        rp.headerPadH, rp.headerPadTop, rp.headerPadH, rp.headerPadBottom),
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
            padding: EdgeInsets.symmetric(
              horizontal: rp.isWide ? 14 : 10,
              vertical: rp.isWide ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('한국지역난방공사',
              style: TextStyle(
                fontSize: rp.fontSm,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              )),
          ),
          SizedBox(height: rp.spaceMd),
          Text('무선모뎀\n신규설치 접수',
            style: TextStyle(
              fontSize: rp.fontHero,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            )),
          SizedBox(height: rp.spaceSm),
          Text('열량계 무선검침 사업\n새로운 사이트 설치를 신청해주세요',
            style: TextStyle(
              fontSize: rp.fontMd,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            )),
        ],
      ),
    );
  }

  Widget _buildRegisterCard(BuildContext context, AppResponsive rp) {
    final iconBoxSize = rp.isWide ? 64.0 : 52.0;
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RegistrationFormScreen())),
      child: Container(
        padding: rp.paddingCard,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(rp.cardRadius),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: iconBoxSize, height: iconBoxSize,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(rp.isWide ? 18 : 14)),
              child: Icon(Icons.add_circle_outline_rounded,
                  size: rp.iconLg, color: Colors.white),
            ),
            SizedBox(width: rp.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('신규 설치 접수 신청',
                    style: TextStyle(
                      fontSize: rp.fontXl,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                  SizedBox(height: rp.isWide ? 6 : 3),
                  Text('4단계 입력으로 간편하게 신청하세요',
                    style: TextStyle(
                      fontSize: rp.fontMd,
                      color: AppTheme.textSecondary,
                    )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: rp.iconSm, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection(AppResponsive rp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('진행 절차',
          style: TextStyle(
            fontSize: rp.fontLg,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          )),
        SizedBox(height: rp.spaceMd),
        ...[
          ('01', '접수 신청',      '지사 선택 후 설치 정보를 입력합니다',         Icons.edit_note_rounded),
          ('02', 'KT 중계기 확인', '건물 내 KT 중계기 설치 여부를 확인합니다',   Icons.router_rounded),
          ('03', '설치 일정 조율', '담당 엔지니어가 설치 일정을 연락드립니다',   Icons.event_available_rounded),
          ('04', '설치 완료',      '현장 설치 완료 후 관리자가 완료 처리합니다', Icons.check_circle_rounded),
        ].asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final iconBoxSz = rp.isWide ? 42.0 : 32.0;
          return Container(
            margin: EdgeInsets.only(bottom: rp.spaceSm),
            padding: rp.paddingCard,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(rp.cardRadius),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: iconBoxSz, height: iconBoxSz,
                  decoration: BoxDecoration(
                    color: i == 3 ? AppTheme.primaryLighter : AppTheme.background,
                    borderRadius: BorderRadius.circular(rp.borderRadius)),
                  child: Icon(item.$4, size: rp.iconMd,
                    color: i == 3 ? AppTheme.primary : AppTheme.textSecondary),
                ),
                SizedBox(width: rp.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(item.$1, style: TextStyle(
                          fontSize: rp.fontXs,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                        SizedBox(width: rp.spaceSm),
                        Text(item.$2, style: TextStyle(
                          fontSize: rp.fontMd,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                      ]),
                      SizedBox(height: rp.isWide ? 4 : 2),
                      Text(item.$3, style: TextStyle(
                        fontSize: rp.fontSm,
                        color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: rp.spaceMd),
        Container(
          padding: rp.paddingCard,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(rp.cardRadius),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: rp.iconSm + 2, color: AppTheme.primary),
              SizedBox(width: rp.spaceMd),
              Expanded(
                child: Text('설치 접수 문의: 무선검침 담당팀',
                  style: TextStyle(
                    fontSize: rp.fontMd,
                    color: AppTheme.primaryDark,
                  )),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final AppResponsive rp;

  const _MiniStatCard({
    required this.label, required this.count,
    required this.color, required this.icon,
    required this.rp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(rp.kpiPad),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(rp.kpiRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: rp.iconMd, color: color),
          SizedBox(height: rp.spaceSm),
          Text('$count',
            style: TextStyle(
              fontSize: rp.kpiValueFont,
              fontWeight: FontWeight.w800,
              color: color,
            )),
          Text(label,
            style: TextStyle(
              fontSize: rp.kpiLabelFont,
              color: AppTheme.textSecondary,
            )),
        ],
      ),
    );
  }
}
