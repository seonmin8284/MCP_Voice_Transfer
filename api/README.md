## 🐳 Docker 빌드 및 실행 가이드

### 1. 네트워크 생성
```bash
docker network create voice-network
```

### 2. LLM Qwen API 빌드 및 실행
```bash
cd MCP_Voice_Transfer
docker build -f api/llm_qwen_api/Dockerfile -t qwen-llm-api .
docker run -d --name qwen-llm-api --network voice-network -p 8008:8008 qwen-llm-api
```

### 3. Kokoro TTS API 실행 (이미 빌드된 이미지 사용)
```bash
docker run -d --name backend-kokoro-tts-english --network voice-network -p 7006:7006 kokoro-tts-english:latest
```

### 4. LLM-TTS Pipeline API 빌드 및 실행
```bash
docker build -f api/llm_tts_pipeline_api/Dockerfile -t llm-tts-pipeline-api .
docker run -d --name llm-tts-pipeline-api --network voice-network -p 8009:8009 \
  -e QWEN_LLM_API_URL="http://qwen-llm-api:8008/infer" \
  -e KOKORO_TTS_API_URL="http://backend-kokoro-tts-english:7006/tts" \
  llm-tts-pipeline-api
```

## 🧪 API 테스트

### 1. LLM API 테스트
```bash
curl -X POST "http://localhost:8008/infer" \
  -H "Content-Type: application/json" \
  -d '{"input_text": "오늘 오후 4시까지 엄마한테 4만원 입금해줘", "prompt_version": "prompt4"}'
```