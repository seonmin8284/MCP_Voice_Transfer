import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 'package:llama_cpp_dart/llama_cpp_dart.dart'; // 임시 주석 처리
import 'package:flutter/foundation.dart';

//언어모델 프롬프트 수정
// class QwenPromptFormat extends PromptFormat { // 임시 주석 처리
//   QwenPromptFormat()
//     : super(
//         PromptFormatType.chatml,
//         inputSequence: "<|im_start|>user\n",
//         outputSequence: "<|im_end|>\n<|im_start|>assistant\n",
//         systemSequence: "<|im_start|>system\n",
//         stopSequence: "<|im_end|>",
//       );

//   @override
//   String formatPrompt(String prompt) {
//     return """
// <|im_start|>system
// You are a helpful assistant.
// <|im_end|>
// <|im_start|>user
// $prompt
// <|im_end|>
// <|im_start|>assistant
// """;
//   }
// }

Future<String> downloadQwenModel({
  required String modelName,
  required String destinationPath,
}) async {
  final url =
      "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/$modelName";

  final httpClient = HttpClient();
  final request = await httpClient.getUrl(Uri.parse(url));
  final response = await request.close();

  final file = File('$destinationPath/$modelName');
  final raf = file.openSync(mode: FileMode.write);

  final contentLength = response.contentLength;
  int downloadedBytes = 0;

  await for (var chunk in response) {
    downloadedBytes += chunk.length;
    raf.writeFromSync(chunk);

    // 다운로드 진행률 출력
    if (kDebugMode && contentLength > 0) {
      final progress = (downloadedBytes / contentLength * 100).toStringAsFixed(
        2,
      );
      debugPrint("📥 qwen 다운로드 중... $progress%");
    }
  }

  await raf.close();

  if (kDebugMode) {
    debugPrint("✅ Qwen 모델 다운로드 완료: ${file.path}");
  }

  return file.path;
}

class NluService {
  // late final LlamaParent _llamaParent; // 임시 주석 처리
  late final String _localModelPath;
  final StringBuffer _responseBuffer = StringBuffer();
  // Stream<String> get stream => _llamaParent.stream; // 임시 주석 처리
  // Stream<void> get completions => _llamaParent.completions; // 임시 주석 처리
  NluService();

  Future<void> _prepareModel() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelName = 'qwen2.5-0.5b-instruct-q2_k.gguf';
    final file = File('${directory.path}/$modelName');

    if (!(await file.exists())) {
      print('🌐 Qwen 모델 다운로드 시작...');
      _localModelPath = await downloadQwenModel(
        modelName: modelName,
        destinationPath: directory.path,
      );
    } else {
      print('⚡ 이미 모델 파일 존재: ${file.path}');
      _localModelPath = file.path;
    }
  }

  Future<void> initialize() async {
    await _prepareModel();

    // final loadCommand = LlamaLoad( // 임시 주석 처리
    //   path: _localModelPath,
    //   modelParams: ModelParams(),
    //   contextParams: ContextParams(),
    //   samplingParams: SamplerParams(), // 출력 토큰 제한 추가
    //   format: QwenPromptFormat(),
    // );

    // _llamaParent = LlamaParent(loadCommand); // 임시 주석 처리
    // await _llamaParent.init(); // 임시 주석 처리
    print("🟢 [NLU Init] 모델 세션 로딩 성공!");

    // _llamaParent.stream.listen((response) { // 임시 주석 처리
    //   if (response.trim().isEmpty) {
    //     print('🧠 (경고) 빈 응답 수신!');
    //   } else {
    //     _responseBuffer.write(response); // 누적
    //     print('🧠 모델 응답 스트림 수신: "$response"');
    //   }
    // });

    // _llamaParent.completions.listen((event) { // 임시 주석 처리
    //   print('📥 Completion 완료됨: $event');
    //   print('💬 전체 응답 결과: ${_responseBuffer.toString()}');
    //   _responseBuffer.clear(); // 다음 응답 위해 초기화
    // });
  }

  void ask(String inputText) {
    // final prompt = QwenPromptFormat().formatPrompt(inputText); // 임시 주석 처리
    // print('📨 실제 전송될 Prompt: $prompt'); // 임시 주석 처리
    // _llamaParent.sendPrompt(prompt); // 임시 주석 처리
    print('📨 NLU 서비스 임시 비활성화: $inputText');
  }
}
