# %% library load
!pip install -r requirements.txt
import sys
sys.path.append("/Users/hajin/Projects/MCP_Voice_Transfer/experiments/llms")
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

# %% model load
model_name = "Qwen/Qwen2.5-0.5B-Instruct"  # 또는 Qwen 등

device = "mps" if torch.backends.mps.is_available() else "cpu"
model = AutoModelForCausalLM.from_pretrained(model_name,
                                             device_map={"":device},
                                             )
tokenizer=AutoTokenizer.from_pretrained(model_name)


#%%
from prompts import unified_system_prompt6
result, pasing, elapsed = run_inference("안녕",unified_system_prompt6, tokenizer, model)
print("🔍 추론 결과:", result)
print("🧩 파싱된 JSON:\n", pasing)
print("⏱️ 처리 시간:", elapsed, "초")

print(samples[3]['text'])
result, pasing, elapsed = run_inference(samples[3]['text'],unified_system_prompt6, tokenizer, model)
print("🔍 추론 결과:", result)
print("🧩 파싱된 JSON:\n", pasing)
print("⏱️ 처리 시간:", elapsed, "초")


#%%
results_summary={}
prompt_module = importlib.import_module("prompts")
for i in range(1,7):
    prompt_name=f"unified_system_prompt{i}"
    prompt_fn = getattr(prompt_module, prompt_name, None)
    
    if prompt_fn is None:
        print(f"❌ {prompt_name} 함수 없음")
        continue
    
    print(f"✅ 실행 중: {prompt_name}")
    evaluation =llm_sampling(model,tokenizer, samples, prompt_fn)
    results_summary[prompt_name] = evaluation

 
 
#%% ASSESMENT

 
# 전체 결과 요약 출력
print("\n📊 전체 평가 요약")
for name, evaluation in results_summary.items():
    print(f"\n🔹 {name}")
    for metric, value in evaluation.items():
        print(f"  - {metric}: {value}")


# %%
