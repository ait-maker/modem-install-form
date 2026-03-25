import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/installation_request.dart';

// ─── 섹션 헤더 ───────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const SectionHeader({super.key, required this.title, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryLighter,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// ─── 필수 필드 레이블 ─────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const FieldLabel({super.key, required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          if (required)
            const Text('  *', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.error)),
        ],
      ),
    );
  }
}

// ─── 커스텀 텍스트필드 ────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final String? initialValue;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    this.hintText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─── 커스텀 드롭다운 ──────────────────────────────────────────────────────────
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? hintText;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hintText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      validator: validator,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
      decoration: InputDecoration(hintText: hintText),
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(itemLabel(item)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── 상태 배지 ────────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final InstallationStatus status;
  final bool small;
  const StatusBadge({super.key, required this.status, this.small = false});

  Color get _bg {
    switch (status) {
      case InstallationStatus.pending:   return const Color(0xFFFEF3C7);
      case InstallationStatus.confirmed: return const Color(0xFFDBEAFE);
      case InstallationStatus.scheduled: return const Color(0xFFEDE9FE);
      case InstallationStatus.onHold:    return const Color(0xFFFFEDD5);
      case InstallationStatus.completed: return const Color(0xFFD1FAE5);
      case InstallationStatus.cancelled: return const Color(0xFFFEE2E2);
    }
  }

  Color get _fg {
    switch (status) {
      case InstallationStatus.pending:   return const Color(0xFFD97706);
      case InstallationStatus.confirmed: return const Color(0xFF2563EB);
      case InstallationStatus.scheduled: return const Color(0xFF7C3AED);
      case InstallationStatus.onHold:    return const Color(0xFFEA580C);
      case InstallationStatus.completed: return AppTheme.primary;
      case InstallationStatus.cancelled: return AppTheme.error;
    }
  }

  IconData get _icon {
    switch (status) {
      case InstallationStatus.pending:   return Icons.schedule_rounded;
      case InstallationStatus.confirmed: return Icons.check_circle_outline_rounded;
      case InstallationStatus.scheduled: return Icons.calendar_today_rounded;
      case InstallationStatus.onHold:    return Icons.pause_circle_outline_rounded;
      case InstallationStatus.completed: return Icons.check_circle_rounded;
      case InstallationStatus.cancelled: return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = small ? 11.0 : 12.0;
    final iconSize = small ? 12.0 : 14.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: iconSize, color: _fg),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(
            fontSize: fs, fontWeight: FontWeight.w600, color: _fg)),
        ],
      ),
    );
  }
}

// ─── 통계 카드 ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text('$count', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── 정보 행 (상세 보기용) ────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const InfoRow({super.key, required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(
              fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(
              fontSize: 13,
              color: highlight ? AppTheme.primary : AppTheme.textPrimary,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─── 섹션 카드 컨테이너 ───────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const SectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ─── 빈 상태 위젯 ─────────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? subMessage;
  final IconData icon;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.subMessage,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          if (subMessage != null) ...[
            const SizedBox(height: 6),
            Text(subMessage!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }
}
