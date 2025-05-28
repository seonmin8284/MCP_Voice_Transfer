import json
import re
import time
import os


def run_inference(input_text: str, unified_system_prompt, tokenizer, model, max_new_tokens=128):
    messages = unified_system_prompt(input_text)
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    start = time.time()
    outputs = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False,
        use_cache=False
    )
    end = time.time()

    generated = tokenizer.decode(outputs[0], skip_special_tokens=True)
    output_text = generated.replace(prompt, "").strip()

    assistant_split = re.split(r"\bassistant\b", output_text, flags=re.IGNORECASE)
    if len(assistant_split) < 2:
        print("⚠️ 'assistant' 이후 내용을 찾지 못했습니다.")
        return output_text, None, round(end - start, 2)

    assistant_response = assistant_split[-1].strip()
    match = re.search(r'\{[\s\S]*?\}', assistant_response)
    if match:
        try:
          
            parsed_json = json.loads(match.group())
            # # 필수 필드 보정
            # parsed_json.setdefault("amount", None)
            # parsed_json.setdefault("recipient", None)
            # parsed_json.setdefault("response", "")
            return output_text, parsed_json, round(end - start, 2)
        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {e}")
    else:
        print("⚠️ assistant 이후 JSON 객체를 찾을 수 없습니다.")

    return output_text, None, round(end - start, 2)

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


def llm_sampling(model, tokenizer, samples, prompt):
    prompt_name = prompt.__name__
    model_name = model.name_or_path.replace("/", "_")
    save_dir = f"results/{model_name}/{prompt_name}"
    os.makedirs(save_dir, exist_ok=True)

    parsed_path = os.path.join(save_dir, "parsed.json")
    raw_path = os.path.join(save_dir, "raw_outputs.json")

    parsed = []
    raw_outputs = []
    total_time = 0

    for sample in samples:
        result, parsing, elapsed = run_inference(sample["text"], prompt, tokenizer, model)
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
                "intent": parsing["intent"],
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

    with open(parsed_path, "w", encoding="utf-8") as f:
        json.dump(parsed, f, indent=2, ensure_ascii=False)

    with open(raw_path, "w", encoding="utf-8") as f:
        json.dump(raw_outputs, f, indent=2, ensure_ascii=False)

    return evaluate_results(parsed, samples, total_time)


