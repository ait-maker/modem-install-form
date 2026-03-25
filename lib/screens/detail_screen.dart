import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/installation_request.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DetailScreen extends StatelessWidget {
  final InstallationRequest request;
  const DetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.of(context).size.width > 700 ? 680.0 : double.infinity;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('접수 상세 정보'),
        actions: [
          if (request.status != InstallationStatus.completed &&
              request.status != InstallationStatus.cancelled)
            Consumer<DataService>(
              builder: (ctx, service, _) => TextButton.icon(
                onPressed: () => _showCompleteDialog(ctx, service),
                icon: const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppTheme.primary),
                label: const Text('완료 처리',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 16),

                  // 보류 사유 배너
                  if (request.status == InstallationStatus.onHold &&
                      request.holdReason != null)
                    _buildHoldReasonBanner(),

                  // 지사/담당자
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: '지사 및 담당자',
                            icon: Icons.business_rounded),
                        const Divider(height: 20),
                        InfoRow(
                            label: '지사',
                            value: request.branch,
                            highlight: true),
                        const Divider(height: 1),
                        InfoRow(label: '담당자', value: request.managerName),
                        const Divider(height: 1),
                        InfoRow(
                            label: '담당자 연락처',
                            value: request.managerPhone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 설치 위치
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: '설치 위치',
                            icon: Icons.location_on_rounded),
                        const Divider(height: 20),
                        InfoRow(
                            label: '건물번호',
                            value: request.buildingNumber),
                        const Divider(height: 1),
                        InfoRow(label: '설치 주소', value: request.address),
                        const Divider(height: 1),
                        InfoRow(
                            label: '설치번호',
                            value: request.installNumber),
                        const Divider(height: 1),
                        InfoRow(
                            label: '기계실번호',
                            value: request.machineRoomNumber),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 열량계/모뎀
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: '열량계 및 모뎀',
                            icon: Icons.device_hub_rounded),
                        const Divider(height: 20),
                        InfoRow(
                            label: '연결방식',
                            value: request.connectionType,
                            highlight: true),
                        const Divider(height: 1),
                        // 마스터
                        _buildMeterRow(
                          label: request.connectionType == '1:N 연결'
                              ? '마스터 열량계'
                              : '열량계 번호',
                          meterNumber: request.masterMeterNumber,
                          port: request.masterPort,
                          isMaster: true,
                        ),
                        // 슬레이브
                        ...request.slaveMeters.asMap().entries.map((e) {
                          return Column(
                            children: [
                              const Divider(height: 1),
                              _buildMeterRow(
                                label: '슬레이브 ${e.key + 1}',
                                meterNumber: e.value.meterNumber,
                                port: e.value.port,
                              ),
                            ],
                          );
                        }),
                        const Divider(height: 1),
                        InfoRow(
                            label: 'KT 중계기',
                            value: request.ktRelayStatus),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 일정
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: '설치 일정',
                            icon: Icons.calendar_today_rounded),
                        const Divider(height: 20),
                        InfoRow(
                          label: '설치가능 날짜',
                          value: request.availableDate != null
                              ? '${DateFormat('yyyy년 MM월 dd일').format(request.availableDate!)} 이후'
                              : '미정',
                          highlight: request.availableDate != null,
                        ),
                        const Divider(height: 1),
                        InfoRow(
                            label: '관리자 연락처',
                            value: request.buildingManagerPhone),
                        if (request.notes != null &&
                            request.notes!.isNotEmpty) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('기타 사항',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(request.notes!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                          height: 1.6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 완료 메모
                  if (request.status == InstallationStatus.completed &&
                      request.completionNote != null &&
                      request.completionNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                              title: '완료 메모',
                              icon: Icons.check_circle_rounded),
                          const Divider(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLighter,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(request.completionNote!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primaryDark,
                                    height: 1.6)),
                          ),
                          if (request.completedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '완료일시: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(request.completedAt!)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 접수 정보
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('접수번호: ${request.id ?? '-'}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textHint)),
                        ),
                        Text(
                          '접수일: ${DateFormat('yyyy.MM.dd HH:mm').format(request.createdAt)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 열량계 번호 + 포트 행
  Widget _buildMeterRow({
    required String label,
    required String meterNumber,
    required String port,
    bool isMaster = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(meterNumber,
                      style: TextStyle(
                          fontSize: 13,
                          color: isMaster
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: isMaster
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('포트 $port',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final isOnHold = request.status == InstallationStatus.onHold;
    final List<Color> gradColors;
    if (request.status == InstallationStatus.completed) {
      gradColors = [AppTheme.primary, const Color(0xFF059669)];
    } else if (isOnHold) {
      gradColors = [const Color(0xFFEA580C), const Color(0xFFDC2626)];
    } else if (request.status == InstallationStatus.cancelled) {
      gradColors = [AppTheme.error, const Color(0xFFDC2626)];
    } else {
      gradColors = [const Color(0xFF2563EB), AppTheme.secondary];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.address,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                    '${request.branch} · 건물번호 ${request.buildingNumber}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(request.status.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldReasonBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_filled_rounded,
              size: 18, color: Color(0xFFEA580C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('설치 보류 중',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C))),
                Text('보류 사유: ${request.holdReason}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFEA580C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, DataService service) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('설치 완료 처리'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.branch} - ${request.buildingNumber}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(request.address,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40)),
            onPressed: () async {
              await service.updateStatus(
                request.id!,
                InstallationStatus.completed,
                completionNote: noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
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
}
