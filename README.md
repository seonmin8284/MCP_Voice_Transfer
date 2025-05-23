# MCP_Voice_Transfer

MCP_Voice_Transfer는 **모바일 음성 명령 기반 송금 시스템**을 목표로 합니다.

## 📊 엣지 시스템 아키텍처 개요

![image](https://github.com/user-attachments/assets/15b04290-1225-4669-b176-60f6020ad88e)

## 주요 특징

- **음성 기반 인터페이스** : 웨이크업 키워드 기반 송금 대화, STT + TTS를 통한 자연스러운 사용자 경험 제공
- **sLMs** : sLMs 기반 의도 분석 및 Vector DB 기반 RAG 연계
- **인증 단계 모킹** : 화자 인증을 통한 이상거래탐지 연계
- **이상탐지**

* **예시**:

| 실제 문장                     | STT 결과                 | 의도분석 | 화자 인증 |
| ----------------------------- | ------------------------ | -------- | --------- |
| 엄마한테 오만원 보내줘/Rachel | 엄마 한테 5만 원 보내 줘 | 송금     | True      |
| 보내지마/Rachel               | 보내지마                 | 취소     | True      |
| 엄마한테 오만원 보내줘/Daniel | 엄마 한테 5만 원 보내 줘 | 송금     | False     |

---

## 📑 상세 문서 보기

- [모델 성능 테스트 (STT, NLU)](https://github.com/seonmin8284/MCP_Voice_Transfer/tree/main/experiments)
- [백엔드 API 설명서](./backend/README.md)
- [모바일 앱 구조](./frontend/README.md)

## 전체 시스템 흐름

![dLLVQnfF57sVJt7nQGMJ_7wlWYMM8WJI6h3jKryMtJPIkygwba8fsCG4gHPCeoYfiGPCOe81DNzg8P-cZpkptw7NyRfsOgL_V36vS-wPS-wS6LUpjcxPkLSffiVjj0LYgoSEpaIhmZ9OJyQJ6TsqmHT9vMpRmENQ0BGdQo0A7T6k-NsWPo6SoQZWi9cmqia4n0phTJ9kI13zhGBNrnyYKvCF2w15zAmTtbYRKEA](https://github.com/user-attachments/assets/50a5d7e4-082b-4570-92b2-db86f93f86d5)

1.  **음성 명령**: 사용자가 앱에서 "헤이 플러터, 철수한테 만 원 보내줘" 라고 말합니다.
2.  **Wakeword & STT**: Android 서비스가 Wakeword("헤이 플러터")를 감지하고 음성 인식을 시작하여 텍스트로 변환합니다.
3.  **NLU (의도 분석)**: 변환된 텍스트를 백엔드 LLM 서버로 전달하여 `송금` 의도와 `대상: 철수`, `금액: 10000` 등의 정보를 추출합니다.
4.  **FDS (이상거래 탐지)**: 추출된 송금 정보를 기반으로 이상 거래 여부를 탐지합니다.
5.  **음성 인증**: 등록된 사용자의 목소리가 맞는지 화자 인증을 수행합니다.
6.  **송금 실행**: 모든 검증이 완료되면, 송금 서버에 API를 호출하여 (시뮬레이션) 송금을 실행합니다.
7.  **결과 안내 (TTS)**: 송금 결과를 "철수에게 1만 원 송금했습니다" 와 같이 음성으로 안내합니다.
8.  **UI 업데이트**: 앱 화면에 송금 내역을 표시하고 저장합니다.

</br>

## 🛠️ 기술 스택

- **Backend**: FastAPI (Python), SQLite (기본)
- **LLM & NLU**: Ollama (phi3-mini 등 sLM 기반), EXAONE-DEEP (LG AI Research) 연동 고려
- **Frontend**: Flutter (Cross-platform), Android Native (음성 처리 연동)
- **Voice**: Whisper.cpp, On-Device STT 모델 (연구/개발 중)
- **Auth**: ECAPA-TDNN 등 경량 화자 인식 모델
- **FDS**: Rule-based FDS
- **Infra**: Docker
  </br>

</br>

---

## 👥 팀 역할 분담

| 이름   | 역할                      | 주요 업무                                                                                            | 연락처                |
| ------ | ------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------- |
| 김선민 | 🧭 총괄, 프론트엔드 개발  | 전체 시스템 설계, FastAPI 기반 백엔드 및 Flutter 앱 전체 개발, 폴더 구조/도커화, 음성 송금 기능 구성 | seonmin8284@gmail.com |
| 강병하 | 🧠 음성 AI (STT / TTS)    | STT/TTS API 성능 테스트, 온디바이스 STT 담당, 음성 전,후처리,                                        | kbh0287@gmail.com     |
| 하진   | 🤖 경량 LLM (sLMs / NLU)  | phi3-mini 기반 NLU 처리, 의도 분석/슬롯 추출 설계, RAG 연동 고려                                     | hajin0717@gmail.com   |
| 백두현 | 🔐 보이스 인증 / 화자인식 | ecapa-tdnn 등 경량 음성 인증 모델 탐색, 안티스푸핑 대응 검토                                         |                       |
| 변민찬 | 💡 RAG 흐름               | 서버 기반 RAG 흐름 제안, 의도별 발화 시나리오 설계, LLM 연동 구조 논의                               |                       |

</br>

## 📊 전체 시스템 아키텍처 개요

![시스템 아키텍처](https://github.com/user-attachments/assets/968b7c89-62e3-478b-bbd3-0ebc2809bfc6)

## 🛡️ 보안 주의

> 본 시스템은 실제 금융기관 API를 사용하지 않으며,  
> 모든 송금 처리와 인증은 **더미 데이터 기반 시뮬레이션**으로 동작합니다.
