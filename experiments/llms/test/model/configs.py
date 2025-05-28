
#%%
qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct")
qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct",torch_dtype=torch.float16).to("cuda")

# #%%
# qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct")
# qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct",torch_dtype=torch.float16).to("cuda")

# #%% transformers-4.52.0.dev0 |  pip-25.1.1
# qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-0.6B-Base")
# qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen3-0.6B-Base")

