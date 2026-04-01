import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/installation_request.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'detail_screen.dart';
import '../services/web_download.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// 기간 필터 모드
enum _PeriodMode { monthly, weekly }

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBranch = '전체';
  String _searchQuery = '';

  // 전체현황 탭 기간 필터
  _PeriodMode _periodMode = _PeriodMode.monthly;
  late DateTime _currentMonth;   // 선택된 월의 1일
  late DateTime _currentWeek;    // 선택된 주의 월요일

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    // 이번 주 월요일
    _currentWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        actions: const [],  // 탭별 다운로드 버튼으로 이전
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: '전체 현황'),
            Tab(text: '미완료'),
            Tab(text: '완료'),
          ],
        ),
      ),
      body: SafeArea(
        child: Consumer<DataService>(
          builder: (context, service, _) {
            if (service.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            return Column(
              children: [
                _buildFilterBar(service),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllTab(service),
                      _buildPendingTab(service),
                      _buildCompletedTab(service),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 필터 바 ───────────────────────────────────────────────────────────────────
  Widget _buildFilterBar(DataService service) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '건물번호, 주소, 열량계번호, 담당자 검색',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppTheme.textHint),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.primary)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['전체', ...branchList].map((branch) {
                final isSelected = _selectedBranch == branch;
                final count = branch == '전체'
                    ? service.requests.length
                    : service.getByBranch(branch).length;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBranch = branch),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border),
                    ),
                    child: Text(
                      '$branch ($count)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 전체 현황 탭 ──────────────────────────────────────────────────────────────
  Widget _buildAllTab(DataService service) {
    // 기간 필터 적용된 목록 (전체현황 탭에서는 기간필터 없이 지사+검색만 적용)
    final allItems = service.filterRequests(
        branch: _selectedBranch, searchQuery: _searchQuery);
    final periodItems = _periodMode == _PeriodMode.monthly
        ? service.getByMonth(_currentMonth.year, _currentMonth.month,
            branch: _selectedBranch)
        : service.getByWeek(_currentWeek, branch: _selectedBranch);

    final periodStats = service.periodStats(periodItems);

    // 검색 필터는 기간 필터 위에 추가 적용
    final filtered = _searchQuery.trim().isEmpty
        ? periodItems
        : periodItems.where((r) {
            final q = _searchQuery.trim().toLowerCase();
            return r.buildingNumber.toLowerCase().contains(q) ||
                r.address.toLowerCase().contains(q) ||
                r.masterMeterNumber.toLowerCase().contains(q) ||
                r.managerName.toLowerCase().contains(q) ||
                r.installNumber.toLowerCase().contains(q);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── 월별/주별 모드 토글 + 기간 이동 ──────────────────────────────
          _buildPeriodToggle(),
          const SizedBox(height: 12),

          // ── 기간 통계 카드 ────────────────────────────────────────────────
          _buildPeriodStatCards(periodStats),
          const SizedBox(height: 16),

          // ── 지사별 차트 (전체 선택 시) ────────────────────────────────────
          if (_selectedBranch == '전체' && periodItems.isNotEmpty)
            _buildBranchChart(service),
          if (_selectedBranch == '전체' && periodItems.isNotEmpty)
            const SizedBox(height: 16),

          // ── 접수 목록 ─────────────────────────────────────────────────────
          _buildRequestList(filtered, service),
          const SizedBox(height: 16),

          // ── 다운로드 버튼 3개 ─────────────────────────────────────────────
          _buildDownloadButtons(service, allItems),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 월별/주별 토글 + 기간 이동 버튼 ─────────────────────────────────────────
  Widget _buildPeriodToggle() {
    final isMonthly = _periodMode == _PeriodMode.monthly;

    // 현재 기간 레이블
    String periodLabel;
    if (isMonthly) {
      periodLabel = DateFormat('yyyy년 M월').format(_currentMonth);
    } else {
      final weekEnd = _currentWeek.add(const Duration(days: 6));
      periodLabel =
          '${DateFormat('M/d').format(_currentWeek)} ~ ${DateFormat('M/d').format(weekEnd)}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // 모드 토글
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _periodMode = _PeriodMode.monthly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isMonthly ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('월별',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isMonthly ? Colors.white : AppTheme.textSecondary,
                        )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _periodMode = _PeriodMode.weekly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isMonthly ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('주별',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: !isMonthly ? Colors.white : AppTheme.textSecondary,
                        )),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 기간 이동
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _prevPeriod,
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppTheme.textSecondary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              GestureDetector(
                onTap: _goToday,
                child: Column(
                  children: [
                    Text(periodLabel,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                    if (_isCurrentPeriod())
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLighter,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('현재',
                          style: TextStyle(fontSize: 10,
                              color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _nextPeriod,
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppTheme.textSecondary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 기간 이동 헬퍼
  bool _isCurrentPeriod() {
    final now = DateTime.now();
    if (_periodMode == _PeriodMode.monthly) {
      return _currentMonth.year == now.year && _currentMonth.month == now.month;
    } else {
      final thisWeekMon = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return _currentWeek == thisWeekMon;
    }
  }

  void _prevPeriod() {
    setState(() {
      if (_periodMode == _PeriodMode.monthly) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      } else {
        _currentWeek = _currentWeek.subtract(const Duration(days: 7));
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_periodMode == _PeriodMode.monthly) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      } else {
        _currentWeek = _currentWeek.add(const Duration(days: 7));
      }
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _currentWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    });
  }

  // ── 기간 통계 카드 ──────────────────────────────────────────────────────────
  Widget _buildPeriodStatCards(Map<String, int> stats) {
    final total    = stats['전체'] ?? 0;
    final complete = stats['설치완료'] ?? 0;
    final onHold   = stats['설치보류'] ?? 0;
    final rate     = total > 0 ? (complete / total * 100).round() : 0;

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.6 : 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(label: '기간 접수', count: total,
            color: AppTheme.secondary,   icon: Icons.list_alt_rounded),
        StatCard(label: '설치보류',  count: onHold,
            color: const Color(0xFFEA580C), icon: Icons.pause_circle_outline_rounded,
            onTap: () => _tabController.animateTo(1)),
        StatCard(label: '설치완료',  count: complete,
            color: AppTheme.completed,   icon: Icons.check_circle_rounded,
            onTap: () => _tabController.animateTo(2)),
        StatCard(label: '완료율',    count: rate,
            color: rate >= 70 ? AppTheme.primary : (rate >= 40 ? AppTheme.warning : AppTheme.error),
            icon: Icons.donut_large_rounded,
            suffix: '%'),
      ],
    );
  }

  // ── 미완료 탭 ─────────────────────────────────────────────────────────────────
  Widget _buildPendingTab(DataService service) {
    final allItems = service.filterRequests(
        branch: _selectedBranch, searchQuery: _searchQuery);
    final filtered = allItems
        .where((r) =>
            r.status != InstallationStatus.completed &&
            r.status != InstallationStatus.cancelled)
        .toList();

    return Column(
      children: [
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateWidget(
                  message: '미완료 접수가 없습니다',
                  subMessage: '모든 접수가 완료되었거나 아직 접수가 없습니다',
                  icon: Icons.check_circle_outline_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildRequestCard(filtered[i], service),
                ),
        ),
        _buildDownloadButtons(service, allItems),
      ],
    );
  }

  // ── 완료 탭 ───────────────────────────────────────────────────────────────────
  Widget _buildCompletedTab(DataService service) {
    final allItems = service.filterRequests(
        branch: _selectedBranch, searchQuery: _searchQuery);
    final filtered = allItems
        .where((r) => r.status == InstallationStatus.completed)
        .toList();

    return Column(
      children: [
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateWidget(
                  message: '완료된 설치가 없습니다',
                  subMessage: '설치 완료 처리된 접수가 없습니다',
                  icon: Icons.inbox_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildRequestCard(filtered[i], service),
                ),
        ),
        _buildDownloadButtons(service, allItems),
      ],
    );
  }

  // ── 지사별 바 차트 ────────────────────────────────────────────────────────────
  Widget _buildBranchChart(DataService service) {
    final branchData = <String, Map<String, int>>{};
    for (final req in service.requests) {
      branchData[req.branch] ??= {'total': 0, 'completed': 0, 'pending': 0};
      branchData[req.branch]!['total'] =
          (branchData[req.branch]!['total'] ?? 0) + 1;
      if (req.status == InstallationStatus.completed) {
        branchData[req.branch]!['completed'] =
            (branchData[req.branch]!['completed'] ?? 0) + 1;
      } else {
        branchData[req.branch]!['pending'] =
            (branchData[req.branch]!['pending'] ?? 0) + 1;
      }
    }

    if (branchData.isEmpty) return const SizedBox();
    final maxTotal = branchData.values
        .map((v) => v['total'] ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: '지사별 접수 현황', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 16),
          ...branchData.entries.map((entry) {
            final total = entry.value['total'] ?? 0;
            final completed = entry.value['completed'] ?? 0;
            final pending = entry.value['pending'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(entry.key,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LayoutBuilder(builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                                height: 16,
                                color: AppTheme.border),
                            Row(
                              children: [
                                if (completed > 0)
                                  Container(
                                    width: maxTotal > 0
                                        ? (completed / maxTotal) *
                                            constraints.maxWidth
                                        : 0,
                                    height: 16,
                                    color: AppTheme.primary,
                                  ),
                                if (pending > 0)
                                  Container(
                                    width: maxTotal > 0
                                        ? (pending / maxTotal) *
                                            constraints.maxWidth
                                        : 0,
                                    height: 16,
                                    color: AppTheme.warning
                                        .withValues(alpha: 0.6),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$total건',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendItem(AppTheme.primary, '완료'),
              const SizedBox(width: 12),
              _legendItem(AppTheme.warning.withValues(alpha: 0.6), '미완료'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  // ── 요청 목록 ─────────────────────────────────────────────────────────────────
  Widget _buildRequestList(
      List<InstallationRequest> items, DataService service) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        message: '접수 내역이 없습니다',
        subMessage: '신규 설치 접수 신청을 해주세요',
        icon: Icons.inbox_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('접수 내역 (${items.length}건)',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ),
        ...items.map((req) => _buildRequestCard(req, service)).toList(),
      ],
    );
  }

  // ── 접수 카드 ─────────────────────────────────────────────────────────────────
  Widget _buildRequestCard(
      InstallationRequest req, DataService service) {
    return Dismissible(
      key: ValueKey(req.id),
      direction: DismissDirection.endToStart, // 왼쪽으로 스와이프
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              SizedBox(width: 8),
              Text('접수 삭제'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.address,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${req.branch} · 건물번호 ${req.buildingNumber}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '삭제하면 복구할 수 없습니다.\n정말 삭제하시겠습니까?',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size(80, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        await service.deleteRequest(req.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('접수 내역이 삭제되었습니다'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('삭제', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(request: req)),
      ).then((_) => setState(() {})),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(req.branch,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark)),
                ),
                const Spacer(),
                StatusBadge(status: req.status, small: true),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.address,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.numbers_rounded,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text('건물 ${req.buildingNumber}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 10),
                          const Icon(Icons.memory_rounded,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(req.masterMeterNumber,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text(req.managerName,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text(
                  req.availableDate != null
                      ? DateFormat('MM/dd 이후').format(req.availableDate!)
                      : '날짜 미정',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
                const Spacer(),
                Text(DateFormat('MM.dd HH:mm').format(req.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
            // 보류 사유 배지 표시
            if (req.status == InstallationStatus.onHold &&
                req.holdReason != null &&
                req.holdReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle_outline_rounded,
                          size: 13, color: Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      Text('보류 사유: ${req.holdReason}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            // 액션 버튼
            if (req.status != InstallationStatus.completed &&
                req.status != InstallationStatus.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    // 1행: 상태변경 + 완료처리
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                            ),
                            onPressed: () => _showStatusChangeDialog(
                                context, req, service),
                            icon: const Icon(Icons.swap_horiz_rounded,
                                size: 14),
                            label: const Text('상태 변경',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                            ),
                            onPressed: () =>
                                _showCompleteDialog(context, req, service),
                            icon: const Icon(Icons.check_rounded,
                                size: 14),
                            label: const Text('완료 처리',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 2행: 설치보류 (전체 너비)
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(
                              color: Color(0xFFEA580C), width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () =>
                            _showHoldDialog(context, req, service),
                        icon: const Icon(
                            Icons.pause_circle_outline_rounded,
                            size: 14),
                        label: Text(
                          req.status == InstallationStatus.onHold
                              ? '보류 사유 변경  (현재: ${req.holdReason ?? '-'})'
                              : '설치 보류 처리',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),   // GestureDetector
    );   // Dismissible
  }

  // ── 완료 처리 다이얼로그 ──────────────────────────────────────────────────────
  void _showCompleteDialog(
      BuildContext ctx, InstallationRequest req, DataService service) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('설치 완료 처리'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${req.branch} - ${req.buildingNumber}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(req.address,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            const Text('완료 메모 (선택)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '설치 완료 관련 특이사항을 입력해주세요',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () async {
              Navigator.pop(ctx);
              await service.updateStatus(
                req.id!,
                InstallationStatus.completed,
                completionNote: noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim(),
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text('설치 완료 처리되었습니다'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('완료 처리'),
          ),
        ],
      ),
    );
  }

  // ── 설치보류 전용 다이얼로그 ─────────────────────────────────────────────────
  void _showHoldDialog(
      BuildContext ctx, InstallationRequest req, DataService service) {
    String selectedReason = req.holdReason ?? holdReasonList.first;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.pause_circle_outline_rounded,
                color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('설치 보류 처리'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사이트 정보 요약
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.branch,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark)),
                    const SizedBox(height: 2),
                    Text('건물 ${req.buildingNumber} · ${req.address}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('보류 사유 선택',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              // 보류 사유 라디오 목록
              ...holdReasonList.map((reason) {
                final isSelected = selectedReason == reason;
                return GestureDetector(
                  onTap: () =>
                      setDialogState(() => selectedReason = reason),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFF7ED)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFEA580C)
                            : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFEA580C)
                                  : AppTheme.border,
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFFEA580C)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? const Color(0xFFEA580C)
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                minimumSize: const Size(100, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await service.updateStatus(
                  req.id!,
                  InstallationStatus.onHold,
                  holdReason: selectedReason,
                );
                setState(() {});
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('설치 보류 처리 완료 (사유: $selectedReason)'),
                      backgroundColor: const Color(0xFFEA580C),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              child: const Text('보류 처리',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상태 변경 다이얼로그 (설치보류 포함) ────────────────────────────────────
  void _showStatusChangeDialog(
      BuildContext ctx, InstallationRequest req, DataService service) {
    // 설치보류 선택 시 사용할 사유
    String? selectedHoldReason = req.holdReason ?? holdReasonList.first;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('상태 변경'),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 일반 상태 목록
                  ...[
                    InstallationStatus.pending,
                    InstallationStatus.confirmed,
                    InstallationStatus.scheduled,
                    InstallationStatus.cancelled,
                  ].map((status) => ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 0),
                        leading: StatusBadge(status: status, small: true),
                        trailing: req.status == status &&
                                req.status != InstallationStatus.onHold
                            ? const Icon(Icons.check_rounded,
                                color: AppTheme.primary)
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await service.updateStatus(req.id!, status);
                          setState(() {});
                        },
                      )),

                  // ── 설치보류 (별도 확장 섹션) ─────────────────────────────
                  const Divider(height: 8),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded:
                          req.status == InstallationStatus.onHold,
                      tilePadding: EdgeInsets.zero,
                      leading: const StatusBadge(
                          status: InstallationStatus.onHold, small: true),
                      title: const SizedBox.shrink(),
                      trailing: req.status == InstallationStatus.onHold
                          ? const Icon(Icons.check_rounded,
                              color: Color(0xFFEA580C), size: 18)
                          : const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: AppTheme.textSecondary),
                      children: [
                        // 보류 사유 셀렉트
                        Container(
                          margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFFED7AA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('보류 사유 선택',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEA580C))),
                              const SizedBox(height: 8),
                              ...holdReasonList.map((reason) {
                                final isSelected =
                                    selectedHoldReason == reason;
                                return GestureDetector(
                                  onTap: () => setDialogState(
                                      () => selectedHoldReason = reason),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    margin:
                                        const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFEDD5)
                                          : AppTheme.surface,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFEA580C)
                                            : AppTheme.border,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFFEA580C)
                                                  : AppTheme.border,
                                              width: 2,
                                            ),
                                            color: isSelected
                                                ? const Color(0xFFEA580C)
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  size: 10,
                                                  color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(reason,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isSelected
                                                    ? const Color(
                                                        0xFFEA580C)
                                                    : AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFEA580C),
                                    minimumSize: const Size(0, 40),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await service.updateStatus(
                                      req.id!,
                                      InstallationStatus.onHold,
                                      holdReason: selectedHoldReason,
                                    );
                                    setState(() {});
                                  },
                                  child: const Text('설치보류로 변경'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 탭별 다운로드 버튼 바 (전체 / 미완료 / 설치완료) ────────────────────────
  Widget _buildDownloadButtons(
      DataService service, List<InstallationRequest> allItems) {
    final branch = _selectedBranch;
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

    final pendingItems = allItems
        .where((r) =>
            r.status != InstallationStatus.completed &&
            r.status != InstallationStatus.cancelled)
        .toList();
    final completedItems = allItems
        .where((r) => r.status == InstallationStatus.completed)
        .toList();

    // 텍스트 링크 스타일 인라인 다운로드 버튼 (한 줄, 최소 영역)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.download_rounded,
              size: 11, color: AppTheme.textHint),
          const SizedBox(width: 4),
          Text(
            '다운로드:',
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
          const SizedBox(width: 8),
          _inlineTextBtn(
            label: '전체 ${allItems.length}건',
            enabled: allItems.isNotEmpty,
            onTap: allItems.isEmpty
                ? null
                : () => _doDownload(context, allItems, '${branch}_전체_$dateStr'),
          ),
          _inlineDivider(),
          _inlineTextBtn(
            label: '미완료 ${pendingItems.length}건',
            enabled: pendingItems.isNotEmpty,
            onTap: pendingItems.isEmpty
                ? null
                : () => _doDownload(
                    context, pendingItems, '${branch}_미완료_$dateStr'),
          ),
          _inlineDivider(),
          _inlineTextBtn(
            label: '설치완료 ${completedItems.length}건',
            enabled: completedItems.isNotEmpty,
            onTap: completedItems.isEmpty
                ? null
                : () => _doDownload(
                    context, completedItems, '${branch}_설치완료_$dateStr'),
          ),
        ],
      ),
    );
  }

  Widget _inlineTextBtn({
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: enabled ? AppTheme.primary : AppTheme.textHint,
          decoration: enabled ? TextDecoration.underline : TextDecoration.none,
          decorationColor: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _inlineDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('|',
          style: TextStyle(
              fontSize: 11,
              color: AppTheme.border,
              fontWeight: FontWeight.w300)),
    );
  }

  void _doDownload(BuildContext context, List<InstallationRequest> items,
      String nameSuffix) {
    final service = context.read<DataService>();
    final csv = service.generateCsv(items);
    final filename = '무선모뎀설치접수_$nameSuffix.csv';
    try {
      downloadCsvWeb(csv, filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 실패: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${items.length}건 다운로드 완료 ($filename)'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
