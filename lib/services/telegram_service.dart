import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/installation_request.dart';

class TelegramService {
  // ── 설정값 ────────────────────────────────────────────────────────────────
  static const String _botToken =
      '8667410051:AAHLR0ngiroRY8AM7LfqfO197i9OewHK83w';
  static const String _chatId = '1718837211';
  static const String _workerUrl =
      'https://telegram-proxy.ksh-8ff.workers.dev/';

  // ── 신규 접수 알림 ─────────────────────────────────────────────────────────
  static Future<void> notifyNewRequest(InstallationRequest req) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${_d(now.month)}-${_d(now.day)} ${_d(now.hour)}:${_d(now.minute)}';

      // 설치 위치 구성
      final locationParts = <String>[];
      if (req.address.isNotEmpty) locationParts.add(req.address);
      if (req.buildingName != null && req.buildingName!.isNotEmpty) {
        locationParts.add('[${req.buildingName}]');
      }
      final locationStr =
          locationParts.isNotEmpty ? locationParts.join(' ') : '-';

      // 기계실 정보 구성
      final machineRoomParts = <String>[];
      if (req.machineRoomNumber.isNotEmpty) {
        machineRoomParts.add('기계실번호 ${req.machineRoomNumber}');
      }
      if (req.installNumber.isNotEmpty) {
        machineRoomParts.add('설치번호 ${req.installNumber}');
      }
      if (req.machineRoomLocation != null &&
          req.machineRoomLocation!.isNotEmpty) {
        machineRoomParts.add('위치: ${req.machineRoomLocation}');
      }
      final machineRoomStr =
          machineRoomParts.isNotEmpty ? machineRoomParts.join(' · ') : '-';

      // 연결방식
      final connStr = req.connectionType.isNotEmpty ? req.connectionType : '-';

      // 슬레이브 정보
      final slaveStr = req.slaveMeters.isNotEmpty
          ? req.slaveMeters
              .map((s) => '${s.meterNumber}(포트${s.port})')
              .join(', ')
          : '없음';

      final message = '''
📬 <b>무선모뎀 신규설치 접수</b>

📋 <b>건물번호:</b> ${req.buildingNumber.isNotEmpty ? req.buildingNumber : '-'}
🏢 <b>지사:</b> ${req.branch.isNotEmpty ? req.branch : '-'}
🏗️ <b>건물명:</b> ${req.buildingName ?? '-'}
📍 <b>설치주소:</b> $locationStr
🔧 <b>기계실:</b> $machineRoomStr

👤 <b>담당자:</b> ${req.managerName.isNotEmpty ? req.managerName : '-'}
📞 <b>담당자 연락처:</b> ${req.managerPhone.isNotEmpty ? req.managerPhone : '-'}
📞 <b>건물관리자:</b> ${req.buildingManagerPhone.isNotEmpty ? req.buildingManagerPhone : '-'}

🔌 <b>연결방식:</b> $connStr
📟 <b>마스터 계량기:</b> ${req.masterMeterNumber.isNotEmpty ? req.masterMeterNumber : '-'} (포트 ${req.masterPort.isNotEmpty ? req.masterPort : '-'})
📟 <b>슬레이브:</b> $slaveStr
📡 <b>KT 중계기:</b> ${req.ktRelayStatus.isNotEmpty ? req.ktRelayStatus : '-'}

⏰ <b>접수시각:</b> $dateStr
${req.notes != null && req.notes!.isNotEmpty ? '\n📝 <b>메모:</b> ${req.notes}' : ''}
🔗 <a href="https://ait-maker.github.io/modem-install-form/">관리 시스템 바로가기</a>''';

      final response = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': _botToken,
              'chat_id': _chatId,
              'text': message,
              'parse_mode': 'HTML',
            }),
          )
          .timeout(const Duration(seconds: 10));

      // 실패 시 HTML 태그 제거 후 plain text로 재시도
      if (response.statusCode != 200) {
        final plainMessage = message
            .replaceAll(RegExp(r'<[^>]+>'), '')  // HTML 태그 제거
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');
        await http
            .post(
              Uri.parse(_workerUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'token': _botToken,
                'chat_id': _chatId,
                'text': plainMessage,
              }),
            )
            .timeout(const Duration(seconds: 10));
      }
      debugPrint('Telegram notify: ${response.statusCode} ${response.body}');
    } catch (e) {
      // 알림 실패는 접수에 영향 없음 — 로그만 남김
      debugPrint('Telegram notify error: $e');
    }
  }

  // 2자리 숫자 포맷 헬퍼
  static String _d(int n) => n.toString().padLeft(2, '0');
}
