#%%
!pip install -r requirements.txt

import json
import re
import time
import os
import importlib
from mlx_lm import load, generate

# %% data load
# 파일 열기
with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/samples.json", "r", encoding="utf-8") as f:
    samples = json.load(f)

with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/transfer.json", "r", encoding="utf-8") as f:
    transfer = json.load(f)

with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/non_memory.json", "r", encoding="utf-8") as f:
    non_memory = json.load(f)
#%%func
class Qwen3InferenceEngine:
    def __init__(self, model, tokenizer):
        self.model = model
        self.tokenizer = tokenizer
        self.history = []

    def reset_history(self):
        self.history = []

    def run_inference(self, user_input, unified_system_prompt, max_new_tokens=2048, thinking_mode=True):
        # 프롬프트 생성
        user_prompt_text = user_input
        system_prompt = unified_system_prompt(user_input)
        self.history = system_prompt  # system_message 포함

        self.history.append({"role": "user", "content": user_prompt_text})

        # chat template 적용
        prompt = self.tokenizer.apply_chat_template(
            self.history,
            tokenize=False,
            add_generation_prompt=True
        )

        start = time.time()
        response = generate(
            self.model,
            self.tokenizer,
            prompt=prompt,
            max_tokens=max_new_tokens,
            verbose=False
        )
        end = time.time()

        self.history.append({"role": "assistant", "content": response})

        output_text = response.strip()

        match = re.search(r'\{[\s\S]*?\}', output_text)
        if match:
            try:
                parsed_json = json.loads(match.group())
                return output_text, parsed_json, round(end - start, 2)
            except json.JSONDecodeError as e:
                print(f"❌ JSON 파싱 실패: {e}")
        else:
            print("⚠️ JSON 패턴 찾기 실패")

        return output_text, None, round(end - start, 2)


#%%
def evaluate_results(results, samples, total_time):
    correct_intent = 0
    correct_recipient = 0
    correct_amount = 0
    parsing_success = 0

    total = len(samples)

    for result, ex in zip(results, samples):
        meta = result.get("_meta", {})
        if "error" not in meta:
            parsing_success += 1

        if result.get("intent") == ex["intent"]:
            correct_intent += 1
        if result.get("slots", {}).get("recipient") == ex["slots"]["recipient"]:
            correct_recipient += 1
        if result.get("slots", {}).get("amount") == ex["slots"]["amount"]:
            correct_amount += 1

        total_time += meta.get("inference_time", 0)

    average_time = total_time / total if total > 0 else 0

    return {
        "Intent 정확도": f"{correct_intent}/{total} ({correct_intent/total:.0%})",
        "Recipient 정확도": f"{correct_recipient}/{total} ({correct_recipient/total:.0%})",
        "Amount 정확도": f"{correct_amount}/{total} ({correct_amount/total:.0%})",
        "파싱 성공률": f"{parsing_success}/{total} ({parsing_success/total:.0%})",
        "평균 처리 시간": f"{average_time:.4f} 초"
    }

#%% === 예시 사용 ===
if __name__ == "__main__":
    from prompts import unified_system_prompt0 
    model, tokenizer = load("Qwen/Qwen3-0.6B-MLX-8bit")
    engine = Qwen3InferenceEngine(model, tokenizer)

    test_input = "엄마한테 삼만 원 보내줘"
    result, parsed_json, elapsed = engine.run_inference(test_input, unified_system_prompt0, thinking_mode=True)

    print("🔍 추론 결과:", result)
    print("🧩 파싱된 JSON:", parsed_json)
    print("⏱️ 처리 시간:", elapsed, "초")
#%% 인퍼런스 시작
import json
import os
import importlib

model_name = "Qwen/Qwen3-1.7B-MLX-8bit"

model, tokenizer = load(model_name)
engine = Qwen3InferenceEngine(model, tokenizer)

results_summary = {}
prompt_module = importlib.import_module("prompts")

for i in range(1, 7):
    prompt_name = f"unified_system_prompt{i}"
    prompt_fn = getattr(prompt_module, prompt_name, None)

    if prompt_fn is None:
        print(f"❌ {prompt_name} 함수 없음")
        continue

    print(f"\n✅ 실행 중: {prompt_name}")

    parsed_results = []
    raw_outputs = []
    total_time = 0

    for sample in samples:
        result, parsing, elapsed = engine.run_inference(sample["text"], prompt_fn, thinking_mode=True)
        total_time += elapsed

        raw_outputs.append({
            "text": sample["text"],
            "raw_output": result
        })

        if parsing is None:
            parsed_results.append({
                "text": sample["text"],
                "intent": None,
                "slots": {"recipient": None, "amount": None},
                "response": "",
                "_meta": {"error": "Parsing failed", "inference_time": elapsed}
            })
        else:
            parsed_results.append({
                "text": sample["text"],
                "intent": parsing["intent"],
                "slots": {
                    "recipient": parsing.get("recipient"),
                    "amount": parsing.get("amount")
                },
                "response": parsing.get("response"),
                "_meta": {"inference_time": elapsed}
            })

    # 평가 결과 저장
    evaluation = evaluate_results(parsed_results, samples, total_time)
    results_summary[prompt_name] = evaluation

    # 경로 설정
    save_dir = f"results/{model_name}/{prompt_name}"
    os.makedirs(save_dir, exist_ok=True)

    # 저장
    with open(os.path.join(save_dir, "parsed.json"), "w", encoding="utf-8") as f:
        json.dump(parsed_results, f, indent=2, ensure_ascii=False)

    with open(os.path.join(save_dir, "raw_outputs.json"), "w", encoding="utf-8") as f:
        json.dump(raw_outputs, f, indent=2, ensure_ascii=False)

# 전체 결과 요약 출력
print("\n📊 전체 평가 요약")
for name, evaluation in results_summary.items():
    print(f"\n🔹 {name}")
    for metric, value in evaluation.items():
        print(f"  - {metric}: {value}")

#%% 인퍼런스 시작
import json
import os
import importlib

model_name = "Qwen/Qwen3-0.6B-MLX-8bit"

model, tokenizer = load(model_name)
engine = Qwen3InferenceEngine(model, tokenizer)

results_summary = {}
prompt_module = importlib.import_module("prompts")

for i in range(1, 7):
    prompt_name = f"unified_system_prompt{i}"
    prompt_fn = getattr(prompt_module, prompt_name, None)

    if prompt_fn is None:
        print(f"❌ {prompt_name} 함수 없음")
        continue

    print(f"\n✅ 실행 중: {prompt_name}")

    parsed_results = []
    raw_outputs = []
    total_time = 0

    for sample in samples:
        result, parsing, elapsed = engine.run_inference(sample["text"], prompt_fn, thinking_mode=True)
        total_time += elapsed

        raw_outputs.append({
            "text": sample["text"],
            "raw_output": result
        })

        if parsing is None:
            parsed_results.append({
                "text": sample["text"],
                "intent": None,
                "slots": {"recipient": None, "amount": None},
                "response": "",
                "_meta": {"error": "Parsing failed", "inference_time": elapsed}
            })
        else:
            parsed_results.append({
                "text": sample["text"],
                "intent": parsing["intent"],
                "slots": {
                    "recipient": parsing.get("recipient"),
                    "amount": parsing.get("amount")
                },
                "response": parsing.get("response"),
                "_meta": {"inference_time": elapsed}
            })

    # 평가 결과 저장
    evaluation = evaluate_results(parsed_results, samples, total_time)
    results_summary[prompt_name] = evaluation

    # 경로 설정
    save_dir = f"results/{model_name}/{prompt_name}"
    os.makedirs(save_dir, exist_ok=True)

    # 저장
    with open(os.path.join(save_dir, "parsed.json"), "w", encoding="utf-8") as f:
        json.dump(parsed_results, f, indent=2, ensure_ascii=False)

    with open(os.path.join(save_dir, "raw_outputs.json"), "w", encoding="utf-8") as f:
        json.dump(raw_outputs, f, indent=2, ensure_ascii=False)

# 전체 결과 요약 출력
print("\n📊 전체 평가 요약")
for name, evaluation in results_summary.items():
    print(f"\n🔹 {name}")
    for metric, value in evaluation.items():
        print(f"  - {metric}: {value}")

# %%
