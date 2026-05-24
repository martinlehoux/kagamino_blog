---
title: 
draft: true
date: 
lastmod: 
description: 
categories:
  - AI
---
I read many news about LLMs nowadays. One topic I'm most interested in
is local inference for LLMs, and trying to understand when they are usable.

Today I want to focus on inference speed - input and output tokens per second.
Without considering quality, I think speed can be pretty important, especially
for interactive usage (maybe autonomous agents that will spin a merge request
can take longer - there is only so much you can handle everyday as a human reviewer).

I'm working with several scenarios.

The first gets a transcript and quite a short prompt, to summarize the
discussion. I think this will be low context, no loop scenari.
No loop meaning we won't exercise the KV cache. The output will be small to medium.
I'm using the text content of the https://fr.wikipedia.org/wiki/Guerre_de_Cent_Ans
Wikipedia page. It's around 40k tokens.
"Voici toutes les infos sur la guerre de cent ans. Ecris une dissertation sur cette guerre"
Then "fais moi en plus une petite section de dédicace à la famille" So we can get a first sense of KV cache.


The second is a coding exercise by an agent, in a medium sized codebase, with
implementing a simple feature in Typescript. This should use a larger context -
coding harnesses have a several thousands initial context, plus tooling. And
the agent will loop, using tools, LSP, ... so it will heavily use KV cache.
Maybe refactoring + LSP MCP is a good use case

I mostly let LMStudio default load configs.

Once these scenario are ready, I can run them with different models.
I selected them as the most capable one on https://artificialanalysis.ai/leaderboards/models?weights=open&size=small.
- qwen/qwen3.6-35b-a3b Q4_K_M - I'm afraid this doesn't really run on the Macbook Pro
- qwen/qwen3.5-9b Q6_K - This one should easily fit everywhere
- qwen/qwen3.5-2b Q6_K - If those become smart enough, it's interesting for some tasks
- google/gemma-4-e2b Q6_K ~ 5B

On different devices, which are "pretty normal" for regular users:

## Lenovo Thinkpad (RAM 27.04GB, VRAM 11.68GB, AMD Ryzen™ 7 PRO 8840HS, AMD Radeon 780M Graphics (RADV PHOENIX))

Actually LMStudio says 11GB but my hardware says something more like VRAM 4.3GB and RAM 32GB.


### Transcript
**qwen/qwen3.5-9b** ctx 65536, gpu offload 32/32 
it's supposed to fit in GPU entirely


> prompt eval time =  508901.88 ms / 40164 tokens (   12.67 ms per token,    78.92 tokens per second)
       eval time =  359682.91 ms /  2551 tokens (  141.00 ms per token,     7.09 tokens per second)
      total time =  868584.79 ms / 42715 tokens

> new prompt, n_ctx_slot = 65536, n_keep = 40164, task.n_tokens = 42508
> cache reuse is not supported - ignoring n_cache_reuse = 256
> restored context checkpoint (pos_min = 40159, pos_max = 40159, n_tokens = 40160, n_past = 40160, size = 50.251 MiB)

> prompt eval time =   38677.28 ms /  2348 tokens (   16.47 ms per token,    60.71 tokens per second)
       eval time =  327517.99 ms /  2275 tokens (  143.96 ms per token,     6.95 tokens per second)
      total time =  366195.28 ms /  4623 tokens

il a bien cache le précédent, par contre il a du parser ce qu'il avait pondu.
on pourrait le faire parser automatiquement son output pour raccourcir ?

note: désactiver thinking, c'est chiant

**google/gemma-4-e2b** ctx 65536, gpu offload 32/32 
I disable Thinking. Maybe playing with Evaluation Batch size can help.

> prompt eval time =  200613.20 ms / 39269 tokens (    5.11 ms per token,   195.74 tokens per second)
       eval time =  181734.01 ms /  2876 tokens (   63.19 ms per token,    15.83 tokens per second)
      total time =  382347.20 ms / 42145 tokens

This time the cache seems to be dead. Maybe because I disabled thinking in between.

> prompt eval time =  204730.33 ms / 41340 tokens (    4.95 ms per token,   201.92 tokens per second)
       eval time =   26508.62 ms /   432 tokens (   61.36 ms per token,    16.30 tokens per second)
      total time =  231238.95 ms / 41772 tokens

## Desktop with dedicated GPU

## Macbook Pro M4

I also want tun understand if the KV cache can help for DX - you could boot your LLM
in the morning, and it might take 10 minutes to parse and cache the harness prompt and you specific
directions. But then all new sessions for the day would not have to parse
again, and warn boot should be fast. However it wouldn't work well with lazy skills
that could disrupt the cache.
