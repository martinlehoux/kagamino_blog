---
title: Local LLM Inference - Offline Scenario
draft: false
date: 2026-05-24
lastmod:
description:
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
can take longer - there is only so much you can handle everyday as a human reviewer.

I'm working with several scenarios, and today's one is low interaction and long context.
The agent gets a large context with a small goal - the text content of the
[Guerre de Cent Ans](https://fr.wikipedia.org/wiki/Guerre_de_Cent_Ans) Wikipedia page (around 40k tokens),
and "Voici toutes les infos sur la guerre de cent ans. Ecris une dissertation sur cette guerre".

After this first task, I ask "fais moi en plus une petite section de dédicace à la famille".

This scenarii is useful for offline, out of the loop usage (like transcription summary).
I'll also be able to test the impact of KV Cache on a simple task.

## Setup

Note that I disable thinking in all these tests. I mostly let LMStudio default load configs,
but I set a 65536 context length. I tried to offload everything on the GPU, but sometimes it
was not possible (qwen3.5-9b on Desktop).

To select models to test, I basically use the [Artificial Analyse benchmark](https://artificialanalysis.ai/leaderboards/models?weights=open) with open weights. Then I take the top performers in different
sizes (if they are easily available in LMStudio). As a reference, leading OSS models socre about 50,
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

| Device           | Model                  | Pass | Prefill (tok/s) | Time to start | Decode (tok/s) | Time to generate |
| ---------------- | ---------------------- | ---- | --------------: | :-----------: | -------------: | :--------------: |
| Thinkpad         | qwen3.5-9b             | Cold |              78 |   8 min 33    |            7.1 |     4 min 41     |
| Thinkpad         | qwen3.5-9b             | Warm |              60 |    33 sec     |            6.9 |     4 min 50     |
| Thinkpad         | gemma-4-e2b            | Cold |             195 |   3 min 25    |           15.8 |     2 min 7      |
| Thinkpad         | gemma-4-e2b            | Warm |             202 |    10 sec     |           16.3 |     2 min 3      |
| Desktop RTX 3050 | qwen3.5-9b (gpu 16/32) | Cold |             534 |   1 min 15    |            4.2 |     7 min 56     |
| Desktop RTX 3050 | qwen3.5-9b (gpu 16/32) | Warm |             435 |     5 sec     |            4.1 |     8 min 8      |
| Desktop RTX 3050 | gemma-4-e2b            | Cold |            1730 |    23 sec     |             60 |      33 sec      |
| Desktop RTX 3050 | gemma-4-e2b            | Warm |            1160 |     2 sec     |             61 |      33 sec      |
| Macbook M4 Pro   | gemma-4-e2b            | Cold |             587 |    1 min 8    |             57 |      35 sec      |
| Macbook M4 Pro   | gemma-4-e2b            | Warm |             333 |     6 sec     |             56 |      36 sec      |
| Macbook M4 Pro   | qwen3.5-9b             | Cold |             266 |   2 min 30    |             13 |     2 min 34     |
| Macbook M4 Pro   | qwen3.5-9b             | Warm |             203 |    10 sec     |             23 |     1 min 27     |

When the cache works, we parse ~20x less tokens (from 40k to 2k), but prefill
is a bit slower. This is because reading the KV cache takes some time, and
the attention mechanism induces more prefill compute at each request.

The RTX is super fast at prefill, but same or worst than the Mac at decoding.
Prefill is parallel, compute bound decoding of tokens. Dedicated GPU
with high FLOPS beat aynthing else. Decoding is sequential and memory bound.
We can compute the prefill/decode ratio for our different devices, and find
that shared memory helps more at decoding (thinkpad ~ 11, macbook ~10) where
dedicated GPU helps at prefill (desktop ~ 25 or even 110 when bad GPU offload)

## Conclusion

Generation at 5-10 token/sec feels too slow for productive work, but in this
offline scenario, we can still find is usable. This concerns models that don't fit
on dedicated GPU, or models on a classic laptop GPU. Models that fit on dedicated
GPU can process a lot of input data. Macbook are very good at generation,
and can use larger models than my GPU.

There are a few axis I want to experiment inference speed against:

- Playing with Evaluation Batch size (when memory is available, like on the Mac)
- Try again the laptop with a more recent LMStudio version
- Experimenting MLX format gains on Mac - when avaible
- The impact of laptop power mode

And of course an agentic coding scenario.

## LLM usage

- Parsing logs and create markdown tables
- Acting as Publisher
