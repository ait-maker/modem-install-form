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
      case InstallationStatus.cancelled: return '취소';
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
  final String masterMeterNumber;   // 마스터 열량계 번호
  final String masterPort;          // 마스터 포트 번호

  // 연결방식
  final String connectionType;      // '1:1 연결' | '1:N 연결'

  // 슬레이브 (1:N 시 최대 3개)
  final List<SlaveMeter> slaveMeters;

  // 기타
  final String ktRelayStatus;
  final DateTime? availableDate;
  final String buildingManagerPhone;
  final String? notes;

  final InstallationStatus status;
  final String? holdReason;         // 설치보류 사유
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? completionNote;

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
    this.completedAt,
    this.completionNote,
  }) : createdAt = createdAt ?? DateTime.now();

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
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String() ?? '',
      'completionNote': completionNote ?? '',
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
      availableDate: (data['availableDate'] as String?)?.isNotEmpty == true
          ? DateTime.tryParse(data['availableDate'] as String)
          : null,
      buildingManagerPhone: data['buildingManagerPhone'] as String? ?? '',
      notes: (data['notes'] as String?)?.isNotEmpty == true
          ? data['notes'] as String
          : null,
      status: InstallationStatusExt.fromString(data['status'] as String?),
      holdReason: (data['holdReason'] as String?)?.isNotEmpty == true
          ? data['holdReason'] as String
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: (data['completedAt'] as String?)?.isNotEmpty == true
          ? DateTime.tryParse(data['completedAt'] as String)
          : null,
      completionNote: (data['completionNote'] as String?)?.isNotEmpty == true
          ? data['completionNote'] as String
          : null,
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
    DateTime? completedAt,
    String? completionNote,
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
      completedAt: completedAt ?? this.completedAt,
      completionNote: completionNote ?? this.completionNote,
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
