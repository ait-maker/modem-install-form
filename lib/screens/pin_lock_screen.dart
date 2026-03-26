import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 관리자 PIN 잠금 화면
/// 올바른 PIN 입력 시 [onUnlocked] 콜백 호출
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String title;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    this.title = '관리자 인증',
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  static const String _correctPin = '0114';
  static const int _pinLength = 4;

  String _input = '';
  bool _isError = false;
  int _failCount = 0;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_input.length >= _pinLength) return;
    setState(() {
      _input += key;
      _isError = false;
    });
    if (_input.length == _pinLength) {
      _checkPin();
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _isError = false;
    });
  }

  void _checkPin() {
    if (_input == _correctPin) {
      widget.onUnlocked();
    } else {
      _failCount++;
      _shakeController.forward(from: 0);
      setState(() {
        _isError = true;
        _input = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 자물쇠 아이콘
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLighter,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryLight, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 타이틀
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _failCount >= 3
                        ? '비밀번호를 ${_failCount}회 잘못 입력했습니다'
                        : 'PIN 4자리를 입력해주세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: _failCount >= 3
                          ? const Color(0xFFDC2626)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN 입력 표시 (흔들림 애니메이션)
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final dx = _isError
                          ? 12 * (0.5 - (_shakeAnimation.value % 1.0)).abs() * 2
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(dx * (_shakeAnimation.value < 0.5 ? 1 : -1), 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (i) {
                        final filled = i < _input.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isError
                                ? const Color(0xFFDC2626)
                                : filled
                                    ? AppTheme.primary
                                    : Colors.transparent,
                            border: Border.all(
                              color: _isError
                                  ? const Color(0xFFDC2626)
                                  : filled
                                      ? AppTheme.primary
                                      : AppTheme.border,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // 오류 메시지
                  AnimatedOpacity(
                    opacity: _isError ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '비밀번호가 올바르지 않습니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 숫자 키패드
                  _buildKeypad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 80, height: 64);
              }
              if (key == '⌫') {
                return _KeyButton(
                  label: key,
                  isDelete: true,
                  onTap: _onDelete,
                );
              }
              return _KeyButton(
                label: key,
                onTap: () => _onKeyTap(key),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String label;
  final bool isDelete;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 72,
        height: 64,
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.primaryLighter
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed ? AppTheme.primary : AppTheme.border,
            width: _pressed ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.0 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: widget.isDelete
              ? Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: _pressed ? AppTheme.primary : AppTheme.textSecondary,
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _pressed ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
