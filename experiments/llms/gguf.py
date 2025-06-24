# %% library load
!pip install -r requirements.txt
import sys
sys.path.append("/Users/hajin/Projects|/MCP_Voice_Transfer/experiments/llms")
import os
import json
import importlib
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from runner import llm_sampling, run_inference, evaluate_results


# %% data load
# 파일 열기
with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/samples.json", "r", encoding="utf-8") as f:
    samples = json.load(f)

with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/transfer.json", "r", encoding="utf-8") as f:
    transfer = json.load(f)

with open("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms/data/non_memory.json", "r", encoding="utf-8") as f:
    non_memory = json.load(f)

print(f"샘플 수: {len(samples)}")
#%% model load
from llama_cpp import Llama

model = Llama.from_pretrained(
	repo_id="google/gemma-3-4b-it-qat-q4_0-gguf",
	filename="gemma-3-4b-it-q4_0.gguf",
)
# %% func load
import json
import re
import time
import os


# ✅ 프롬프트 함수 (llama-cpp용 포맷)
def gemma_prompt1(input_text: str):
    messages = [
        {
            "role": "system",
            "content": [
                {
                    "type": "text",
                    "text": """
You are a Korean-speaking AI assistant that extracts structured information from user messages related to money transfers.

Your task is to analyze the user's sentence and return the following four fields as a single JSON object:

- intent: one of [transfer, confirm, cancel, inquiry, other, system_response]
- amount: integer amount in KRW (e.g. 30000), or null if not specified
- recipient: name or label of the target person, or null if not present
- response: natural Korean response based on the user's intent

Conditions:
- Only extract `amount` and `recipient` if `intent` is "transfer". Otherwise, set them to null.
- Always respond with only a single valid JSON object. Do not include any other text, comments, or explanations.
- All numbers must be normalized to integers (e.g., 삼만 원 == 30000).
- The response field must be a polite Korean message that fits the intent.

Example input and expected output:

Input: "엄마한테 삼만 원 보내줘"  
Output:
{
  "intent": "transfer",
  "amount": 30000,
  "recipient": "엄마",
  "response": "엄마님께 30,000원을 송금하시겠어요?"
}

Now, analyze the following user input:
"""
                }
            ]
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": input_text
                }
            ]
        }
    ]
    return messages
def gemma_prompt2(input_text: str):
    messages = [
        {
            "role": "system",
            "content": [
                {
                    "type": "text",
                    "text": """
You are a Korean-speaking AI assistant that extracts structured information from user messages related to money transfers.

Your task is to analyze the user's sentence and return the following four fields as a single JSON object:

Example input and expected output:

Input: "엄마한테 삼만 원 보내줘"  
Output:
{
  "intent": "transfer",
  "amount": 30000,
  "recipient": "엄마",
  "response": "엄마님께 30,000원을 송금하시겠어요?"
}

Input: "삼만원 보내는 거였지"  
Output:{
  "intent": "confirm",
  "amount": 30000,
  "recipient": null,
  "response": "30,000원 송금 요청을 확인했습니다."
}

text: "보내지 마"  
Output:{
  "intent": "cancel",
  "amount": null,
  "recipient": null,
  "response": "요청하신 송금을 취소했습니다."
}
Now, analyze the following user input:
"""
                }
            ]
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "json",
                    "text": input_text          
                }
            ]
        }
    ]
    return messages

def gemma_prompt3(input_text: str):
    return [
        {
            "role": "system",
            "content": """
You are a Korean-speaking AI assistant. Your task has 3 steps:

1. Analyze the user's message and extract the following fields:
    - intent: one of [transfer, confirm, cancel, inquiry, other, system_response]
    - amount: integer amount (extract only numbers; if not present, set to null)
    - recipient: name or label of the target person (if not present, set to null)

2. Generate a polite Korean response (response) appropriate for the user's intent.

3. Return **only** a single JSON object in the following format. Do not output any extra text.

Example:
{
  "intent": "transfer",
  "amount": 30000,
  "recipient": "엄마",
  "response": "엄마님께 30,000원을 송금해드릴까요?"
}
"""
        },
        {
            "role": "user",
            "content": input_text
        }
    ]


# ✅ 단일 추론 (1개 샘플)
def run_inference(input_text, unified_system_prompt, model):
    start = time.time()
    messages = unified_system_prompt(input_text)

    output = model.create_chat_completion(
        messages=messages,
        max_tokens=128,
        temperature=0,
        stop=["}"]
    )
    end = time.time()

    output_text = output['choices'][0]['message']['content'].strip()+"}"

    # JSON 파싱 시도
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


# ✅ 전체 샘플 반복 추론
def llm_sampling(model, samples):
    parsed = []
    raw_outputs = []
    total_time = 0

    for sample in samples:
        result, parsing, elapsed = run_inference(sample["text"], unified_system_prompt_eng1, model)
        total_time += elapsed

        if parsing is None:
            parsed.append({
                "text": sample["text"],
                "intent": None,
                "slots": {"recipient": None, "amount": None},
                "response": "",
                "_meta": {"error": "Parsing failed", "inference_time": elapsed}
            })
        else:
            parsed.append({
                "text": sample["text"],
                "intent": parsing.get("intent"),
                "slots": {
                    "recipient": parsing.get("recipient"),
                    "amount": parsing.get("amount")
                },
                "response": parsing.get("response"),
                "_meta": {"inference_time": elapsed}
            })

        raw_outputs.append({
            "text": sample["text"],
            "raw_output": result
        })

    os.makedirs("results", exist_ok=True)
    with open("results/parsed.json", "w", encoding="utf-8") as f:
        json.dump(parsed, f, indent=2, ensure_ascii=False)

    with open("results/raw_outputs.json", "w", encoding="utf-8") as f:
        json.dump(raw_outputs, f, indent=2, ensure_ascii=False)

    return parsed, total_time

# %%

# result, pasing, elapsed = run_inference("안녕",gemma_prompt1,model)
# print("🔍 추론 결과:", result)
# print("🧩 파싱된 JSON:\n", pasing)
# print("⏱️ 처리 시간:", elapsed, "초")

print(samples[3]['text'])
result, pasing, elapsed = run_inference(samples[3]['text'],gemma_prompt1, model)
print("🔍 추론 결과:", result)
print("🧩 파싱된 JSON:\n", pasing)
print("⏱️ 처리 시간:", elapsed, "초")




# %%
