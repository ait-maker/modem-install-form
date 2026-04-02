import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/installation_request.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_responsive.dart';
import '../widgets/common_widgets.dart';

class RegistrationFormScreen extends StatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  State<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // ── Step 1: 지사/담당자
  String? _branch;
  bool _isLoadingManager = false;  // 담당자 정보 로딩 중
  final _managerNameCtrl = TextEditingController();
  final _managerPhoneCtrl = TextEditingController();

  // ── Step 2: 설치 위치
  final _buildingNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _buildingNameCtrl = TextEditingController();      // 건물명 (신규, 필수)
  final _machineRoomLocationCtrl = TextEditingController(); // 기계실위치 (신규, 선택)
  final _machineRoomCtrl = TextEditingController();        // 기계실번호
  final _installNumberCtrl = TextEditingController();      // 설치번호

  // ── Step 3: 장비 정보
  String _connectionType = '1:1 연결';
  // 마스터
  final _masterMeterCtrl = TextEditingController();
  final _masterPortCtrl = TextEditingController();
  // 슬레이브 (최대 3개)
  final List<TextEditingController> _slaveMeterCtrls =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _slavePortCtrls =
      List.generate(3, (_) => TextEditingController());

  String? _ktRelayStatus;

  // ── Step 4: 일정/완료
  DateTime? _availableDate;
  final _buildingManagerPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<String> _steps = ['지사/담당자', '설치 위치', '장비 정보', '일정/완료'];

  @override
  void dispose() {
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    _buildingNumberCtrl.dispose();
    _addressCtrl.dispose();
    _buildingNameCtrl.dispose();
    _machineRoomLocationCtrl.dispose();
    _machineRoomCtrl.dispose();
    _installNumberCtrl.dispose();
    _masterMeterCtrl.dispose();
    _masterPortCtrl.dispose();
    for (final c in _slaveMeterCtrls) c.dispose();
    for (final c in _slavePortCtrls) c.dispose();
    _buildingManagerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = AppResponsive.of(context);
    final maxWidth =
        MediaQuery.of(context).size.width > 700 ? 680.0 : double.infinity;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('무선모뎀 설치 접수',
            style: TextStyle(fontSize: rp.isWide ? 18 : 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showContactInfo(context),
              icon: Icon(Icons.help_outline_rounded,
                  size: rp.isWide ? 20 : 16, color: AppTheme.primary),
              label: Text('문의',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: rp.isWide ? 15 : 13)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                _buildStepIndicator(rp),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          rp.isWide ? 24 : 16,
                          rp.isWide ? 16 : 8,
                          rp.isWide ? 24 : 16,
                          100),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── 스텝 인디케이터 ─────────────────────────────────────────────────────────
  Widget _buildStepIndicator(AppResponsive rp) {
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.fromLTRB(16, rp.isWide ? 16 : 12, 16, rp.isWide ? 16 : 12),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          final circleSize = rp.isWide ? (isActive ? 36.0 : 30.0) : (isActive ? 28.0 : 24.0);
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppTheme.primary
                                  : isActive
                                      ? AppTheme.primary
                                      : AppTheme.border,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDone
                                  ? Icon(Icons.check,
                                      size: rp.isWide ? 18 : 14, color: Colors.white)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: rp.isWide ? 15 : 12,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? Colors.white
                                              : AppTheme.textHint)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: rp.isWide ? 6 : 4),
                      Text(_steps[i],
                          style: TextStyle(
                              fontSize: rp.isWide ? 13 : 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.textHint)),
                    ],
                  ),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.only(bottom: rp.isWide ? 24 : 18),
                      color: i < _currentStep
                          ? AppTheme.primary
                          : AppTheme.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      default: return const SizedBox();
    }
  }

  // ── STEP 1: 지사/담당자 ─────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  title: '지사 및 담당자 정보',
                  icon: Icons.business_rounded),
              const SizedBox(height: 20),
              const FieldLabel(label: '지사 선택', required: true),
              AppDropdown<String>(
                value: _branch,
                items: branchList,
                itemLabel: (s) => s,
                hintText: '지사를 선택해주세요',
                validator: (v) =>
                    v == null || v.isEmpty ? '지사를 선택해주세요' : null,
                onChanged: _onBranchChanged,
              ),
              const SizedBox(height: 16),
              // 담당자 성함
              Row(
                children: [
                  const FieldLabel(label: '담당자 성함', required: true),
                  if (_isLoadingManager) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                    const Text('담당자 정보 불러오는 중...',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  ],
                ],
              ),
              AppTextField(
                controller: _managerNameCtrl,
                hintText: _branch == null
                    ? '지사를 먼저 선택해주세요'
                    : '담당자 성함을 입력해주세요',
                readOnly: _isLoadingManager,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '담당자 성함을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              const FieldLabel(label: '담당자 연락처', required: true),
              AppTextField(
                controller: _managerPhoneCtrl,
                hintText: _branch == null ? '지사를 먼저 선택해주세요' : '010-0000-0000',
                readOnly: _isLoadingManager,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (v) => v == null || v.trim().isEmpty
                    ? '담당자 연락처를 입력해주세요'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoBanner(
          '문의 및 긴급접수',
          'as@ai-telecom.co.kr  |  AIT 김승희 010-2708-8570',
          Icons.support_agent_rounded,
        ),
      ],
    );
  }

  // ── STEP 2: 설치 위치 ───────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  title: '설치 위치 정보', icon: Icons.location_on_rounded),
              const SizedBox(height: 20),

              // ① 건물번호
              const FieldLabel(label: '건물번호', required: true),
              AppTextField(
                controller: _buildingNumberCtrl,
                hintText: '건물번호를 입력해주세요',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '건물번호를 입력해주세요' : null,
              ),
              const SizedBox(height: 16),

              // ② 설치 주소
              const FieldLabel(label: '설치 주소', required: true),
              AppTextField(
                controller: _addressCtrl,
                hintText: '기본 주소를 입력해주세요',
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '설치 주소를 입력해주세요' : null,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded,
                      color: AppTheme.primary),
                  onPressed: () => _showAddressSearch(context),
                ),
              ),
              const SizedBox(height: 16),

              // ③ 건물명 (신규, 필수)
              const FieldLabel(label: '건물명', required: true),
              AppTextField(
                controller: _buildingNameCtrl,
                hintText: '건물명을 입력해주세요 (예: 한빛아파트)',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '건물명을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),

              // ④ 기계실 위치 (신규, 선택)
              const FieldLabel(label: '기계실 위치', required: false),
              AppTextField(
                controller: _machineRoomLocationCtrl,
                hintText: '기계실 위치를 입력해주세요 (예: 지하 1층)',
              ),
              const SizedBox(height: 16),

              // ⑤ 기계실번호 + 설치번호 (순서: 기계실번호 먼저)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel(label: '기계실번호', required: true),
                        AppTextField(
                          controller: _machineRoomCtrl,
                          hintText: '기계실번호',
                          validator: (v) => v == null || v.trim().isEmpty
                              ? '필수'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel(label: '설치번호', required: true),
                        AppTextField(
                          controller: _installNumberCtrl,
                          hintText: '설치번호',
                          validator: (v) => v == null || v.trim().isEmpty
                              ? '필수'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 3: 장비 정보 (핵심 변경) ──────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  title: '열량계 및 모뎀 정보',
                  icon: Icons.device_hub_rounded),
              const SizedBox(height: 20),

              // ── 연결 방식 선택 ──────────────────────────────────────────────
              const FieldLabel(label: '열량계-무선모뎀 연결방식', required: true),
              _buildConnectionTypeSelector(),
              const SizedBox(height: 20),

              // ── 마스터 열량계 (공통) ────────────────────────────────────────
              _buildMasterSection(),
              const SizedBox(height: 16),

              // ── 슬레이브 섹션 (1:N 선택 시) ────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _connectionType == '1:N 연결'
                    ? _buildSlaveSection()
                    : const SizedBox.shrink(),
              ),

              // ── KT 중계기 ──────────────────────────────────────────────────
              const FieldLabel(label: 'KT 중계기 설치확인', required: true),
              _buildKtRelaySelector(),
              if (_ktRelayStatus != null) _buildKtRelayNote(),
            ],
          ),
        ),
      ],
    );
  }

  /// 연결방식 선택 버튼
  Widget _buildConnectionTypeSelector() {
    return Row(
      children: ['1:1 연결', '1:N 연결'].map((type) {
        final selected = _connectionType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _connectionType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                  right: type == '1:1 연결' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryLighter
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    type == '1:1 연결'
                        ? Icons.cable_rounded
                        : Icons.account_tree_rounded,
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(type,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 마스터 열량계 입력 (1:1, 1:N 공통)
  Widget _buildMasterSection() {
    final isMaster = _connectionType == '1:N 연결';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryLighter,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isMaster ? '마스터 열량계' : '열량계 정보',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(
                      label: isMaster ? '마스터 열량계 번호' : '열량계 번호',
                      required: true),
                  AppTextField(
                    controller: _masterMeterCtrl,
                    hintText: '열량계 번호 입력',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? '열량계 번호를 입력해주세요'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel(label: '포트 번호', required: true),
                  AppTextField(
                    controller: _masterPortCtrl,
                    hintText: '포트 번호',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? '포트 번호를 입력해주세요'
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 슬레이브 열량계 입력 (1:N 전용, 최대 3개)
  Widget _buildSlaveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 슬레이브 타이틀
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '슬레이브 열량계 (선택, 최대 3개)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 슬레이브 1~3
        ...List.generate(3, (i) => _buildSlaveRow(i)),
        // 경고 안내 문구
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1:3 이상 다중 연결은 노이즈 발생 등으로 인해 권장하지 않습니다.\n'
                  '필요 시 분리설치로 신규 접수 부탁드립니다.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEA580C),
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlaveRow(int idx) {
    final label = '슬레이브 ${idx + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인덱스 뱃지
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 26, right: 8),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('S${idx + 1}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FieldLabel(label: '$label 열량계 번호'),
                AppTextField(
                  controller: _slaveMeterCtrls[idx],
                  hintText: '슬레이브 열량계 번호 (선택)',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel(label: '포트 번호'),
                AppTextField(
                  controller: _slavePortCtrls[idx],
                  hintText: '포트 번호',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// KT 중계기 선택 라디오
  Widget _buildKtRelaySelector() {
    final options = [
      'KT중계기 설치 확인완료',
      'KT중계기 미설치',
      '확인불가'
    ];
    return Column(
      children: options.map((opt) {
        final selected = _ktRelayStatus == opt;
        return GestureDetector(
          onTap: () => setState(() => _ktRelayStatus = opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryLighter
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    selected ? AppTheme.primary : AppTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: 2),
                    color: selected
                        ? AppTheme.primary
                        : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(opt,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textPrimary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKtRelayNote() {
    late Color bg, fg;
    late IconData icon;
    late String msg;
    if (_ktRelayStatus == 'KT중계기 설치 확인완료') {
      bg = AppTheme.primaryLighter;
      fg = AppTheme.primaryDark;
      icon = Icons.check_circle_rounded;
      msg = 'KT중계기 설치 확인 개소부터 우선적으로 설치가 진행됩니다.';
    } else if (_ktRelayStatus == 'KT중계기 미설치') {
      bg = const Color(0xFFFEE2E2);
      fg = AppTheme.error;
      icon = Icons.warning_rounded;
      msg = '중계기 미설치 시 설치 일정이 지연될 수 있습니다. 계약 시 건물 관리자에게 확인해주세요.';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.help_outline_rounded;
      msg = '중계기 설치 유무는 계약 시 해당 건물 관리자로부터 확인 가능합니다.';
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(fontSize: 11, color: fg))),
        ],
      ),
    );
  }

  // ── STEP 4: 일정/완료 ───────────────────────────────────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  title: '설치 일정 및 연락처',
                  icon: Icons.calendar_today_rounded),
              const SizedBox(height: 20),

              // 설치가능 날짜
              const FieldLabel(label: '설치가능 날짜', required: true),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _availableDate == null
                            ? AppTheme.border
                            : AppTheme.primary,
                        width: _availableDate == null ? 1 : 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18,
                          color: _availableDate == null
                              ? AppTheme.textHint
                              : AppTheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        _availableDate == null
                            ? '날짜를 선택해주세요'
                            : DateFormat('yyyy년 MM월 dd일')
                                .format(_availableDate!),
                        style: TextStyle(
                            fontSize: 14,
                            color: _availableDate == null
                                ? AppTheme.textHint
                                : AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLighter,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '선택일자 이후 설치 가능하다는 의미입니다.\n준공·공사 등으로 설치 가능한 시작일을 선택해주세요.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 건물관리자 연락처 (성함 삭제)
              const FieldLabel(label: '건물관리자 연락처', required: true),
              AppTextField(
                controller: _buildingManagerPhoneCtrl,
                hintText: '건물관리소 또는 담당 관리자 연락처',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (v) => v == null || v.trim().isEmpty
                    ? '건물관리자 연락처를 입력해주세요'
                    : null,
              ),
              const SizedBox(height: 16),

              // 기타 전달 사항
              const FieldLabel(label: '기타 전달 사항'),
              AppTextField(
                controller: _notesCtrl,
                hintText:
                    '담당 엔지니어가 현장 방문 시 참고해야 할 내용을 적어주세요',
                maxLines: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_branch != null) _buildSummaryCard(),
      ],
    );
  }

  // ── 요약 카드 ─────────────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final hasSlaves = _connectionType == '1:N 연결' &&
        _slaveMeterCtrls.any((c) => c.text.trim().isNotEmpty);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded,
                  size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('입력 내용 요약',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20),
          if (_branch != null)
            InfoRow(label: '지사', value: _branch!, highlight: true),
          if (_managerNameCtrl.text.isNotEmpty)
            InfoRow(
                label: '담당자',
                value:
                    '${_managerNameCtrl.text} (${_managerPhoneCtrl.text})'),
          if (_buildingNumberCtrl.text.isNotEmpty)
            InfoRow(label: '건물번호', value: _buildingNumberCtrl.text),
          if (_addressCtrl.text.isNotEmpty)
            InfoRow(label: '설치주소', value: _addressCtrl.text),
          if (_buildingNameCtrl.text.isNotEmpty)
            InfoRow(label: '건물명', value: _buildingNameCtrl.text),
          if (_machineRoomLocationCtrl.text.isNotEmpty)
            InfoRow(label: '기계실위치', value: _machineRoomLocationCtrl.text),
          if (_machineRoomCtrl.text.isNotEmpty)
            InfoRow(label: '기계실번호', value: _machineRoomCtrl.text),
          if (_installNumberCtrl.text.isNotEmpty)
            InfoRow(label: '설치번호', value: _installNumberCtrl.text),
          InfoRow(label: '연결방식', value: _connectionType),
          if (_masterMeterCtrl.text.isNotEmpty)
            InfoRow(
                label: '마스터 열량계',
                value:
                    '${_masterMeterCtrl.text}  포트: ${_masterPortCtrl.text}'),
          if (hasSlaves)
            ...List.generate(3, (i) {
              final m = _slaveMeterCtrls[i].text.trim();
              final p = _slavePortCtrls[i].text.trim();
              if (m.isEmpty) return const SizedBox.shrink();
              return InfoRow(
                  label: '슬레이브 ${i + 1}',
                  value: '$m  포트: $p');
            }),
          if (_ktRelayStatus != null)
            InfoRow(label: 'KT중계기', value: _ktRelayStatus!),
          if (_availableDate != null)
            InfoRow(
                label: '설치가능일',
                value: DateFormat('yyyy년 MM월 dd일')
                    .format(_availableDate!)),
        ],
      ),
    );
  }

  // ── 정보 배너 ─────────────────────────────────────────────────────────────────
  Widget _buildInfoBanner(
      String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0EA5E9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                Text(content,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 버튼 ─────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _currentStep--),
                  icon: const Icon(Icons.chevron_left_rounded,
                      size: 20),
                  label: const Text('이전'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onNextOrSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep < _steps.length - 1
                        ? '다음 단계'
                        : '접수 신청'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 지사 선택 시 담당자 자동입력 ──────────────────────────────────────────────────
  Future<void> _onBranchChanged(String? branch) async {
    if (branch == null) return;
    setState(() {
      _branch = branch;
      _isLoadingManager = true;
    });

    final service = context.read<DataService>();
    final manager = await service.fetchBranchManager(branch);

    if (mounted) {
      setState(() {
        _isLoadingManager = false;
        _managerNameCtrl.text = manager['name'] ?? '';
        _managerPhoneCtrl.text = manager['phone'] ?? '';
      });
    }
  }

  // ── 유효성 검사 & 제출 ────────────────────────────────────────────────────────
  void _onNextOrSubmit() {
    bool valid = true;

    if (_currentStep == 0) {
      if (_branch == null) {
        _showSnack('지사를 선택해주세요');
        return;
      }
      valid = _formKey.currentState!.validate();
    } else if (_currentStep == 2) {
      if (_ktRelayStatus == null) {
        _showSnack('KT중계기 설치 확인 여부를 선택해주세요');
        return;
      }
      valid = _formKey.currentState!.validate();
    } else if (_currentStep == 3) {
      if (_availableDate == null) {
        _showSnack('설치가능 날짜를 선택해주세요');
        return;
      }
      valid = _formKey.currentState!.validate();
    } else {
      valid = _formKey.currentState!.validate();
    }

    if (!valid) return;

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // 슬레이브 목록 수집 (번호가 입력된 것만)
    final slaves = <SlaveMeter>[];
    for (int i = 0; i < 3; i++) {
      final m = _slaveMeterCtrls[i].text.trim();
      if (m.isNotEmpty) {
        slaves.add(SlaveMeter(
            meterNumber: m, port: _slavePortCtrls[i].text.trim()));
      }
    }

    final request = InstallationRequest(
      branch: _branch!,
      managerName: _managerNameCtrl.text.trim(),
      managerPhone: _managerPhoneCtrl.text.trim(),
      buildingNumber: _buildingNumberCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      buildingName: _buildingNameCtrl.text.trim().isEmpty
          ? null : _buildingNameCtrl.text.trim(),
      machineRoomLocation: _machineRoomLocationCtrl.text.trim().isEmpty
          ? null : _machineRoomLocationCtrl.text.trim(),
      installNumber: _installNumberCtrl.text.trim(),
      machineRoomNumber: _machineRoomCtrl.text.trim(),
      masterMeterNumber: _masterMeterCtrl.text.trim(),
      masterPort: _masterPortCtrl.text.trim(),
      connectionType: _connectionType,
      slaveMeters: slaves,
      ktRelayStatus: _ktRelayStatus!,
      availableDate: _availableDate,
      buildingManagerPhone: _buildingManagerPhoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    final service = context.read<DataService>();

    // ── 중복 접수 검사 ────────────────────────────────────────────────────────
    final duplicate = service.findDuplicate(request);
    if (duplicate != null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showDuplicateDialog(duplicate);
      }
      return;
    }

    final success = await service.addRequest(request);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _showSuccessDialog();
      } else {
        _showSnack('접수 저장에 실패했습니다. 다시 시도해주세요.');
      }
    }
  }

  // ── 중복 접수 경고 다이얼로그 ──────────────────────────────────────────────────
  void _showDuplicateDialog(InstallationRequest dup) {
    // 상태 한글 변환 (enum label 확장 활용)
    final statusText = dup.status.label;

    final createdStr =
        '${dup.createdAt.year}-${dup.createdAt.month.toString().padLeft(2, '0')}-${dup.createdAt.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 24),
            SizedBox(width: 8),
            Text(
              '중복 접수 불가',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE53935)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '동일한 위치에 이미 접수된 내역이 있습니다.\n중복 접수는 불가합니다.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF2E7D32)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '기존 접수된 곳으로 빠른 시일 내 설치가 진행될 예정입니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dupInfoRow('건물번호', dup.buildingNumber),
                  _dupInfoRow('기계실번호', dup.machineRoomNumber),
                  _dupInfoRow('설치번호', dup.installNumber),
                  _dupInfoRow('지사', dup.branch),
                  _dupInfoRow('접수일', createdStr),
                  _dupInfoRow('현재 상태', statusText),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0ea271),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인 (접수폼으로 돌아가기)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dupInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF212529),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppTheme.primaryLighter,
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('접수 완료!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('$_branch 무선모뎀 설치 접수가\n성공적으로 완료되었습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.6)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _availableDate = picked);
  }

  void _showAddressSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('주소 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('주소를 직접 입력해주세요',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                  hintText: '예: 경기도 고양시 일산동구 무궁화로 42'),
              maxLines: 2,
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded,
                color: AppTheme.primary),
            SizedBox(width: 8),
            Text('문의 및 긴급접수'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoRow(label: '이메일', value: 'as@ai-telecom.co.kr'),
            InfoRow(label: '담당자', value: 'AIT 김승희'),
            InfoRow(
                label: '연락처',
                value: '010-2708-8570',
                highlight: true),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
