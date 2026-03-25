import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/installation_request.dart';
// branchList는 installation_request.dart에서 export됨

class DataService extends ChangeNotifier {
  static const String _storageKey = 'installation_requests_v2';
  List<InstallationRequest> _requests = [];
  bool _isLoading = false;

  List<InstallationRequest> get requests => List.unmodifiable(_requests);
  bool get isLoading => _isLoading;

  List<InstallationRequest> get pendingRequests => _requests
      .where((r) =>
          r.status != InstallationStatus.completed &&
          r.status != InstallationStatus.cancelled)
      .toList();

  List<InstallationRequest> get completedRequests =>
      _requests.where((r) => r.status == InstallationStatus.completed).toList();

  List<InstallationRequest> getByBranch(String? branch) {
    if (branch == null || branch.isEmpty || branch == '전체') return _requests;
    return _requests.where((r) => r.branch == branch).toList();
  }

  List<InstallationRequest> filterRequests({
    String? branch,
    InstallationStatus? status,
    String? searchQuery,
  }) {
    return _requests.where((r) {
      final branchMatch = branch == null ||
          branch.isEmpty ||
          branch == '전체' ||
          r.branch == branch;
      final statusMatch = status == null || r.status == status;
      final q = searchQuery?.trim().toLowerCase() ?? '';
      final searchMatch = q.isEmpty ||
          r.buildingNumber.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q) ||
          r.masterMeterNumber.toLowerCase().contains(q) ||
          r.managerName.toLowerCase().contains(q) ||
          r.installNumber.toLowerCase().contains(q);
      return branchMatch && statusMatch && searchMatch;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Map<String, int> get statusStats {
    return {
      '접수대기': _requests
          .where((r) => r.status == InstallationStatus.pending)
          .length,
      '접수확인': _requests
          .where((r) => r.status == InstallationStatus.confirmed)
          .length,
      '설치예정': _requests
          .where((r) => r.status == InstallationStatus.scheduled)
          .length,
      '설치보류': _requests
          .where((r) => r.status == InstallationStatus.onHold)
          .length,
      '설치완료': _requests
          .where((r) => r.status == InstallationStatus.completed)
          .length,
      '취소': _requests
          .where((r) => r.status == InstallationStatus.cancelled)
          .length,
    };
  }

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList =
            json.decode(jsonStr) as List<dynamic>;
        _requests = jsonList
            .map((e) => InstallationRequest.fromLocalMap(
                e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('loadRequests error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addRequest(InstallationRequest request) async {
    try {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRequest =
          request.copyWith(id: newId, createdAt: DateTime.now());
      _requests.insert(0, newRequest);
      await _saveToLocal();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('addRequest error: $e');
      return false;
    }
  }

  Future<bool> updateStatus(
    String id,
    InstallationStatus status, {
    String? completionNote,
    String? holdReason,
  }) async {
    try {
      final index = _requests.indexWhere((r) => r.id == id);
      if (index == -1) return false;
      _requests[index] = _requests[index].copyWith(
        status: status,
        holdReason: holdReason,
        completedAt:
            status == InstallationStatus.completed ? DateTime.now() : null,
        completionNote: completionNote,
      );
      await _saveToLocal();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('updateStatus error: $e');
      return false;
    }
  }

  Future<bool> deleteRequest(String id) async {
    try {
      _requests.removeWhere((r) => r.id == id);
      await _saveToLocal();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteRequest error: $e');
      return false;
    }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _requests.map((r) => r.toLocalMap()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  // ══════════════════════════════════════════════════════
  //  통계 집계 메서드
  // ══════════════════════════════════════════════════════

  /// 날짜 범위 필터 (연도 or 연도+월)
  List<InstallationRequest> filterByPeriod({
    required List<InstallationRequest> source,
    required int year,
    int? month, // null이면 연간 전체
  }) {
    return source.where((r) {
      if (r.createdAt.year != year) return false;
      if (month != null && r.createdAt.month != month) return false;
      return true;
    }).toList();
  }

  /// 지사 + 기간 복합 필터
  List<InstallationRequest> filterStat({
    String branch = '전체',
    int? year,
    int? month,
  }) {
    var src = branch == '전체' ? _requests : _requests.where((r) => r.branch == branch).toList();
    if (year != null) {
      src = filterByPeriod(source: src, year: year, month: month);
    }
    return src;
  }

  /// 월별 접수/완료 집계 (해당 연도 전체)
  List<Map<String, dynamic>> monthlyStats({
    String branch = '전체',
    required int year,
  }) {
    final src = filterStat(branch: branch, year: year);
    return List.generate(12, (i) {
      final month = i + 1;
      final monthItems = src.where((r) => r.createdAt.month == month).toList();
      final completed = monthItems.where((r) => r.status == InstallationStatus.completed).length;
      final onHold   = monthItems.where((r) => r.status == InstallationStatus.onHold).length;
      final cancelled = monthItems.where((r) => r.status == InstallationStatus.cancelled).length;
      return {
        'month': month,
        'total': monthItems.length,
        'completed': completed,
        'onHold': onHold,
        'cancelled': cancelled,
        'active': monthItems.length - completed - onHold - cancelled,
      };
    });
  }

  /// 지사별 상태 집계
  List<Map<String, dynamic>> branchStats({
    int? year,
    int? month,
  }) {
    return branchList.map((branch) {
      final items = filterStat(branch: branch, year: year, month: month);
      final total     = items.length;
      final completed = items.where((r) => r.status == InstallationStatus.completed).length;
      final onHold    = items.where((r) => r.status == InstallationStatus.onHold).length;
      final cancelled = items.where((r) => r.status == InstallationStatus.cancelled).length;
      final active    = total - completed - onHold - cancelled;
      final rate      = total > 0 ? (completed / total * 100).round() : 0;
      return {
        'branch': branch,
        'total': total,
        'completed': completed,
        'onHold': onHold,
        'cancelled': cancelled,
        'active': active,
        'rate': rate,
      };
    }).where((m) => m['total'] as int > 0).toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
  }

  /// 보류 사유별 집계
  Map<String, int> holdReasonStats({String branch = '전체', int? year, int? month}) {
    final items = filterStat(branch: branch, year: year, month: month)
        .where((r) => r.status == InstallationStatus.onHold);
    final result = <String, int>{};
    for (final r in items) {
      final reason = r.holdReason ?? '미지정';
      result[reason] = (result[reason] ?? 0) + 1;
    }
    return result;
  }

  /// 연결방식별 집계
  Map<String, int> connectionTypeStats({String branch = '전체', int? year, int? month}) {
    final items = filterStat(branch: branch, year: year, month: month);
    final result = <String, int>{};
    for (final r in items) {
      result[r.connectionType] = (result[r.connectionType] ?? 0) + 1;
    }
    return result;
  }

  /// 평균 완료 소요일 (지사별)
  Map<String, double> avgCompletionDays({int? year, int? month}) {
    final result = <String, double>{};
    for (final branch in branchList) {
      final items = filterStat(branch: branch, year: year, month: month)
          .where((r) => r.status == InstallationStatus.completed && r.completedAt != null)
          .toList();
      if (items.isEmpty) continue;
      final totalDays = items.fold<int>(0, (sum, r) =>
          sum + r.completedAt!.difference(r.createdAt).inDays);
      result[branch] = totalDays / items.length;
    }
    return result;
  }

  /// 존재하는 연도 목록 (최신순)
  List<int> get availableYears {
    final years = _requests.map((r) => r.createdAt.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    if (years.isEmpty) years.add(DateTime.now().year);
    return years;
  }

  /// CSV 생성 (BOM 포함 → Excel 한글 호환)
  String generateCsv(List<InstallationRequest> items) {
    final buf = StringBuffer();
    buf.write('\uFEFF'); // BOM
    buf.writeln(
      '접수번호,지사,담당자,연락처,건물번호,설치주소,설치번호,기계실번호,'
      '마스터열량계번호,마스터포트,연결방식,'
      '슬레이브1번호,슬레이브1포트,슬레이브2번호,슬레이브2포트,슬레이브3번호,슬레이브3포트,'
      'KT중계기,설치가능일,관리자연락처,기타사항,'
      '상태,보류사유,접수일시,완료일시',
    );
    for (final r in items) {
      final s1 = r.slaveMeters.isNotEmpty ? r.slaveMeters[0] : null;
      final s2 = r.slaveMeters.length > 1 ? r.slaveMeters[1] : null;
      final s3 = r.slaveMeters.length > 2 ? r.slaveMeters[2] : null;

      final row = [
        r.id ?? '',
        r.branch,
        r.managerName,
        r.managerPhone,
        r.buildingNumber,
        '"${r.address}"',
        r.installNumber,
        r.machineRoomNumber,
        r.masterMeterNumber,
        r.masterPort,
        r.connectionType,
        s1?.meterNumber ?? '',
        s1?.port ?? '',
        s2?.meterNumber ?? '',
        s2?.port ?? '',
        s3?.meterNumber ?? '',
        s3?.port ?? '',
        r.ktRelayStatus,
        r.availableDate != null
            ? '${r.availableDate!.year}-'
                '${r.availableDate!.month.toString().padLeft(2, '0')}-'
                '${r.availableDate!.day.toString().padLeft(2, '0')}'
            : '',
        r.buildingManagerPhone,
        '"${r.notes ?? ''}"',
        r.status.label,
        r.holdReason ?? '',
        '${r.createdAt.year}-'
            '${r.createdAt.month.toString().padLeft(2, '0')}-'
            '${r.createdAt.day.toString().padLeft(2, '0')}',
        r.completedAt != null
            ? '${r.completedAt!.year}-'
                '${r.completedAt!.month.toString().padLeft(2, '0')}-'
                '${r.completedAt!.day.toString().padLeft(2, '0')}'
            : '',
      ];
      buf.writeln(row.join(','));
    }
    return buf.toString();
  }
}
