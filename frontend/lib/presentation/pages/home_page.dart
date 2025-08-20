// lib/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicetransfer/modules/2nlu/nlu_provider.dart';
import 'package:voicetransfer/modules/1stt/stt_provider.dart';
import 'package:voicetransfer/presentation/viewmodels/nlu_viewmodel.dart';
import 'package:voicetransfer/presentation/viewmodels/stt_viewmodel.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title, this.initializationTime});
  final String title;
  final Duration? initializationTime;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> messages = [
    {"text": "안녕하세요. 웨비코님!\n오늘은 무엇을 도와드릴까요?", "type": "system"},
  ];

  bool autoSend = false;
  bool _isFirstRun = true;
  final Stopwatch _voiceRecognitionStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _requestPermission();
    
    // 초기화 시간이 있으면 첫 실행으로 간주
    if (widget.initializationTime != null) {
      _isFirstRun = true;
      // 권한 요청 후 자동 마이크 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoVoiceRecognition();
      });
    }
  }

  void _requestPermission() async {
    var status = await Permission.microphone.status;
    var geoStatus = await Permission.location.status;
    if (geoStatus.isDenied) {
      await Permission.location.request();
    }
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) async {
    setState(() {
      messages.add({"text": text, "type": "user"});
      messages.add({"text": "", "type": "system"}); // ✅ 빈 시스템 응답 추가
      _scrollToBottom();
    });

    final chatbotIndex = messages.length - 1; // ✅ 마지막 system 메시지 위치

    try {
      // print("📨 NLU 요청 시작: $text");
      // final nlu = ref.read(nluViewModelProvider);

      // await nlu.generate(
      //   text,
      //   (String finalReply) {
      //     setState(() {
      //       messages[chatbotIndex]["text"] = finalReply; // ✅ 최종 덮어쓰기
      //       _scrollToBottom();
      //     });
      //     print("🧠 생성된 응답: $finalReply");
      //   },
      //   onUpdate: (partial) {
      //     setState(() {
      //       messages[chatbotIndex]["text"] = partial; // ✅ 중간결과 누적 갱신
      //       _scrollToBottom();
      //     });
      //   },
      // );
    } catch (e, stack) {
      print("❌ _handleSubmitted 예외: $e");
      print(stack);
      setState(() {
        messages[chatbotIndex] = {"text": "오류가 발생했어요", "type": "system"};
      });
    }
  }

  void _startAutoVoiceRecognition() async {
    if (!_isFirstRun) return;
    
    // 마이크 권한 확인
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) return;
    }

    // 자동 음성 인식 시작
    setState(() {
      messages.add({"text": "🎤 자동 음성 인식을 시작합니다. 말씀해주세요...", "type": "system"});
      _scrollToBottom();
    });

    // 음성 인식 시작
    _voiceRecognitionStopwatch.start();
    await _startVoiceRecognition();
  }

  Future<void> _startVoiceRecognition() async {
    try {
      final sttViewModel = ref.read(sttViewModelProvider);
      
      await sttViewModel.startListening();
      
      // 결과를 실시간으로 모니터링
      sttViewModel.addListener(() {
        if (sttViewModel.resultText.isNotEmpty) {
          setState(() {
            messages[messages.length - 1]["text"] = "🎧 인식 중: ${sttViewModel.resultText}";
            _scrollToBottom();
          });
        }
        
        if (sttViewModel.state == SttUiState.transcribing) {
          // 음성 인식 완료
          _voiceRecognitionStopwatch.stop();
          final recognitionTime = _voiceRecognitionStopwatch.elapsed;
          
          setState(() {
            messages[messages.length - 1]["text"] = "✅ 인식 완료: ${sttViewModel.resultText}";
            _scrollToBottom();
          });

          // 인식된 텍스트를 입력 필드에 설정
          _textController.text = sttViewModel.resultText;
          
          // 자동 전송
          if (autoSend) {
            _handleSubmitted(sttViewModel.resultText);
          }

          // 시간 측정 결과 표시
          _showTimeMeasurementResult(recognitionTime);
        }
        
        if (sttViewModel.state == SttUiState.error) {
          setState(() {
            messages[messages.length - 1]["text"] = "❌ 오류: ${sttViewModel.errorMessage}";
            _scrollToBottom();
          });
        }
      });
      
    } catch (e) {
      print("❌ 자동 음성 인식 오류: $e");
    }
  }

  void _showTimeMeasurementResult(Duration recognitionTime) {
    final totalTime = widget.initializationTime! + recognitionTime;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏱️ 시간 측정 결과'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🚀 앱 초기화: ${_formatDuration(widget.initializationTime!)}'),
            const SizedBox(height: 8),
            Text('🎤 음성 인식: ${_formatDuration(recognitionTime)}'),
            const SizedBox(height: 8),
            Text('⏱️ 총 소요시간: ${_formatDuration(totalTime)}', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    _isFirstRun = false;
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inMinutes < 1) {
      return '${duration.inSeconds}초';
    } else {
      return '${duration.inMinutes}분 ${duration.inSeconds % 60}초';
    }
  }

  String getStateText({
    required SttUiState sttState,
    required NluUiState nluState,
    required int timestamp,
    int? previousTimestamp,
    int? now,
    String? nluResponse,
    String? nluError,
  }) {
    final current = now ?? DateTime.now().millisecondsSinceEpoch;
    final elapsed = current - timestamp;
    final sinceLast =
        previousTimestamp != null ? timestamp - previousTimestamp : null;

    String label = '';

    // 1. NLU 상태 우선 처리 (성공 or 오류 시 즉시 출력)
    if (nluState == NluUiState.success &&
        nluResponse != null &&
        nluResponse.isNotEmpty) {
      return '✅ 응답: $nluResponse';
    } else if (nluState == NluUiState.error && nluError != null) {
      return '❌ 오류: $nluError';
    }

    // 2. NLU 진행 중 상태 표시
    switch (nluState) {
      case NluUiState.downloadingModel:
        label = "📥 NLU 모델 다운로드 중...";
        break;
      case NluUiState.loadingModel:
        label = "🔧 NLU 모델 로딩 중...";
        break;
      case NluUiState.analyzing:
        label = "🧠 텍스트 분석 중...";
        break;
      default:
        break; // 진행 없음 → STT 상태로 넘어감
    }

    // 3. STT 상태 메시지 출력
    switch (sttState) {
      case SttUiState.downloadingModel:
        label = "📥 STT 모델 다운로드 중...";
        break;
      case SttUiState.initializingModel:
        label = "🔧 STT 모델 초기화 중...";
        break;
      case SttUiState.recording:
        label = "🎙️ 마이크 녹음 중...";
        break;
      case SttUiState.transcribing:
        label = "🧠 음성 → 텍스트 추론 중...";
        break;
      case SttUiState.unloadingModel:
        label = "📤 STT 모델 언로딩 중...";
        break;
      case SttUiState.error:
        label = "❌ STT 오류 발생!";
        break;
      case SttUiState.idle:
      default:
        label = "";
    }

    // 4. 시간 정보 추가
    if (sttState != SttUiState.idle && label.isNotEmpty) {
      label += " (${elapsed}ms 경과";
      if (sinceLast != null) {
        label += ", 이전 상태로부터 +${sinceLast}ms)";
      } else {
        label += ")";
      }
    }

    return label;
  }

  @override
  Widget build(BuildContext context) {
    final sttViewModel = ref.watch(sttViewModelProvider);
    // final nluViewModel = ref.watch(nluViewModelProvider);
    
    // 디바이스의 하단 안전 영역 확인
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false, // 하단 SafeArea는 수동으로 처리
        child: Column(
          children: [
            // 상단 상태 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final sttViewModel = ref.watch(sttViewModelProvider);
                  final now = DateTime.now().millisecondsSinceEpoch;
                  return Text(
                    getStateText(
                      sttState: sttViewModel.state,
                      nluState: NluUiState.idle, // 임시로 idle 상태
                      timestamp: sttViewModel.stateChangedAt,
                      previousTimestamp: sttViewModel.previousStateChangedAt,
                      now: now,
                      nluResponse: null,
                      nluError: null,
                    ),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            ),
            
            // 메시지 영역 (상단에 배치)
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 메시지들
                    for (var message in messages)
                      Align(
                        alignment:
                            message['type'] == 'user'
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                message['type'] == 'user'
                                    ? Colors.brown
                                    : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color:
                                  message['type'] == 'user'
                                      ? Colors.white
                                      : Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // 하단 컨트롤 영역 (안전 영역 고려)
            Container(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 16.0 + bottomPadding, // 하단 안전 영역만큼 여백 추가
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
                // 키보드가 올라올 때 그림자 효과
                boxShadow: keyboardHeight > 0 ? [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8.0,
                    offset: const Offset(0, -2),
                  ),
                ] : null,
              ),
              child: Column(
                children: [
                  // 자동 전송 스위치
                  SwitchListTile(
                    title: const Text("음성 인식 후 자동 전송"),
                    value: autoSend,
                    onChanged: (value) async {
                      setState(() {
                        autoSend = value;
                      });
                      if (value) {
                        await sttViewModel.startListening();

                        if (sttViewModel.resultText.isNotEmpty) {
                          print("📨 STT 결과 자동 제출: ${sttViewModel.resultText}");
                          _handleSubmitted(sttViewModel.resultText);
                        }
                      } else {
                        sttViewModel.stopListening();
                      }
                    },
                  ),
                  
                  // 텍스트 입력 필드
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5.0,
                          offset: Offset(1.5, 1.5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: '궁금한 것을 물어보세요',
                        hintStyle: const TextStyle(color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: Colors.amber),
                          onPressed: () {
                            if (_textController.text.isNotEmpty) {
                              _handleSubmitted(_textController.text);
                              _textController.clear();
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
