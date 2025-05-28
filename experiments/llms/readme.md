## LLM API 실행 방법
CUDA 12.8 환경 기준
Qwen/Qwen2.5-0.5B-Instruct + FastAPI 기반 경량 추론 서버

✅ 1. 필수 패키지 설치
```bash
pip install fastapi uvicorn
pip install transformers==4.50.0
```

✅ 2. FastAPI 서버 실행
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

✅ 3. Swagger UI 접속
브라우저에서 아래 주소 접속:

```bash
http://localhost:8000/docs
```

📦 실행 파일: main.py

📡 엔드포인트: POST /process

입력: { "text": "엄마한테 삼만원 보내줘" }
출력: intent, recipient, amount, response 포함 JSON

## sample 결과

🔹 unified_system_prompt1
  - Intent 정확도: 12/20 (60%)
  - Recipient 정확도: 6/20 (30%)
  - Amount 정확도: 9/20 (45%)
  - 파싱 성공률: 20/20 (100%)
  - 평균 처리 시간: 5.3150 초

🔹 unified_system_prompt2
  - Intent 정확도: 8/20 (40%)
  - Recipient 정확도: 5/20 (25%)
  - Amount 정확도: 11/20 (55%)
  - 파싱 성공률: 15/20 (75%)
  - 평균 처리 시간: 4.2620 초

🔹 unified_system_prompt3
  - Intent 정확도: 13/20 (65%)
  - Recipient 정확도: 8/20 (40%)
  - Amount 정확도: 13/20 (65%)
  - 파싱 성공률: 20/20 (100%)
  - 평균 처리 시간: 4.2940 초

🔹 unified_system_prompt4
  - Intent 정확도: 12/20 (60%)
  - Recipient 정확도: 11/20 (55%)
  - Amount 정확도: 11/20 (55%)
  - 파싱 성공률: 20/20 (100%)
  - 평균 처리 시간: 4.2990 초

🔹 unified_system_prompt5
  - Intent 정확도: 13/20 (65%)
  - Recipient 정확도: 12/20 (60%)
  - Amount 정확도: 11/20 (55%)
  - 파싱 성공률: 20/20 (100%)
  - 평균 처리 시간: 4.0510 초

🔹 unified_system_prompt6
  - Intent 정확도: 12/20 (60%)
  - Recipient 정확도: 9/20 (45%)
  - Amount 정확도: 11/20 (55%)
  - 파싱 성공률: 18/20 (90%)
  - 평균 처리 시간: 4.7310 초
