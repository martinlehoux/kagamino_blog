---
title: Local LLM Inference - Offline Scenario
draft: false
date: 2026-05-24
lastmod:
description: | 
    Testing local LLM inference speed on consumer hardware — prefill, decode,
    and KV cache impact across three devices and two models.
categories:
  - LLM
  - Inference
---

I read many news about LLMs nowadays. One topic I'm most interested in
is local inference for LLMs, and trying to find the sweet spot where they can be used
in local setups.

Today I want to focus on inference speed - input and output tokens per second.
Without considering quality, I think speed can be pretty important, especially
for interactive usage. When you prompt your agent with surgical changes and refactors,
speed helps you stay in flow. Maybe autonomous agents that will spin a merge request
can take longer, but this only holds when no human is in the loop.

In this first scenario, I test a low interaction and large context task.
The agent gets a large context with a small goal - the text content of the
[Guerre de Cent Ans](https://fr.wikipedia.org/wiki/Guerre_de_Cent_Ans) Wikipedia page (around 40k tokens),
and "Voici toutes les infos sur la guerre de cent ans. Ecris une dissertation sur cette guerre".
After this first task, I ask "fais moi en plus une petite section de dédicace à la famille".
This lets me test the impact of KV Cache on a simple followup task.

## Setup

Note that I disable thinking in all these tests. I mostly let LMStudio default load configs,
but I set a 65536 context length. I tried to offload everything on the GPU, but sometimes it
was not possible (qwen3.5-9b on Desktop).

To select models to test, I basically use the [Artificial Analyse benchmark](https://artificialanalysis.ai/leaderboards/models?weights=open) with open weights. Then I take the top performers in different
sizes (if they are easily available in LMStudio). As a reference, leading OSS models score about 50,
and closed ones about 60.

| Model              | Quantization | Artificial Analysis Score |
| ------------------ | ------------ | ------------------------: |
| qwen/qwen3.5-9b    | Q6_K         |                        32 |
| google/gemma-4-e2b | Q6_K         |                        15 |

I have devices that are pretty regular - I'm often frustrated with
online benchmarks on 128GB Macbooks.

- **Lenovo Thinkpad** - AMD Ryzen Pro 8840HS, 32 GB RAM, AMD Radeon 780M Graphics, 11.68 GB VRAM (virtual)
- **Desktop** - AMD Ryzen 7 5700X, RAM 32 GB, VRAM 7.66 GB, NVIDIA GeForce RTX 3050
- **Macbook Pro M4** - RAM 24 GB, VRAM 17.76 GB, Apple M4 Pro

## Results


{{< perf-chart title="Prefill speed (tok/s)" xAxisLabel="tok/s" stacked="false" labels="Thinkpad qwen3.5-9b,Thinkpad gemma-4-e2b,Desktop qwen3.5-9b,Desktop gemma-4-e2b,Mac gemma-4-e2b,Mac qwen3.5-9b" datasets="Cold:blue:78,195,534,1730,587,266|Warm:emerald:60,202,435,1160,333,203" >}}

{{< perf-chart title="Decode speed (tok/s)" xAxisLabel="tok/s" stacked="false" labels="Thinkpad qwen3.5-9b,Thinkpad gemma-4-e2b,Desktop qwen3.5-9b,Desktop gemma-4-e2b,Mac gemma-4-e2b,Mac qwen3.5-9b" datasets="Cold:blue:7.1,15.8,4.2,60,57,13|Warm:emerald:6.9,16.3,4.1,61,56,23" >}}

When the cache works, we parse ~20x less tokens (from 40k to 2k), but prefill
is a bit slower. This is because reading the KV cache takes some time, and
the attention mechanism induces more prefill compute at each request.

The RTX is super fast at prefill, but same or worst than the Mac at decoding.
Prefill is parallel, compute bound decoding of tokens. Dedicated GPU
with high FLOPS beat anything else. Decoding is sequential and memory bound.
We can compute the prefill/decode ratio for our different devices, and find
that shared memory helps more at decoding (thinkpad ~ 11, macbook ~10) where
dedicated GPU helps at prefill (desktop ~ 25 or even 110 when bad GPU offload)

## Conclusion

Generation at 5-10 token/sec feels too slow for productive work, but in this
offline scenario, we can still find it usable. This concerns models that don't fit
on dedicated GPU, or models on a classic laptop GPU. Models that fit on dedicated
GPU can process a lot of input data. Macbook are very good at generation,
and can use larger models than my GPU.

There are a few axis I want to experiment inference speed against:

- Playing with Evaluation Batch size (when memory is available, like on the Mac)
- Try again the laptop with a more recent LMStudio version
- Experimenting MLX format gains on Mac - when available
- The impact of laptop power mode

And of course an agentic coding scenario.

{{< alert info "LLM usage in this article" >}}
- Parsing logs and creating markdown tables
- Generating charts
- Acting as Publisher
{{< /alert >}}
