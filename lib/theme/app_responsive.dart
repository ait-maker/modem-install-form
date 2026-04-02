import 'package:flutter/material.dart';

/// PC(넓은 화면) 기준: 600px 이상
/// 모든 화면에서 `AppResponsive.of(context)` 로 접근
class AppResponsive {
  final bool isWide;
  final double width;

  const AppResponsive._({required this.isWide, required this.width});

  factory AppResponsive.of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return AppResponsive._(isWide: w >= 600, width: w);
  }

  // ── 스케일 팩터 ──────────────────────────────────────
  /// 1.0 (모바일) ~ 1.6 (PC)
  double get scale => isWide ? 1.6 : 1.0;

  // ── 폰트 크기 ────────────────────────────────────────
  double get fontXs   => isWide ? 14.0 : 10.0;   // 모바일 10 → PC 14
  double get fontSm   => isWide ? 16.0 : 11.0;   // 모바일 11 → PC 16
  double get fontMd   => isWide ? 18.0 : 13.0;   // 모바일 13 → PC 18
  double get fontLg   => isWide ? 22.0 : 15.0;   // 모바일 15 → PC 22
  double get fontXl   => isWide ? 28.0 : 18.0;   // 모바일 18 → PC 28
  double get fontXxl  => isWide ? 34.0 : 22.0;   // 모바일 22 → PC 34
  double get fontHero => isWide ? 42.0 : 26.0;   // 모바일 26 → PC 42

  // ── 아이콘 크기 ──────────────────────────────────────
  double get iconSm  => isWide ? 22.0 : 14.0;
  double get iconMd  => isWide ? 30.0 : 18.0;
  double get iconLg  => isWide ? 40.0 : 24.0;
  double get iconXl  => isWide ? 64.0 : 40.0;

  // ── 여백 ─────────────────────────────────────────────
  double get spaceSm  => isWide ? 12.0 : 6.0;
  double get spaceMd  => isWide ? 22.0 : 12.0;
  double get spaceLg  => isWide ? 32.0 : 20.0;
  double get spaceXl  => isWide ? 44.0 : 24.0;

  // ── 패딩 ─────────────────────────────────────────────
  EdgeInsets get paddingSm => EdgeInsets.all(isWide ? 16.0 : 8.0);
  EdgeInsets get paddingMd => EdgeInsets.all(isWide ? 24.0 : 14.0);
  EdgeInsets get paddingLg => EdgeInsets.all(isWide ? 34.0 : 20.0);

  EdgeInsets get paddingH => EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0);
  EdgeInsets get paddingCard => EdgeInsets.symmetric(
    horizontal: isWide ? 26.0 : 14.0,
    vertical:   isWide ? 22.0 : 12.0,
  );

  // ── 카드/컨테이너 ─────────────────────────────────────
  double get cardRadius   => isWide ? 18.0 : 12.0;
  double get borderRadius => isWide ? 12.0 : 8.0;
  double get cardElevation => isWide ? 4.0 : 1.5;

  // ── 버튼 ─────────────────────────────────────────────
  double get buttonHeight => isWide ? 58.0 : 42.0;
  double get buttonRadius => isWide ? 16.0 : 10.0;

  // ── 헤더 ─────────────────────────────────────────────
  double get headerPadTop    => isWide ? 44.0 : 24.0;
  double get headerPadBottom => isWide ? 48.0 : 28.0;
  double get headerPadH      => isWide ? 36.0 : 20.0;

  // ── 입력 필드 ─────────────────────────────────────────
  double get inputFontSize  => isWide ? 17.0 : 13.0;
  double get inputPadV      => isWide ? 20.0 : 12.0;
  double get inputPadH      => isWide ? 20.0 : 12.0;
  double get labelFontSize  => isWide ? 16.0 : 12.0;

  // ── 하단 내비게이션 ───────────────────────────────────
  double get bottomNavHeight  => isWide ? 80.0 : 58.0;
  double get bottomNavIconSz  => isWide ? 30.0 : 22.0;
  double get bottomNavFontSz  => isWide ? 15.0 : 11.0;

  // ── KPI / 통계 카드 ───────────────────────────────────
  double get kpiValueFont => isWide ? 32.0 : 20.0;   // 모바일 20 → PC 32
  double get kpiLabelFont => isWide ? 15.0 : 11.0;   // 모바일 11 → PC 15
  double get kpiPad       => isWide ? 22.0 : 14.0;
  double get kpiRadius    => isWide ? 16.0 : 12.0;
  double get kpiIconSz    => isWide ? 28.0 : 20.0;   // KPI 전용 아이콘
}
