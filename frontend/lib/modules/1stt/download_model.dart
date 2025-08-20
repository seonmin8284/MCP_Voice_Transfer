/*
 * Copyright (c) 田梓萱[小草林] 2021-2024.
 * All Rights Reserved.
 * All codes are protected by China's regulations on the protection of computer software, and infringement must be investigated.
 * 版权所有 (c) 田梓萱[小草林] 2021-2024.
 * 所有代码均受中国《计算机软件保护条例》保护，侵权必究.
 */

import 'dart:io';
import 'package:http/http.dart' as http;

enum WhisperModel {
  none(""),
  tiny("tiny"),
  tinyQ5_1("tiny-q5_1"),
  tinyQ8_0("tiny-q8_0"),
  tinyEn("tiny.en"),
  tinyEnQ5_1("tiny.en-q5_1"),
  tinyEnQ8_0("tiny.en-q8_0"),
  base("base"),
  baseQ5_1("base-q5_1"),
  baseQ8_0("base-q8_0"),
  baseEn("base.en"),
  baseEnQ5_1("base.en-q5_1"),
  baseEnQ8_0("base.en-q8_0"),
  small("small"),
  smallQ5_1("small-q5_1"),
  smallQ8_0("small-q8_0"),
  smallEn("small.en"),
  smallEnQ5_1("small.en-q5_1"),
  smallEnQ8_0("small.en-q8_0"),
  smallEnTdrz("small.en-tdrz"),
  medium("medium"),
  mediumQ5_0("medium-q5_0"),
  mediumQ8_0("medium-q8_0"),
  mediumEn("medium.en"),
  mediumEnQ5_0("medium.en-q5_0"),
  mediumEnQ8_0("medium.en-q8_0"),
  largeV1("large-v1"),
  largeV2("large-v2"),
  largeV2Q5_0("large-v2-q5_0"),
  largeV2Q8_0("large-v2-q8_0"),
  largeV3("large-v3"),
  largeV3Q5_0("large-v3-q5_0"),
  largeV3Turbo("large-v3-turbo"),
  largeV3TurboQ5_0("large-v3-turbo-q5_0"),
  largeV3TurboQ8_0("large-v3-turbo-q8_0");

  const WhisperModel(this.modelName);
  final String modelName;

  String getPath(String directory) {
    return '$directory/ggml-$modelName.bin';
  }
}

/// 강화된 Whisper 모델 다운로드 함수
/// 
/// [model] 다운로드할 모델
/// [destinationPath] 저장할 경로
/// [downloadHost] 기본 다운로드 호스트 (선택사항)
/// [onProgress] 다운로드 진행률 콜백
/// [maxRetries] 최대 재시도 횟수 (기본값: 3)
/// [retryDelay] 재시도 간격 (기본값: 2초)
Future<String> downloadModel({
  required WhisperModel model,
  required String destinationPath,
  String? downloadHost,
  void Function(int downloaded, int total)? onProgress,
  int maxRetries = 3,
  Duration retryDelay = const Duration(seconds: 2),
}) async {
  final httpClient = HttpClient();
  final modelPath = model.getPath(destinationPath);
  final modelFile = File(modelPath);
  
  // 1. 이미 존재하는 모델 파일 검증
  if (await modelFile.exists()) {
    final fileSize = await modelFile.length();
    if (fileSize > 0) {
      print("✅ 기존 모델 파일 발견: $modelPath (크기: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)");
      
      // 파일 크기 검증 (최소 1MB 이상이어야 함)
      if (fileSize > 1024 * 1024) {
        return modelPath;
      } else {
        print("⚠️ 기존 파일이 너무 작습니다. 재다운로드를 진행합니다.");
        await modelFile.delete();
      }
    }
  }

  // 2. 다운로드 URL 목록 (여러 소스 제공)
  final downloadUrls = [
    // IPv6 주소 (DNS 문제 해결)
    "https://2606:4700::6810:1b3/ggerganov/whisper.cpp/resolve/main/ggml-${model.modelName}.bin",
    // 원본 HuggingFace
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${model.modelName}.bin",
    // 사용자 지정 호스트
    if (downloadHost != null && downloadHost.isNotEmpty)
      "$downloadHost/ggml-${model.modelName}.bin",
    // 대체 CDN
    "https://cdn.huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${model.modelName}.bin",
  ];

  Exception? lastException;
  
  // 3. 여러 URL로 재시도 다운로드
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    for (int urlIndex = 0; urlIndex < downloadUrls.length; urlIndex++) {
      final url = downloadUrls[urlIndex];
      print("🔄 다운로드 시도 $attempt/$maxRetries - URL $urlIndex: $url");
      
      try {
        final result = await _downloadFromUrl(
          url: url,
          modelPath: modelPath,
          onProgress: onProgress,
          attempt: attempt,
        );
        
        if (result) {
          print("✅ 모델 다운로드 성공: $modelPath");
          return modelPath;
        }
      } catch (e) {
        lastException = e as Exception;
        print("❌ 다운로드 실패 (시도 $attempt, URL $urlIndex): $e");
        
        // 잠시 대기 후 다음 URL 시도
        if (urlIndex < downloadUrls.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    // 모든 URL 실패 시 재시도 대기
    if (attempt < maxRetries) {
      print("⏳ $retryDelay 후 재시도...");
      await Future.delayed(retryDelay);
    }
  }
  
  // 4. 모든 시도 실패
  throw Exception("모든 다운로드 시도 실패 (${maxRetries}회). 마지막 오류: $lastException");
}

/// 특정 URL에서 모델 다운로드
Future<bool> _downloadFromUrl({
  required String url,
  required String modelPath,
  void Function(int downloaded, int total)? onProgress,
  required int attempt,
}) async {
  final httpClient = HttpClient();
  final modelFile = File(modelPath);
  
  try {
    final modelUri = Uri.parse(url);
    print("🌐 연결 시도: $url");
    
    final request = await httpClient.getUrl(modelUri);
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    final response = await request.close();
    
    if (response.statusCode != 200) {
      throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
    }
    
    final contentLength = response.contentLength;
    if (contentLength == null || contentLength <= 0) {
      throw Exception("유효하지 않은 파일 크기: $contentLength");
    }
    
    print("📥 다운로드 시작: ${(contentLength / 1024 / 1024).toStringAsFixed(2)}MB");
    
    // 임시 파일로 다운로드 (안전한 다운로드)
    final tempFile = File('$modelPath.tmp');
    final sink = tempFile.openWrite();
    
    int downloaded = 0;
    final stopwatch = Stopwatch()..start();
    
    await for (final chunk in response) {
      sink.add(chunk);
      downloaded += chunk.length;
      
      if (onProgress != null) {
        onProgress(downloaded, contentLength);
      }
      
      // 진행률 로그 (1MB마다)
      if (downloaded % (1024 * 1024) == 0 || downloaded == contentLength) {
        final progress = (downloaded / contentLength * 100).toStringAsFixed(1);
        final speed = (downloaded / 1024 / 1024 / (stopwatch.elapsed.inSeconds + 1)).toStringAsFixed(2);
        print("📊 진행률: $progress% (${(downloaded / 1024 / 1024).toStringAsFixed(2)}MB, 속도: ${speed}MB/s)");
      }
    }
    
    await sink.close();
    
    // 다운로드 완료 검증
    if (await tempFile.exists()) {
      final downloadedSize = await tempFile.length();
      
      if (downloadedSize == contentLength) {
        // 기존 파일이 있으면 백업
        if (await modelFile.exists()) {
          final backupFile = File('$modelPath.backup');
          await modelFile.rename(backupFile.path);
          print("💾 기존 파일 백업: ${backupFile.path}");
        }
        
        // 임시 파일을 최종 파일로 이동
        await tempFile.rename(modelPath);
        
        // 파일 무결성 검증
        final finalSize = await modelFile.length();
        if (finalSize == contentLength) {
          print("✅ 다운로드 완료 및 검증 성공: $modelPath");
          return true;
        } else {
          throw Exception("파일 크기 불일치: 예상 $contentLength, 실제 $finalSize");
        }
      } else {
        throw Exception("다운로드된 파일 크기 불일치: 예상 $contentLength, 실제 $downloadedSize");
      }
    } else {
      throw Exception("임시 파일 생성 실패");
    }
    
  } catch (e) {
    // 임시 파일 정리
    final tempFile = File('$modelPath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    
    rethrow;
  } finally {
    httpClient.close();
  }
}

/// 모델 파일 상태 확인
Future<Map<String, dynamic>> checkModelStatus({
  required WhisperModel model,
  required String directory,
}) async {
  final modelPath = model.getPath(directory);
  final modelFile = File(modelPath);
  
  if (await modelFile.exists()) {
    final fileSize = await modelFile.length();
    final lastModified = await modelFile.lastModified();
    final age = DateTime.now().difference(lastModified);
    
    return {
      'exists': true,
      'path': modelPath,
      'size': fileSize,
      'sizeMB': (fileSize / 1024 / 1024).toStringAsFixed(2),
      'lastModified': lastModified,
      'age': age,
      'isValid': fileSize > 1024 * 1024, // 1MB 이상
    };
  }
  
  return {
    'exists': false,
    'path': modelPath,
    'size': 0,
    'sizeMB': '0.00',
    'lastModified': null,
    'age': null,
    'isValid': false,
  };
}
