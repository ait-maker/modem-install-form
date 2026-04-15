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

  // ── HTML 특수문자 이스케이프 (Worker가 parse_mode:HTML 강제 적용하므로 필수)
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _escN(String? s) => s == null ? '-' : _esc(s);

  // ── 신규 접수 알림 ─────────────────────────────────────────────────────────
  static Future<void> notifyNewRequest(InstallationRequest req) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${_d(now.month)}-${_d(now.day)} ${_d(now.hour)}:${_d(now.minute)}';

      // 설치 위치 구성 (특수문자 이스케이프)
      final locationParts = <String>[];
      if (req.address.isNotEmpty) locationParts.add(_esc(req.address));
      if (req.buildingName != null && req.buildingName!.isNotEmpty) {
        locationParts.add('[${_esc(req.buildingName!)}]');
      }
      final locationStr =
          locationParts.isNotEmpty ? locationParts.join(' ') : '-';

      // 기계실 정보 구성
      final machineRoomParts = <String>[];
      if (req.machineRoomNumber.isNotEmpty) {
        machineRoomParts.add('기계실번호 ${_esc(req.machineRoomNumber)}');
      }
      if (req.installNumber.isNotEmpty) {
        machineRoomParts.add('설치번호 ${_esc(req.installNumber)}');
      }
      if (req.machineRoomLocation != null &&
          req.machineRoomLocation!.isNotEmpty) {
        machineRoomParts.add('위치: ${_esc(req.machineRoomLocation!)}');
      }
      final machineRoomStr =
          machineRoomParts.isNotEmpty ? machineRoomParts.join(' · ') : '-';

      // 연결방식
      final connStr = req.connectionType.isNotEmpty
          ? _esc(req.connectionType) : '-';

      // 슬레이브 정보
      final slaveStr = req.slaveMeters.isNotEmpty
          ? req.slaveMeters
              .map((s) => '${_esc(s.meterNumber)}(포트${_esc(s.port)})')
              .join(', ')
          : '없음';

      final message = '📬 <b>무선모뎀 신규설치 접수</b>\n\n'
          '📋 <b>건물번호:</b> ${req.buildingNumber.isNotEmpty ? _esc(req.buildingNumber) : "-"}\n'
          '🏢 <b>지사:</b> ${req.branch.isNotEmpty ? _esc(req.branch) : "-"}\n'
          '🏗 <b>건물명:</b> ${_escN(req.buildingName)}\n'
          '📍 <b>설치주소:</b> $locationStr\n'
          '🔧 <b>기계실:</b> $machineRoomStr\n\n'
          '👤 <b>담당자:</b> ${req.managerName.isNotEmpty ? _esc(req.managerName) : "-"}\n'
          '📞 <b>담당자 연락처:</b> ${req.managerPhone.isNotEmpty ? _esc(req.managerPhone) : "-"}\n'
          '📞 <b>건물관리자:</b> ${req.buildingManagerPhone.isNotEmpty ? _esc(req.buildingManagerPhone) : "-"}\n\n'
          '🔌 <b>연결방식:</b> $connStr\n'
          '📟 <b>마스터 계량기:</b> ${req.masterMeterNumber.isNotEmpty ? _esc(req.masterMeterNumber) : "-"} (포트 ${req.masterPort.isNotEmpty ? _esc(req.masterPort) : "-"})\n'
          '📟 <b>슬레이브:</b> $slaveStr\n'
          '📡 <b>KT 중계기:</b> ${req.ktRelayStatus.isNotEmpty ? _esc(req.ktRelayStatus) : "-"}\n\n'
          '⏰ <b>접수시각:</b> $dateStr'
          '${req.notes != null && req.notes!.isNotEmpty ? "\n📝 <b>메모:</b> ${_esc(req.notes!)}" : ""}\n'
          '🔗 <a href="https://ait-maker.github.io/modem-install-form/">관리 시스템 바로가기</a>';

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

      debugPrint('Telegram notify: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Telegram notify error: $e');
    }
  }

  // 2자리 숫자 포맷 헬퍼
  static String _d(int n) => n.toString().padLeft(2, '0');
}
