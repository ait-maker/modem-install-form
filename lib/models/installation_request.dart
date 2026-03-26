import 'package:cloud_firestore/cloud_firestore.dart';

enum InstallationStatus {
  pending,    // 접수대기
  confirmed,  // 접수확인
  scheduled,  // 설치예정
  onHold,     // 설치보류
  completed,  // 설치완료
  cancelled,  // 취소
}

extension InstallationStatusExt on InstallationStatus {
  String get label {
    switch (this) {
      case InstallationStatus.pending:   return '접수대기';
      case InstallationStatus.confirmed: return '접수확인';
      case InstallationStatus.scheduled: return '설치예정';
      case InstallationStatus.onHold:    return '설치보류';
      case InstallationStatus.completed: return '설치완료';
      case InstallationStatus.cancelled: return '접수취소';
    }
  }

  String get value => name;

  static InstallationStatus fromString(String? s) {
    switch (s) {
      case 'confirmed': return InstallationStatus.confirmed;
      case 'scheduled': return InstallationStatus.scheduled;
      case 'onHold':    return InstallationStatus.onHold;
      case 'completed': return InstallationStatus.completed;
      case 'cancelled': return InstallationStatus.cancelled;
      default:          return InstallationStatus.pending;
    }
  }
}

// 보류 사유 목록
const List<String> holdReasonList = [
  'KT중계기 미설치',
  '건물 준공 전',
  '고객 거부',
];

// ── 상태 변경 이력 항목 ──────────────────────────────────────────────────────
class StatusHistoryEntry {
  final InstallationStatus status;
  final DateTime changedAt;
  final String? note; // 완료메모 또는 보류사유

  const StatusHistoryEntry({
    required this.status,
    required this.changedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'status': status.value,
    'changedAt': changedAt.toIso8601String(),
    'note': note ?? '',
  };

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> m) =>
      StatusHistoryEntry(
        status: InstallationStatusExt.fromString(m['status'] as String?),
        changedAt: DateTime.tryParse(m['changedAt'] as String? ?? '') ?? DateTime.now(),
        note: (m['note'] as String?)?.isNotEmpty == true ? m['note'] as String : null,
      );
}

/// 슬레이브 열량계 (번호 + 포트)
class SlaveMeter {
  final String meterNumber;
  final String port;

  const SlaveMeter({required this.meterNumber, required this.port});

  Map<String, String> toMap() => {
    'meterNumber': meterNumber,
    'port': port,
  };

  factory SlaveMeter.fromMap(Map<String, dynamic> m) => SlaveMeter(
    meterNumber: m['meterNumber'] as String? ?? '',
    port: m['port'] as String? ?? '',
  );
}

class InstallationRequest {
  final String? id;
  final String branch;
  final String managerName;
  final String managerPhone;
  final String buildingNumber;
  final String address;
  final String installNumber;
  final String machineRoomNumber;

  // 열량계 - 마스터
  final String masterMeterNumber;
  final String masterPort;

  // 연결방식
  final String connectionType;

  // 슬레이브 (1:N 시 최대 3개)
  final List<SlaveMeter> slaveMeters;

  // 기타
  final String ktRelayStatus;
  final DateTime? availableDate;
  final String buildingManagerPhone;
  final String? notes;

  // ── 상태 및 날짜 이력 (Firebase 연동 후 소요일 통계에 활용) ──────────────
  final InstallationStatus status;
  final String? holdReason;

  final DateTime createdAt;           // 접수일 (자동)
  final DateTime? confirmedAt;        // 접수확인일 (자동)
  final DateTime? scheduledAt;        // 설치예정 처리일 (자동)
  final DateTime? onHoldAt;           // 보류 처리일 (자동)
  final DateTime? completedAt;        // 설치완료일 (자동)
  final DateTime? cancelledAt;        // 취소일 (자동)
  final DateTime? lastStatusChangedAt;// 최종 상태변경일 (자동)

  final String? completionNote;

  // 상태 변경 전체 이력 (Firebase 연동 시 상세 분석에 활용)
  final List<StatusHistoryEntry> statusHistory;

  InstallationRequest({
    this.id,
    required this.branch,
    required this.managerName,
    required this.managerPhone,
    required this.buildingNumber,
    required this.address,
    required this.installNumber,
    required this.machineRoomNumber,
    required this.masterMeterNumber,
    required this.masterPort,
    required this.connectionType,
    this.slaveMeters = const [],
    required this.ktRelayStatus,
    this.availableDate,
    required this.buildingManagerPhone,
    this.notes,
    this.status = InstallationStatus.pending,
    this.holdReason,
    DateTime? createdAt,
    this.confirmedAt,
    this.scheduledAt,
    this.onHoldAt,
    this.completedAt,
    this.cancelledAt,
    this.lastStatusChangedAt,
    this.completionNote,
    this.statusHistory = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  // ── 소요일 계산 헬퍼 (통계 활용용) ─────────────────────────────────────────
  /// 접수 → 완료 소요일
  int? get daysToComplete =>
      completedAt != null ? completedAt!.difference(createdAt).inDays : null;

  /// 접수 → 현재(미완료 기준) 경과일
  int get elapsedDays => DateTime.now().difference(createdAt).inDays;

  /// 마지막 상태 변경까지 소요일
  int? get daysToLastChange =>
      lastStatusChangedAt != null
          ? lastStatusChangedAt!.difference(createdAt).inDays
          : null;

  // ── 직렬화 ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'branch': branch,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'buildingNumber': buildingNumber,
      'address': address,
      'installNumber': installNumber,
      'machineRoomNumber': machineRoomNumber,
      'masterMeterNumber': masterMeterNumber,
      'masterPort': masterPort,
      'connectionType': connectionType,
      'slaveMeters': slaveMeters.map((s) => s.toMap()).toList(),
      'ktRelayStatus': ktRelayStatus,
      'availableDate': availableDate?.toIso8601String() ?? '',
      'buildingManagerPhone': buildingManagerPhone,
      'notes': notes ?? '',
      'status': status.value,
      'holdReason': holdReason ?? '',
      // 날짜 이력
      'createdAt': createdAt.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String() ?? '',
      'scheduledAt': scheduledAt?.toIso8601String() ?? '',
      'onHoldAt': onHoldAt?.toIso8601String() ?? '',
      'completedAt': completedAt?.toIso8601String() ?? '',
      'cancelledAt': cancelledAt?.toIso8601String() ?? '',
      'lastStatusChangedAt': lastStatusChangedAt?.toIso8601String() ?? '',
      'completionNote': completionNote ?? '',
      // 상태 이력
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
    };
  }

  factory InstallationRequest.fromLocalMap(Map<String, dynamic> data) {
    // 슬레이브 파싱
    final rawSlaves = data['slaveMeters'];
    final List<SlaveMeter> slaves = [];
    if (rawSlaves is List) {
      for (final item in rawSlaves) {
        if (item is Map<String, dynamic>) {
          slaves.add(SlaveMeter.fromMap(item));
        }
      }
    }

    // 상태 이력 파싱
    final rawHistory = data['statusHistory'];
    final List<StatusHistoryEntry> history = [];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map<String, dynamic>) {
          history.add(StatusHistoryEntry.fromMap(item));
        }
      }
    }

    DateTime? _parseDate(String key) {
      final v = data[key] as String?;
      return (v != null && v.isNotEmpty) ? DateTime.tryParse(v) : null;
    }

    return InstallationRequest(
      id: data['id'] as String?,
      branch: data['branch'] as String? ?? '',
      managerName: data['managerName'] as String? ?? '',
      managerPhone: data['managerPhone'] as String? ?? '',
      buildingNumber: data['buildingNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      installNumber: data['installNumber'] as String? ?? '',
      machineRoomNumber: data['machineRoomNumber'] as String? ?? '',
      masterMeterNumber: data['masterMeterNumber'] as String? ?? '',
      masterPort: data['masterPort'] as String? ?? '',
      connectionType: data['connectionType'] as String? ?? '1:1 연결',
      slaveMeters: slaves,
      ktRelayStatus: data['ktRelayStatus'] as String? ?? '',
      availableDate: _parseDate('availableDate'),
      buildingManagerPhone: data['buildingManagerPhone'] as String? ?? '',
      notes: (data['notes'] as String?)?.isNotEmpty == true
          ? data['notes'] as String : null,
      status: InstallationStatusExt.fromString(data['status'] as String?),
      holdReason: (data['holdReason'] as String?)?.isNotEmpty == true
          ? data['holdReason'] as String : null,
      createdAt: _parseDate('createdAt') ?? DateTime.now(),
      confirmedAt:  _parseDate('confirmedAt'),
      scheduledAt:  _parseDate('scheduledAt'),
      onHoldAt:     _parseDate('onHoldAt'),
      completedAt:  _parseDate('completedAt'),
      cancelledAt:  _parseDate('cancelledAt'),
      lastStatusChangedAt: _parseDate('lastStatusChangedAt'),
      completionNote: (data['completionNote'] as String?)?.isNotEmpty == true
          ? data['completionNote'] as String : null,
      statusHistory: history,
    );
  }

  /// Firestore 저장용 Map (Timestamp 사용)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'branch': branch,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'buildingNumber': buildingNumber,
      'address': address,
      'installNumber': installNumber,
      'machineRoomNumber': machineRoomNumber,
      'masterMeterNumber': masterMeterNumber,
      'masterPort': masterPort,
      'connectionType': connectionType,
      'slaveMeters': slaveMeters.map((s) => s.toMap()).toList(),
      'ktRelayStatus': ktRelayStatus,
      'availableDate': availableDate?.toIso8601String() ?? '',
      'buildingManagerPhone': buildingManagerPhone,
      'notes': notes ?? '',
      'status': status.value,
      'holdReason': holdReason ?? '',
      // 날짜 (ISO string으로 저장 - 플랫폼 독립적)
      'createdAt': createdAt.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String() ?? '',
      'scheduledAt': scheduledAt?.toIso8601String() ?? '',
      'onHoldAt': onHoldAt?.toIso8601String() ?? '',
      'completedAt': completedAt?.toIso8601String() ?? '',
      'cancelledAt': cancelledAt?.toIso8601String() ?? '',
      'lastStatusChangedAt': lastStatusChangedAt?.toIso8601String() ?? '',
      'completionNote': completionNote ?? '',
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Firestore 문서에서 파싱 (fromLocalMap과 동일 구조)
  factory InstallationRequest.fromFirestoreMap(
      Map<String, dynamic> data, String docId) {
    final rawSlaves = data['slaveMeters'];
    final List<SlaveMeter> slaves = [];
    if (rawSlaves is List) {
      for (final item in rawSlaves) {
        if (item is Map<String, dynamic>) {
          slaves.add(SlaveMeter.fromMap(item));
        }
      }
    }

    final rawHistory = data['statusHistory'];
    final List<StatusHistoryEntry> history = [];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map<String, dynamic>) {
          history.add(StatusHistoryEntry.fromMap(item));
        }
      }
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      // Firestore Timestamp 처리
      if (val.runtimeType.toString().contains('Timestamp')) {
        try {
          return (val as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      return null;
    }

    return InstallationRequest(
      id: data['id'] as String? ?? docId,
      branch: data['branch'] as String? ?? '',
      managerName: data['managerName'] as String? ?? '',
      managerPhone: data['managerPhone'] as String? ?? '',
      buildingNumber: data['buildingNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      installNumber: data['installNumber'] as String? ?? '',
      machineRoomNumber: data['machineRoomNumber'] as String? ?? '',
      masterMeterNumber: data['masterMeterNumber'] as String? ?? '',
      masterPort: data['masterPort'] as String? ?? '',
      connectionType: data['connectionType'] as String? ?? '1:1 연결',
      slaveMeters: slaves,
      ktRelayStatus: data['ktRelayStatus'] as String? ?? '',
      availableDate: parseDate(data['availableDate']),
      buildingManagerPhone: data['buildingManagerPhone'] as String? ?? '',
      notes: (data['notes'] as String?)?.isNotEmpty == true
          ? data['notes'] as String : null,
      status: InstallationStatusExt.fromString(data['status'] as String?),
      holdReason: (data['holdReason'] as String?)?.isNotEmpty == true
          ? data['holdReason'] as String : null,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      confirmedAt: parseDate(data['confirmedAt']),
      scheduledAt: parseDate(data['scheduledAt']),
      onHoldAt: parseDate(data['onHoldAt']),
      completedAt: parseDate(data['completedAt']),
      cancelledAt: parseDate(data['cancelledAt']),
      lastStatusChangedAt: parseDate(data['lastStatusChangedAt']),
      completionNote: (data['completionNote'] as String?)?.isNotEmpty == true
          ? data['completionNote'] as String : null,
      statusHistory: history,
    );
  }

  InstallationRequest copyWith({
    String? id,
    String? branch,
    String? managerName,
    String? managerPhone,
    String? buildingNumber,
    String? address,
    String? installNumber,
    String? machineRoomNumber,
    String? masterMeterNumber,
    String? masterPort,
    String? connectionType,
    List<SlaveMeter>? slaveMeters,
    String? ktRelayStatus,
    DateTime? availableDate,
    String? buildingManagerPhone,
    String? notes,
    InstallationStatus? status,
    String? holdReason,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? scheduledAt,
    DateTime? onHoldAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? lastStatusChangedAt,
    String? completionNote,
    List<StatusHistoryEntry>? statusHistory,
  }) {
    return InstallationRequest(
      id: id ?? this.id,
      branch: branch ?? this.branch,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      address: address ?? this.address,
      installNumber: installNumber ?? this.installNumber,
      machineRoomNumber: machineRoomNumber ?? this.machineRoomNumber,
      masterMeterNumber: masterMeterNumber ?? this.masterMeterNumber,
      masterPort: masterPort ?? this.masterPort,
      connectionType: connectionType ?? this.connectionType,
      slaveMeters: slaveMeters ?? this.slaveMeters,
      ktRelayStatus: ktRelayStatus ?? this.ktRelayStatus,
      availableDate: availableDate ?? this.availableDate,
      buildingManagerPhone: buildingManagerPhone ?? this.buildingManagerPhone,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      holdReason: holdReason ?? this.holdReason,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      onHoldAt: onHoldAt ?? this.onHoldAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      lastStatusChangedAt: lastStatusChangedAt ?? this.lastStatusChangedAt,
      completionNote: completionNote ?? this.completionNote,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}

// 지사 목록 (네이버 폼 기준)
const List<String> branchList = [
  '고양사업소', '분당사업소', '수원사업소', '김해사업소',
  '강남지사', '중앙지사', '삼송지사', '파주지사', '용인지사',
  '판교지사', '광교지사', '동탄지사', '화성지사', '평택지사',
  '청주지사', '세종지사', '대구지사', '양산지사', '광주전남지사',
];
