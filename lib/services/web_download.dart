import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// 웹 플랫폼에서 CSV 파일 다운로드 (UTF-8 BOM 포함 → 한글 엑셀 호환)
void downloadCsvWeb(String content, String filename) {
  // BOM(0xEF,0xBB,0xBF) + UTF-8 인코딩으로 한글 엑셀 호환
  const bom = '\uFEFF';
  final bytes = utf8.encode(bom + content);

  // Uint8Array로 변환
  final jsArray = bytes.toJS;

  // Blob 생성 (text/csv + charset=utf-8)
  final blobParts = [jsArray].toJS;
  final blobOptions = web.BlobPropertyBag(type: 'text/csv;charset=utf-8');
  final blob = web.Blob(blobParts, blobOptions);

  // Object URL 생성
  final url = web.URL.createObjectURL(blob);

  // 임시 <a> 태그로 다운로드 트리거
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  web.document.body!.removeChild(anchor);

  // Object URL 해제
  web.URL.revokeObjectURL(url);
}
