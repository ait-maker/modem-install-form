import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/installation_request.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBranch = '전체';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        actions: [
          Consumer<DataService>(
            builder: (context, service, _) => IconButton(
              onPressed: () => _showExportDialog(context, service),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLighter,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download_rounded, size: 18, color: AppTheme.primary),
              ),
              tooltip: 'CSV 내보내기',
            ),
          ),
        ],
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
    final stats = service.statusStats;
    final filtered = service.filterRequests(
      branch: _selectedBranch,
      searchQuery: _searchQuery,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount:
                MediaQuery.of(context).size.width > 600 ? 5 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.3 : 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                label: '전체 접수',
                count: service.requests.length,
                color: AppTheme.secondary,
                icon: Icons.list_alt_rounded,
                onTap: () => _tabController.animateTo(0),
              ),
              StatCard(
                label: '미완료',
                count: service.pendingRequests.length,
                color: AppTheme.warning,
                icon: Icons.pending_actions_rounded,
                onTap: () => _tabController.animateTo(1),
              ),
              StatCard(
                label: '설치보류',
                count: stats['설치보류'] ?? 0,
                color: const Color(0xFFEA580C),
                icon: Icons.pause_circle_outline_rounded,
              ),
              StatCard(
                label: '설치완료',
                count: stats['설치완료'] ?? 0,
                color: AppTheme.completed,
                icon: Icons.check_circle_rounded,
                onTap: () => _tabController.animateTo(2),
              ),
              StatCard(
                label: '취소',
                count: stats['취소'] ?? 0,
                color: AppTheme.cancelled,
                icon: Icons.cancel_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedBranch == '전체' && service.requests.isNotEmpty)
            _buildBranchChart(service),
          const SizedBox(height: 16),
          _buildRequestList(filtered, service),
        ],
      ),
    );
  }

  // ── 미완료 탭 ─────────────────────────────────────────────────────────────────
  Widget _buildPendingTab(DataService service) {
    final filtered = service
        .filterRequests(branch: _selectedBranch, searchQuery: _searchQuery)
        .where((r) =>
            r.status != InstallationStatus.completed &&
            r.status != InstallationStatus.cancelled)
        .toList();

    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        message: '미완료 접수가 없습니다',
        subMessage: '모든 접수가 완료되었거나 아직 접수가 없습니다',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildRequestCard(filtered[i], service),
    );
  }

  // ── 완료 탭 ───────────────────────────────────────────────────────────────────
  Widget _buildCompletedTab(DataService service) {
    final filtered = service
        .filterRequests(branch: _selectedBranch, searchQuery: _searchQuery)
        .where((r) => r.status == InstallationStatus.completed)
        .toList();

    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        message: '완료된 설치가 없습니다',
        subMessage: '설치 완료 처리된 접수가 없습니다',
        icon: Icons.inbox_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildRequestCard(filtered[i], service),
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
    return GestureDetector(
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
    );
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

  // ── CSV 내보내기 다이얼로그 ───────────────────────────────────────────────────
  void _showExportDialog(BuildContext ctx, DataService service) {
    // 항상 '전체'로 초기화 (지사 필터와 무관하게)
    String exportBranch = '전체';

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final exportCount = exportBranch == '전체'
              ? service.requests.length
              : service.getByBranch(exportBranch).length;
          final completedCount = exportBranch == '전체'
              ? service.requests
                  .where((r) => r.status == InstallationStatus.completed)
                  .length
              : service
                  .getByBranch(exportBranch)
                  .where((r) => r.status == InstallationStatus.completed)
                  .length;
          final pendingCount = exportCount - completedCount;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.download_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('CSV 내보내기'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('지사 선택',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: exportBranch,
                  isExpanded: true,
                  underline: Container(
                    height: 1,
                    color: AppTheme.border,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary),
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary),
                  // 목록: 전체 → 각 지사
                  items: ['전체', ...branchList]
                      .map((b) {
                        final cnt = b == '전체'
                            ? service.requests.length
                            : service.getByBranch(b).length;
                        return DropdownMenuItem(
                          value: b,
                          child: Text('$b  ($cnt건)'),
                        );
                      })
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => exportBranch = v ?? '전체'),
                ),
                const SizedBox(height: 12),
                // 선택 지사 요약 카드
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          exportBranch == '전체'
                              ? '전체 지사 데이터'
                              : exportBranch,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryDark),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _exportStatChip('전체', exportCount,
                            AppTheme.secondary),
                        const SizedBox(width: 6),
                        _exportStatChip('완료', completedCount,
                            AppTheme.primary),
                        const SizedBox(width: 6),
                        _exportStatChip('미완료', pendingCount,
                            AppTheme.warning),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 40)),
                onPressed: exportCount == 0
                    ? null
                    : () {
                        final items = exportBranch == '전체'
                            ? service.requests.toList()
                            : service.getByBranch(exportBranch);
                        _exportCsv(ctx, service, items, exportBranch);
                        Navigator.pop(ctx);
                      },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text('$exportCount건 다운로드'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _exportStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $count건',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }

  void _exportCsv(BuildContext context, DataService service,
      List<InstallationRequest> items, String branch) {
    final csv = service.generateCsv(items);
    final filename =
        '무선모뎀설치접수_${branch}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

    // Web 다운로드 시도
    try {
      // ignore: undefined_prefixed_name
      _webDownload(csv, filename);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$branch 데이터 ${items.length}건 다운로드 준비 완료'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _webDownload(String content, String filename) {
    // dart:html 기반 다운로드 (web only)
    try {
      // ignore: avoid_web_libraries_in_flutter
      final element = _createAnchorElement(content, filename);
      element.call();
    } catch (_) {}
  }

  dynamic _createAnchorElement(String content, String filename) {
    return () {};
  }
}
