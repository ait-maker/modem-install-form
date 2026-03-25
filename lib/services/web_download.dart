// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// 웹 플랫폼에서 CSV 파일 다운로드 (UTF-8 BOM 포함 → 한글 엑셀 호환)
void downloadCsvWeb(String content, String filename) {
  // BOM(0xEF,0xBB,0xBF) + UTF-8 인코딩으로 한글 엑셀 호환
  const bom = '\uFEFF';
  final bytes = utf8.encode(bom + content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
