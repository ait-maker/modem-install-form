import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/installation_request.dart';
// branchList는 installation_request.dart에서 export됨

class DataService extends ChangeNotifier {
  static const String _storageKey = 'installation_requests_v2';
  List<InstallationRequest> _requests = [];
  bool _isLoading = false;

  // Firestore 인스턴스
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _fsCollection = 'installation_requests';

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
      '접수취소': _requests
          .where((r) => r.status == InstallationStatus.cancelled)
          .length,
    };
  }

  Future<void> loadRequests() async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1) 먼저 로컬(SharedPreferences)에서 빠르게 로드
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
        _isLoading = false;
        notifyListeners();
      }

      // 2) Firestore에서 최신 데이터 동기화
      await _syncFromFirestore();
    } catch (e) {
      if (kDebugMode) debugPrint('loadRequests error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Firestore에서 전체 데이터를 로컬로 동기화
  Future<void> _syncFromFirestore() async {
    try {
      final snapshot = await _db
          .collection(_fsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // Firestore가 비어있으면 로컬 데이터를 Firestore에 업로드
        if (_requests.isNotEmpty) {
          await _uploadAllToFirestore();
        }
        return;
      }

      final fsRequests = <InstallationRequest>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final req = InstallationRequest.fromFirestoreMap(data, doc.id);
          fsRequests.add(req);
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing doc ${doc.id}: $e');
        }
      }

      if (fsRequests.isNotEmpty) {
        _requests = fsRequests
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveToLocal();
        notifyListeners();
        if (kDebugMode) debugPrint('Synced ${fsRequests.length} requests from Firestore');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_syncFromFirestore error: $e');
    }
  }

  /// 로컬 데이터 전체를 Firestore에 업로드 (최초 마이그레이션)
  Future<void> _uploadAllToFirestore() async {
    try {
      final batch = _db.batch();
      for (final req in _requests) {
        final ref = _db.collection(_fsCollection).doc(req.id);
        batch.set(ref, req.toFirestoreMap());
      }
      await batch.commit();
      if (kDebugMode) debugPrint('Uploaded ${_requests.length} requests to Firestore');
    } catch (e) {
      if (kDebugMode) debugPrint('_uploadAllToFirestore error: $e');
    }
  }

  /// 단건을 Firestore에 저장/업데이트
  Future<void> _saveToFirestore(InstallationRequest req) async {
    try {
      await _db
          .collection(_fsCollection)
          .doc(req.id)
          .set(req.toFirestoreMap(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('_saveToFirestore error: $e');
    }
  }

  /// 단건을 Firestore에서 삭제
  Future<void> _deleteFromFirestore(String id) async {
    try {
      await _db.collection(_fsCollection).doc(id).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('_deleteFromFirestore error: $e');
    }
  }

  Future<bool> addRequest(InstallationRequest request) async {
    try {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRequest =
          request.copyWith(id: newId, createdAt: DateTime.now());
      _requests.insert(0, newRequest);
      await _saveToLocal();
      // Firestore 동기화 (비동기 - UI 차단 없음)
      unawaited(_saveToFirestore(newRequest));
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

      final now = DateTime.now();
      final req  = _requests[index];

      // 상태별 날짜 자동 기록
      final newHistory = List<StatusHistoryEntry>.from(req.statusHistory)
        ..add(StatusHistoryEntry(
          status: status,
          changedAt: now,
          note: status == InstallationStatus.onHold
              ? holdReason
              : completionNote,
        ));

      _requests[index] = req.copyWith(
        status:    status,
        holdReason: holdReason ?? (status != InstallationStatus.onHold ? null : req.holdReason),
        // 상태별 날짜 자동 세팅
        confirmedAt: status == InstallationStatus.confirmed
            ? (req.confirmedAt ?? now) : req.confirmedAt,
        scheduledAt: status == InstallationStatus.scheduled
            ? (req.scheduledAt ?? now) : req.scheduledAt,
        onHoldAt:    status == InstallationStatus.onHold
            ? now : req.onHoldAt,
        completedAt: status == InstallationStatus.completed
            ? now : req.completedAt,
        cancelledAt: status == InstallationStatus.cancelled
            ? now : req.cancelledAt,
        lastStatusChangedAt: now,
        completionNote: completionNote ?? req.completionNote,
        statusHistory: newHistory,
      );

      await _saveToLocal();
      // Firestore 동기화 (비동기)
      unawaited(_saveToFirestore(_requests[index]));
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
      // Firestore 동기화 (비동기)
      unawaited(_deleteFromFirestore(id));
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
  //  기간 필터 메서드 (대시보드 월별/주별 필터용)
  // ══════════════════════════════════════════════════════

  /// 해당 월의 접수 목록
  List<InstallationRequest> getByMonth(int year, int month, {String branch = '전체'}) {
    return _requests.where((r) {
      final b = branch == '전체' || r.branch == branch;
      return b && r.createdAt.year == year && r.createdAt.month == month;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 해당 주의 접수 목록 (월요일 시작)
  List<InstallationRequest> getByWeek(DateTime weekStart, {String branch = '전체'}) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _requests.where((r) {
      final b = branch == '전체' || r.branch == branch;
      return b &&
          !r.createdAt.isBefore(weekStart) &&
          r.createdAt.isBefore(weekEnd);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 월 기준 상태 통계 요약
  Map<String, int> periodStats(List<InstallationRequest> items) => {
    '전체': items.length,
    '접수대기':  items.where((r) => r.status == InstallationStatus.pending).length,
    '접수확인':  items.where((r) => r.status == InstallationStatus.confirmed).length,
    '설치예정':  items.where((r) => r.status == InstallationStatus.scheduled).length,
    '설치보류':  items.where((r) => r.status == InstallationStatus.onHold).length,
    '설치완료':  items.where((r) => r.status == InstallationStatus.completed).length,
    '접수취소': items.where((r) => r.status == InstallationStatus.cancelled).length,
  };

  /// 이번 달 시작일
  DateTime get thisMonthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// 이번 주 월요일
  DateTime get thisWeekStart {
    final now = DateTime.now();
    final diff = now.weekday - 1; // Monday=1
    return DateTime(now.year, now.month, now.day - diff);
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
