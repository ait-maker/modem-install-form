import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/installation_request.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_responsive.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 필터
  late int _selectedYear;
  int? _selectedMonth; // null = 연간 전체
  String _selectedBranch = '전체';

  final List<String> _months = [
    '전체', '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('통계'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: '요약'),
            Tab(text: '지사별'),
            Tab(text: '월별 추이'),
          ],
        ),
      ),
      body: Consumer<DataService>(
        builder: (context, service, _) {
          // 사용 가능한 연도 목록
          final years = service.availableYears;
          if (!years.contains(_selectedYear)) {
            _selectedYear = years.first;
          }

          return Column(
            children: [
              _buildFilterBar(service, years),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(service),
                    _buildBranchTab(service),
                    _buildMonthlyTab(service),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 필터 바 ──────────────────────────────────────────
  Widget _buildFilterBar(DataService service, List<int> years) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 연도 + 지사 선택
          Row(
            children: [
              // 연도 드롭다운
              _FilterChipDropdown<int>(
                label: '연도',
                value: _selectedYear,
                items: years,
                display: (y) => '$y년',
                onChanged: (y) => setState(() => _selectedYear = y!),
              ),
              const SizedBox(width: 8),
              // 지사 드롭다운
              Expanded(
                child: _FilterChipDropdown<String>(
                  label: '지사',
                  value: _selectedBranch,
                  items: ['전체', ...branchList],
                  display: (b) => b,
                  onChanged: (b) => setState(() => _selectedBranch = b ?? '전체'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 월 선택 (가로 스크롤 칩)
          SizedBox(
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              itemBuilder: (_, i) {
                final m = _months[i];
                final monthNum = i == 0 ? null : i;
                final selected = _selectedMonth == monthNum;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMonth = monthNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.background,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 요약 탭 ──────────────────────────────────────────
  Widget _buildSummaryTab(DataService service) {
    final items = service.filterStat(
      branch: _selectedBranch,
      year: _selectedYear,
      month: _selectedMonth,
    );
    final total     = items.length;
    final completed = items.where((r) => r.status == InstallationStatus.completed).length;
    final onHold    = items.where((r) => r.status == InstallationStatus.onHold).length;
    final cancelled = items.where((r) => r.status == InstallationStatus.cancelled).length;
    final active    = total - completed - onHold - cancelled;
    final rate      = total > 0 ? (completed / total * 100) : 0.0;

    // 보류 사유
    final holdStats  = service.holdReasonStats(branch: _selectedBranch, year: _selectedYear, month: _selectedMonth);
    // 연결방식
    final connStats  = service.connectionTypeStats(branch: _selectedBranch, year: _selectedYear, month: _selectedMonth);
    // 평균 완료일
    final avgDaysMap = service.avgCompletionDays(year: _selectedYear, month: _selectedMonth);
    final avgDays    = _selectedBranch == '전체'
        ? (avgDaysMap.isEmpty ? null : avgDaysMap.values.reduce((a, b) => a + b) / avgDaysMap.length)
        : avgDaysMap[_selectedBranch];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기간 레이블
          _periodLabel(),
          const SizedBox(height: 12),

          // KPI 카드 (5개: 전체접수/설치완료/설치보류/접수취소/평균완료일)
          _buildKpiGrid(total, completed, active, onHold, cancelled, rate, avgDays,
              allItems: items),
          const SizedBox(height: 20),

          // 완료율 게이지
          if (total > 0) ...[
            _SectionTitle(title: '완료율', icon: Icons.donut_large_rounded),
            const SizedBox(height: 10),
            _CompletionGauge(rate: rate.toDouble()),
            const SizedBox(height: 20),
          ],

          // 연결방식 분포
          if (connStats.isNotEmpty) ...[
            _SectionTitle(title: '연결방식 분포', icon: Icons.device_hub_rounded),
            const SizedBox(height: 10),
            _buildConnTypeChart(connStats, total),
            const SizedBox(height: 20),
          ],

          // 보류 사유 분포
          if (holdStats.isNotEmpty) ...[
            _SectionTitle(title: '보류 사유 분포', icon: Icons.pause_circle_outline_rounded),
            const SizedBox(height: 10),
            _buildHoldReasonChart(holdStats),
          ],
        ],
      ),
    );
  }

  // ── KPI 카드 그리드 ─────────────────────────────────
  Widget _buildKpiGrid(int total, int completed, int active,
      int onHold, int cancelled, double rate, double? avgDays,
      {required List<InstallationRequest> allItems}) {

    // 드릴다운 가능 카드 정의
    // filterStatuses: null → 탭 불가 / 리스트 → 해당 상태들 합산 표시
    final items = [
      _KpiData('전체 접수',  '$total건',    Icons.list_alt_rounded,             AppTheme.secondary,        null),
      _KpiData('진행 중',    '$active건',   Icons.pending_actions_rounded,       const Color(0xFF0284C7),    [
        InstallationStatus.pending,
        InstallationStatus.confirmed,
        InstallationStatus.scheduled,
      ]),
      _KpiData('설치 완료',  '$completed건', Icons.check_circle_rounded,         AppTheme.primary,           [InstallationStatus.completed]),
      _KpiData('설치 보류',  '$onHold건',   Icons.pause_circle_outline_rounded,  const Color(0xFFEA580C),    [InstallationStatus.onHold]),
      _KpiData('접수 취소',  '$cancelled건', Icons.cancel_rounded,               AppTheme.cancelled,         [InstallationStatus.cancelled]),
      _KpiData('평균 완료일', avgDays != null ? '${avgDays.toStringAsFixed(1)}일' : '-',
                             Icons.timer_outlined,                               const Color(0xFF7C3AED),    null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        mainAxisSpacing: AppResponsive.of(context).isWide ? 12 : 10,
        crossAxisSpacing: AppResponsive.of(context).isWide ? 12 : 10,
        childAspectRatio: AppResponsive.of(context).isWide ? 1.8 : 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final d = items[i];
        final tappable = d.filterStatuses != null;
        return GestureDetector(
          onTap: tappable
              ? () => _showDrilldownSheet(
                    context,
                    label: d.label,
                    color: d.color,
                    icon: d.icon,
                    filterStatuses: d.filterStatuses!,
                    allItems: allItems,
                  )
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tappable ? d.color.withValues(alpha: 0.35) : AppTheme.border,
                width: tappable ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppResponsive.of(context).isWide ? 8 : 6),
                      decoration: BoxDecoration(
                        color: d.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(d.icon,
                          size: AppResponsive.of(context).isWide ? 20 : 16,
                          color: d.color),
                    ),
                    const Spacer(),
                    if (tappable)
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: d.color.withValues(alpha: 0.7)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.value,
                      style: TextStyle(
                        fontSize: AppResponsive.of(context).kpiValueFont,
                        fontWeight: FontWeight.w800,
                        color: d.color)),
                    Text(d.label,
                      style: TextStyle(
                        fontSize: AppResponsive.of(context).kpiLabelFont,
                        color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 드릴다운 바텀시트 ─────────────────────────────────
  void _showDrilldownSheet(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    required List<InstallationStatus> filterStatuses,
    required List<InstallationRequest> allItems,
  }) {
    // 설치완료 단독 카드인지 여부 → 날짜 정렬·표시 기준
    final isCompleted = filterStatuses.length == 1 &&
        filterStatuses.first == InstallationStatus.completed;

    // 현재 필터 컨텍스트로 해당 상태들의 건만 추출
    final filtered = allItems
        .where((r) => filterStatuses.contains(r.status))
        .toList()
      ..sort((a, b) {
          final dateA = isCompleted ? (a.completedAt ?? a.createdAt) : a.createdAt;
          final dateB = isCompleted ? (b.completedAt ?? b.createdAt) : b.createdAt;
          return dateB.compareTo(dateA);
        });

    // 기간 레이블 문자열
    final periodStr = _selectedMonth != null
        ? '$_selectedYear년 $_selectedMonth월'
        : '$_selectedYear년';
    final branchStr = _selectedBranch == '전체' ? '전체 지사' : _selectedBranch;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DrilldownSheet(
        label: label,
        color: color,
        icon: icon,
        filterStatuses: filterStatuses,
        items: filtered,
        periodStr: periodStr,
        branchStr: branchStr,
      ),
    );
  }

  Widget _buildConnTypeChart(Map<String, int> stats, int total) {
    return _StatCard(
      child: Column(
        children: stats.entries.map((e) {
          final ratio = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                    const Spacer(),
                    Text('${e.value}건  (${(ratio * 100).round()}%)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                _ProgressBar(ratio: ratio, color: AppTheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHoldReasonChart(Map<String, int> stats) {
    final total = stats.values.fold(0, (a, b) => a + b);
    final colors = [
      const Color(0xFFEA580C),
      const Color(0xFFDC2626),
      const Color(0xFF9333EA),
    ];
    final entries = stats.entries.toList();
    return _StatCard(
      child: Column(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          final ratio = total > 0 ? e.value / total : 0.0;
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.key,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ),
                    Text('${e.value}건  (${(ratio * 100).round()}%)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                _ProgressBar(ratio: ratio, color: color),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── 지사별 탭 ─────────────────────────────────────────
  Widget _buildBranchTab(DataService service) {
    final stats = service.branchStats(year: _selectedYear, month: _selectedMonth);
    final avgDays = service.avgCompletionDays(year: _selectedYear, month: _selectedMonth);

    if (stats.isEmpty) {
      return _EmptyState(label: _periodLabel());
    }

    final maxTotal = stats.map((m) => m['total'] as int).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _periodLabel(),
          const SizedBox(height: 12),

          // 지사 순위 테이블
          _SectionTitle(title: '지사별 접수 현황', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 10),
          _StatCard(
            child: Column(
              children: [
                // 헤더
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text('지사', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600))),
                      Expanded(child: Text('접수 비율', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600))),
                      SizedBox(width: 40, child: Text('완료율', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...stats.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final m = entry.value;
                  final branch    = m['branch'] as String;
                  final total     = m['total'] as int;
                  final completed = m['completed'] as int;
                  final onHold    = m['onHold'] as int;
                  final active    = m['active'] as int;
                  final rate      = m['rate'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // 순위 배지
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: idx < 3 ? AppTheme.primary : AppTheme.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text('${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: idx < 3 ? Colors.white : AppTheme.textSecondary,
                                  )),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 64,
                              child: Text(branch,
                                style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(height: 14, color: AppTheme.border.withValues(alpha: 0.5)),
                                  // 완료 (파랑)
                                  if (completed > 0)
                                    FractionallySizedBox(
                                      widthFactor: maxTotal > 0 ? completed / maxTotal : 0,
                                      child: Container(height: 14, color: AppTheme.primary),
                                    ),
                                  // 진행중 (주황)
                                  Positioned(
                                    left: maxTotal > 0 ? (completed / maxTotal) * (MediaQuery.of(context).size.width - 200) : 0,
                                    child: active > 0
                                        ? Container(
                                            width: maxTotal > 0 ? (active / maxTotal) * (MediaQuery.of(context).size.width - 200) : 0,
                                            height: 14,
                                            color: AppTheme.warning.withValues(alpha: 0.7))
                                        : const SizedBox.shrink(),
                                  ),
                                  // 보류 (주황빨강)
                                  Positioned(
                                    left: maxTotal > 0 ? ((completed + active) / maxTotal) * (MediaQuery.of(context).size.width - 200) : 0,
                                    child: onHold > 0
                                        ? Container(
                                            width: maxTotal > 0 ? (onHold / maxTotal) * (MediaQuery.of(context).size.width - 200) : 0,
                                            height: 14,
                                            color: const Color(0xFFEA580C).withValues(alpha: 0.7))
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              child: Text('$rate%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: rate >= 70 ? AppTheme.primary : AppTheme.warning,
                                )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Row(
                            children: [
                              _SmallBadge('전체 $total', AppTheme.secondary),
                              const SizedBox(width: 4),
                              _SmallBadge('완료 $completed', AppTheme.primary),
                              const SizedBox(width: 4),
                              if (active > 0) _SmallBadge('미완료 $active', AppTheme.warning),
                              if (active > 0) const SizedBox(width: 4),
                              if (onHold > 0) _SmallBadge('보류 $onHold', const Color(0xFFEA580C)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // 범례
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(AppTheme.primary, '완료'),
                    const SizedBox(width: 12),
                    _LegendDot(AppTheme.warning, '미완료'),
                    const SizedBox(width: 12),
                    _LegendDot(const Color(0xFFEA580C), '보류'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 평균 완료 소요일
          if (avgDays.isNotEmpty) ...[
            _SectionTitle(title: '지사별 평균 완료 소요일', icon: Icons.timer_outlined),
            const SizedBox(height: 10),
            _buildAvgDaysChart(avgDays),
          ],
        ],
      ),
    );
  }

  Widget _buildAvgDaysChart(Map<String, double> avgDays) {
    final entries = avgDays.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)); // 빠른 순
    if (entries.isEmpty) return const SizedBox();
    final maxDays = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return _StatCard(
      child: Column(
        children: entries.map((e) {
          final ratio = maxDays > 0 ? e.value / maxDays : 0.0;
          final color = e.value <= 3 ? AppTheme.primary
              : e.value <= 7 ? AppTheme.warning
              : const Color(0xFFDC2626);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(e.key,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
                ),
                Expanded(child: _ProgressBar(ratio: ratio, color: color)),
                const SizedBox(width: 8),
                Text('${e.value.toStringAsFixed(1)}일',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 월별 추이 탭 ──────────────────────────────────────
  Widget _buildMonthlyTab(DataService service) {
    final monthly = service.monthlyStats(branch: _selectedBranch, year: _selectedYear);
    final nonZero = monthly.where((m) => m['total'] as int > 0).toList();

    if (nonZero.isEmpty) {
      return _EmptyState(label: _periodLabel());
    }

    final maxVal = monthly.map((m) => m['total'] as int).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _periodLabel(),
          const SizedBox(height: 12),

          // 월별 누적 막대 차트
          _SectionTitle(title: '월별 접수 현황', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 10),
          _StatCard(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(12, (i) {
                      final m = monthly[i];
                      final total     = m['total'] as int;
                      final completed = m['completed'] as int;
                      final onHold    = m['onHold'] as int;
                      final active    = (m['active'] as int) + (m['cancelled'] as int);

                      final isCurrentMonth = DateTime.now().month == i + 1
                          && _selectedYear == DateTime.now().year;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (total > 0)
                                Text('$total',
                                  style: TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w700,
                                    color: isCurrentMonth ? AppTheme.primary : AppTheme.textSecondary,
                                  )),
                              const SizedBox(height: 2),
                              // 누적 막대
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: maxVal > 0 ? (total / maxVal) * 160 : 0,
                                  child: Column(
                                    children: [
                                      // 완료 (파랑) → 위
                                      if (completed > 0)
                                        Flexible(
                                          flex: completed,
                                          child: Container(color: AppTheme.primary),
                                        ),
                                      // 진행 (주황) → 중간
                                      if (active > 0)
                                        Flexible(
                                          flex: active,
                                          child: Container(color: AppTheme.warning.withValues(alpha: 0.8)),
                                        ),
                                      // 보류 (빨간주황) → 아래
                                      if (onHold > 0)
                                        Flexible(
                                          flex: onHold,
                                          child: Container(color: const Color(0xFFEA580C).withValues(alpha: 0.8)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${i + 1}월',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isCurrentMonth ? AppTheme.primary : AppTheme.textHint,
                                  fontWeight: isCurrentMonth ? FontWeight.w700 : FontWeight.w400,
                                )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LegendDot(AppTheme.primary, '완료'),
                    const SizedBox(width: 12),
                    _LegendDot(AppTheme.warning, '미완료'),
                    const SizedBox(width: 12),
                    _LegendDot(const Color(0xFFEA580C), '보류'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 월별 상세 표
          _SectionTitle(title: '월별 상세', icon: Icons.table_chart_rounded),
          const SizedBox(height: 10),
          _StatCard(
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(40),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FixedColumnWidth(42),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // 헤더
                TableRow(
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6)),
                  children: ['월', '접수', '완료', '미완료', '보류', '완료율'].map((h) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      child: Text(h,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary)),
                    ),
                  ).toList(),
                ),
                // 데이터 행
                ...List.generate(12, (i) {
                  final m = monthly[i];
                  final total     = m['total'] as int;
                  final completed = m['completed'] as int;
                  final onHold    = m['onHold'] as int;
                  final active    = m['active'] as int;
                  final rate      = total > 0 ? (completed / total * 100).round() : 0;
                  final isCur = DateTime.now().month == i + 1 && _selectedYear == DateTime.now().year;

                  return TableRow(
                    decoration: BoxDecoration(
                      color: isCur ? AppTheme.primaryLighter.withValues(alpha: 0.4) : null,
                    ),
                    children: [
                      _TableCell('${i + 1}월', bold: isCur, color: isCur ? AppTheme.primary : AppTheme.textSecondary),
                      _TableCell(total > 0 ? '$total' : '-'),
                      _TableCell(completed > 0 ? '$completed' : '-', color: completed > 0 ? AppTheme.primary : null),
                      _TableCell(active > 0 ? '$active' : '-', color: active > 0 ? AppTheme.warning : null),
                      _TableCell(onHold > 0 ? '$onHold' : '-', color: onHold > 0 ? const Color(0xFFEA580C) : null),
                      _TableCell(total > 0 ? '$rate%' : '-',
                        bold: total > 0,
                        color: rate >= 70 ? AppTheme.primary : rate >= 40 ? AppTheme.warning : null),
                    ],
                  );
                }),
                // 합계 행
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
                  ),
                  children: () {
                    final tot = monthly.fold(0, (s, m) => s + (m['total'] as int));
                    final com = monthly.fold(0, (s, m) => s + (m['completed'] as int));
                    final act = monthly.fold(0, (s, m) => s + (m['active'] as int));
                    final hld = monthly.fold(0, (s, m) => s + (m['onHold'] as int));
                    final rt  = tot > 0 ? (com / tot * 100).round() : 0;
                    return [
                      _TableCell('합계', bold: true, color: AppTheme.textPrimary),
                      _TableCell('$tot', bold: true),
                      _TableCell('$com', bold: true, color: AppTheme.primary),
                      _TableCell('$act', bold: true, color: AppTheme.warning),
                      _TableCell('$hld', bold: true, color: const Color(0xFFEA580C)),
                      _TableCell('$rt%', bold: true, color: AppTheme.primary),
                    ];
                  }(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 유틸 ─────────────────────────────────────────────
  Widget _periodLabel() {
    final branch = _selectedBranch == '전체' ? '전체 지사' : _selectedBranch;
    final period = _selectedMonth != null
        ? '$_selectedYear년 $_selectedMonth월'
        : '$_selectedYear년';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryLighter,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryLight),
      ),
      child: Text('$branch  ·  $period',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark)),
    );
  }
}

// ── 재사용 위젯 ───────────────────────────────────────────────────────────────

class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  final List<InstallationStatus>? filterStatuses; // null = 드릴다운 없음
  const _KpiData(this.label, this.value, this.icon, this.color, this.filterStatuses);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppTheme.primary),
      const SizedBox(width: 6),
      Text(title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary)),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final Widget child;
  const _StatCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

class _ProgressBar extends StatelessWidget {
  final double ratio;
  final Color color;
  const _ProgressBar({required this.ratio, required this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: ratio.clamp(0.0, 1.0),
      minHeight: 10,
      backgroundColor: AppTheme.border.withValues(alpha: 0.5),
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  );
}

class _CompletionGauge extends StatelessWidget {
  final double rate;
  const _CompletionGauge({required this.rate});
  @override
  Widget build(BuildContext context) {
    final color = rate >= 70 ? AppTheme.primary
        : rate >= 40 ? AppTheme.warning
        : const Color(0xFFDC2626);
    return _StatCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 22,
                    backgroundColor: AppTheme.border.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${rate.round()}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendDot(color, '완료율'),
              const Spacer(),
              Text(
                rate >= 70 ? '목표 달성' : rate >= 40 ? '진행 중' : '집중 관리 필요',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ],
  );
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _TableCell(this.text, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
    child: Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? AppTheme.textPrimary,
      )),
  );
}

class _FilterChipDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) display;
  final void Function(T?) onChanged;
  const _FilterChipDropdown({
    required this.label, required this.value, required this.items,
    required this.display, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.textSecondary),
        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(display(item)),
        )).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final Widget label;
  const _EmptyState({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.bar_chart_rounded, size: 56, color: AppTheme.border),
        const SizedBox(height: 12),
        const Text('해당 기간에 접수 데이터가 없습니다',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        label,
      ],
    ),
  );
}

// ── 드릴다운 바텀시트 ─────────────────────────────────────────────────────────
class _DrilldownSheet extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final List<InstallationStatus> filterStatuses;
  final List<InstallationRequest> items;
  final String periodStr;
  final String branchStr;

  const _DrilldownSheet({
    required this.label,
    required this.color,
    required this.icon,
    required this.filterStatuses,
    required this.items,
    required this.periodStr,
    required this.branchStr,
  });

  // AIT 담당자 연락처 안내 배너 문구
  static const String _contactGuide =
      '접수 내용 수정 또는 취소가 필요하신 경우,\nAIT 무선검침 담당팀(김승희 010-2708-8570)으로 연락해 주세요.';

  @override
  Widget build(BuildContext context) {
    final sheetH = MediaQuery.of(context).size.height * 0.82;

    return Container(
      height: sheetH,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── 드래그 핸들
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── 시트 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
            child: Row(
              children: [
                // 상태 아이콘
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                // 제목 + 컨텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(label,
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: color,
                            )),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text('${items.length}건',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: color,
                              )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('$branchStr  ·  $periodStr',
                        style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // 닫기 버튼
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // ── AIT 연락처 안내 배너
          //    - 설치완료 건은 수정/취소 대상이 아닐 수 있으나 일관성 있게 노출
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: Color(0xFFB8860B)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(_contactGuide,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B4F00),
                      height: 1.5,
                    )),
                ),
              ],
            ),
          ),

          // ── 목록 or 빈 상태
          Expanded(
            child: items.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _DrilldownCard(
                      item: items[i],
                      statusColor: color,
                      showCompletedDate:
                          filterStatuses.length == 1 &&
                          filterStatuses.first == InstallationStatus.completed,
                      showHoldReason:
                          filterStatuses.length == 1 &&
                          filterStatuses.first == InstallationStatus.onHold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: color.withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Text('해당 기간에 $label 건이 없어요',
          style: const TextStyle(
            fontSize: 14, color: AppTheme.textSecondary)),
      ],
    ),
  );
}

// ── 드릴다운 개별 카드 ─────────────────────────────────────────────────────────
class _DrilldownCard extends StatelessWidget {
  final InstallationRequest item;
  final Color statusColor;
  final bool showCompletedDate; // true → 설치일 / false → 접수일
  final bool showHoldReason;   // true → 보류 사유 뱃지 표시 (설치보류 카드 전용)

  const _DrilldownCard({
    required this.item,
    required this.statusColor,
    required this.showCompletedDate,
    this.showHoldReason = false,
  });

  // 상태별 색상 매핑
  static Color _statusColor(InstallationStatus s) {
    switch (s) {
      case InstallationStatus.completed:  return AppTheme.primary;
      case InstallationStatus.onHold:     return const Color(0xFFEA580C);
      case InstallationStatus.cancelled:  return AppTheme.cancelled;
      case InstallationStatus.scheduled:  return AppTheme.primary;
      case InstallationStatus.confirmed:  return AppTheme.secondary;
      case InstallationStatus.pending:    return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 결정: 설치완료 탭이면 completedAt, 나머지는 createdAt
    final date = (showCompletedDate && item.completedAt != null)
        ? item.completedAt!
        : item.createdAt;
    final dateLabel = (showCompletedDate && item.completedAt != null)
        ? '설치일자'
        : '접수일자';
    final dateFmt = DateFormat('yyyy.MM.dd').format(date);

    // 건물명: buildingName 우선, 없으면 주소 앞부분
    final displayName = (item.buildingName != null &&
            item.buildingName!.isNotEmpty)
        ? item.buildingName!
        : item.address.length > 18
            ? '${item.address.substring(0, 18)}…'
            : item.address;

    final sc = _statusColor(item.status);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1행: 건물명 + 상태 뱃지
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(displayName,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sc.withValues(alpha: 0.35)),
                ),
                child: Text(item.status.label,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── 1.5행: 지사명
          Row(
            children: [
              const Icon(Icons.business_rounded,
                  size: 11, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text(item.branch,
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 7),

          // ── 2행: 건물번호 · 기계실번호 · 설치번호
          Row(
            children: [
              _InfoChip(
                icon: Icons.apartment_rounded,
                text: '건물번호 ${item.buildingNumber}',
              ),
              const SizedBox(width: 6),
              _InfoChip(
                icon: Icons.room_preferences_rounded,
                text: '기계실 ${item.machineRoomNumber}',
              ),
              const SizedBox(width: 6),
              _InfoChip(
                icon: Icons.tag_rounded,
                text: '설치 ${item.installNumber}',
              ),
            ],
          ),
          const SizedBox(height: 7),

          // ── 2.5행: 보류 사유 (설치보류 카드 전용)
          if (showHoldReason && item.holdReason != null && item.holdReason!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.report_problem_outlined,
                      size: 12, color: Color(0xFFEA580C)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '보류 사유: ${item.holdReason}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A3412),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
          ],

          // ── 3행: 연결방식 + 날짜
          Row(
            children: [
              // 연결방식
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLighter,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.device_hub_rounded,
                        size: 11, color: AppTheme.primaryDark),
                    const SizedBox(width: 4),
                    Text(item.connectionType,
                      style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // 날짜
              Row(
                children: [
                  Icon(
                    showCompletedDate && item.completedAt != null
                        ? Icons.check_circle_outline_rounded
                        : Icons.calendar_today_rounded,
                    size: 11, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('$dateLabel  $dateFmt',
                    style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
              const Spacer(),
              // 담당자
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 11, color: AppTheme.textHint),
                  const SizedBox(width: 3),
                  Text(item.managerName,
                    style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 드릴다운 카드 내부 칩
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: AppTheme.textHint),
      const SizedBox(width: 3),
      Text(text,
        style: const TextStyle(
          fontSize: 11, color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500)),
    ],
  );
}
