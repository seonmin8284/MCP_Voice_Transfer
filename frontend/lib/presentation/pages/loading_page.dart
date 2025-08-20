import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voicetransfer/modules/1stt/stt_service_whisper.dart';
import 'package:voicetransfer/modules/1stt/download_model.dart';
import 'package:voicetransfer/presentation/pages/home_page.dart';
import 'package:voicetransfer/utils/utils/timeLogger.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String _status = '초기화 중...';
  double _progress = 0.0;
  bool _isDownloading = false;
  bool _hasError = false;
  String _errorMessage = '';
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    
    // 안전한 초기화를 위해 약간의 지연 후 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // 0. 기본 초기화 확인
      setState(() {
        _status = '기본 환경 확인 중...';
        _isDownloading = false;
        _hasError = false;
      });

      // 1. 로컬 모델 파일 상태 확인
      setState(() {
        _status = '로컬 모델 파일 상태 확인 중...';
        _isDownloading = false;
      });

      bool modelReady = false;
      
      try {
        final directory = await getApplicationDocumentsDirectory();
        final modelStatus = await checkModelStatus(
          model: WhisperModel.baseQ8_0,
          directory: directory.path,
        );

        if (modelStatus['exists'] && modelStatus['isValid']) {
          setState(() {
            _status = '✅ 로컬 모델 파일 발견!\n크기: ${modelStatus['sizeMB']}MB\n수정일: ${_formatModelAge(modelStatus['age'])}';
            _progress = 1.0;
            _hasError = false;
          });
          
          modelReady = true;
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // 2. Whisper 모델 다운로드 시도 (강화된 로직)
          setState(() {
            _status = 'Whisper 모델 다운로드 준비 중...\n모델: base-q8_0 (약 75MB)';
            _isDownloading = true;
            _progress = 0.0;
            _hasError = false;
          });

          try {
            await Future.delayed(const Duration(seconds: 1));
            
            await downloadModel(
              model: WhisperModel.baseQ8_0,
              destinationPath: directory.path,
              maxRetries: 5, // 재시도 횟수 증가
              retryDelay: const Duration(seconds: 3), // 재시도 간격 증가
              onProgress: (downloaded, total) {
                if (mounted) {
                  final progress = downloaded / total;
                  final downloadedMB = (downloaded / 1024 / 1024).toStringAsFixed(2);
                  final totalMB = (total / 1024 / 1024).toStringAsFixed(2);
                  
                  setState(() {
                    _progress = progress;
                    _status = '📥 모델 다운로드 중...\n${(progress * 100).toStringAsFixed(1)}% 완료\n$downloadedMB MB / $totalMB MB';
                  });
                }
              },
            );
            
            // 다운로드 완료 후 최종 검증
            final finalStatus = await checkModelStatus(
              model: WhisperModel.baseQ8_0,
              directory: directory.path,
            );
            
            if (finalStatus['exists'] && finalStatus['isValid']) {
              setState(() {
                _status = '✅ 모델 다운로드 완료!\n크기: ${finalStatus['sizeMB']}MB';
                _progress = 1.0;
                _isDownloading = false;
                _hasError = false;
              });
              
              modelReady = true;
            } else {
              throw Exception('다운로드 완료 후 모델 검증 실패');
            }
            
          } catch (e) {
            if (mounted) {
              setState(() {
                _status = '❌ 모델 다운로드 실패: $e\n\n⚠️ 모델이 필요합니다!\n다시 시도하거나 수동으로 진행하세요.';
                _isDownloading = false;
                _hasError = true;
                _errorMessage = '다운로드 실패: $e';
              });
            }
            
            // 다운로드 실패 시 자동 진행하지 않음
            return;
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = '⚠️ 모델 확인 오류: $e\n\n⚠️ 모델이 필요합니다!\n다시 시도하거나 수동으로 진행하세요.';
            _hasError = true;
            _errorMessage = '모델 확인 오류: $e';
          });
        }
        
        // 모델 확인 오류 시 자동 진행하지 않음
        return;
      }

      // 3. 모델이 준비되지 않았으면 여기서 중단
      if (!modelReady) {
        setState(() {
          _status = '❌ Whisper 모델이 준비되지 않았습니다.\n\n앱을 사용하려면 모델이 필요합니다.\n다시 시도하거나 수동으로 진행하세요.';
          _hasError = true;
          _errorMessage = '모델 준비 실패';
        });
        return;
      }

      // 4. STT 서비스 초기화 (모델이 준비된 후에만)
      setState(() {
        _status = 'STT 서비스 초기화 시도 중...';
        _isDownloading = false;
      });

      try {
        final sttService = SttServiceWhisper();
        final initialized = await sttService.initialize(
          onStatus: (status) {
            if (mounted) {
              setState(() {
                _status = 'STT 초기화: $status';
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _status = 'STT 오류: $error';
                _hasError = true;
                _errorMessage = 'STT 오류: $error';
              });
            }
          },
        );

        if (initialized) {
          setState(() {
            _status = 'STT 초기화 완료!';
            _hasError = false;
          });
        } else {
          setState(() {
            _status = 'STT 초기화 실패했지만 계속 진행합니다...';
            _hasError = true;
            _errorMessage = 'STT 초기화 실패';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = 'STT 초기화 오류: $e\n기본 모드로 진행합니다...';
            _hasError = true;
            _errorMessage = 'STT 초기화 오류: $e';
          });
        }
      }

      // 5. 모든 준비가 완료된 후에만 홈 페이지로 이동
      setState(() {
        _status = '✅ 모든 준비 완료!\n홈 페이지로 이동 중...';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MyHomePage(
              title: 'Voice Transfer',
              initializationTime: _stopwatch.elapsed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '앱 초기화 오류: $e\n\n⚠️ 모델이 필요합니다!\n다시 시도하거나 수동으로 진행하세요.';
          _hasError = true;
          _errorMessage = '앱 초기화 오류: $e';
        });
      }
      
      // 오류 발생 시 자동 진행하지 않음
    }
  }

  /// 모델 파일 나이를 읽기 쉬운 형태로 변환
  String _formatModelAge(Duration? age) {
    if (age == null) return '알 수 없음';
    
    if (age.inDays > 0) {
      return '${age.inDays}일 전';
    } else if (age.inHours > 0) {
      return '${age.inHours}시간 전';
    } else if (age.inMinutes > 0) {
      return '${age.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앱 로고 또는 아이콘
                Icon(
                  Icons.mic,
                  size: 100,
                  color: _hasError ? Colors.orange[600] : Colors.blue[600],
                ),
                const SizedBox(height: 40),
                
                // 앱 제목
                Text(
                  'Voice Transfer',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _hasError ? Colors.orange[800] : Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 60),
                
                // 상태 메시지
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 18,
                    color: _hasError ? Colors.orange[700] : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // 오류 메시지가 있으면 표시
                if (_hasError && _errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      '⚠️ $_errorMessage',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                const SizedBox(height: 30),
                
                // 진행률 바
                if (_isDownloading) ...[
                  SizedBox(
                    width: 300,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // 로딩 스피너 또는 오류 아이콘
                if (!_isDownloading)
                  _hasError
                    ? Icon(
                        Icons.warning,
                        size: 50,
                        color: Colors.orange[600],
                      )
                    : CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                      ),
                
                // 수동 진행 버튼 (오류 시)
                if (_hasError) ...[
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _status = '다시 시도 중...';
                            _hasError = false;
                            _errorMessage = '';
                            _progress = 0.0;
                          });
                          _initializeApp(); // 다시 시도
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                        child: const Text(
                          '🔄 다시 시도',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // 강제로 홈 페이지로 이동 (모델 없이)
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => MyHomePage(
                                title: 'Voice Transfer',
                                initializationTime: _stopwatch.elapsed,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                        child: const Text(
                          '⚠️ 모델 없이 진행',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      '⚠️ 주의: 모델 없이 진행하면 음성 인식 기능이 작동하지 않습니다.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
