---
title: "New tests around local LLMs"
draft: false
date: 2026-08-26
lastmod: 2026-08-26
description: |
  Qwen 3.8 27B is an exciting release, but still too large
  for common dev machines. But I can find interesting models
  to run locally.
categories:
  - LLM
  - Coding Agents
---

## Qwen 3.8 27B

This week was interesting for local models with the open-weights release of Qwen 3.8 27B. It was highly anticipated, because
Qwen 3.6 held the crown for a long time in open models of a size
that is runnable on almost consumer hardware.

The [Artificial Analysis](https://artificialanalysis.ai/models/qwen3-8-27b)
score is pretty damn good! 52 with xhigh is in the ballpark of 
GPT-5.6 Luna (max) and DeepSeek V4 Flash 0731, which were my go
to models for august, given their relatively low price.
To think that I could run as powerful a model locally feels
insane.
For reference, it sits between a Claude Opus 4.6 and a
Claude Opus 4.7, and that was the best available in February
in Claude Code.

## Artificial Analysis pareto frontier

[Artificial Analysis](https://artificialanalysis.ai) is my reference for model comparison.
It actually compiles scores from many benchmarks. I know there are
many pitfalls to these benchmarks, but hey, I have to reduce
the world's complexity, right?
I found my preferred charts when removing all models.
Then AAI highlights the pareto frontier, with the best option
at each tradeoff.


[Int vs Cost/Time per task](https://artificialanalysis.ai/models#intelligence-comparisons) - What frontier model to use in
what case. Here Luna looks pretty neat for cost, and
that's what I used in august.

[Int vs Active/Total params](https://artificialanalysis.ai/models#model-size) - This helps me understand what I could
run on my hardware. For this one, filtering on small
(and maybe tiny) models helps. This shows Qwen 3.8 27B as much better
than the previous Gemma 4 26B A4B. And I can see a new contender
[Ling 3.0 Tiny](https://artificialanalysis.ai/models/ling-3-0-tiny)
that looks promising.

## Running modern models

I wonder if local inference got better since my
[previous attempt](/posts/local-llm-inference-offline-scenario/).
Back then, I had decent inference performance with Gemma 4 E2B
(AAI 15), but it felt too dumb to do meaningful work.
I wanted to test Qwen 3.5 9B, but this time it was too slow,
on my Desktop as well as on my Mac.

As I ran out of my OpenCode Go subscription for the last ten days
of august, it's time to check if I can work locally!
Maybe there were new smaller and smarter models, like Qwen
or Ling ? Or better inference, like oMLX on Mac?

Last time was a one shot scenario, so this time I want to test
a coding agentic workflow with Pi - it has a smaller system prompt.
I go by feel, because I don't have clear metrics to target.

Sadly, Qwen 3.8 27B is too large, even with oMLX. That's also
because I need a larger context of 100k tokens. And I couldn't
run Ling 3.0 Tiny, because of unsupported architecture on
both oMLX and LMStudio. So much for modern models!

## New contenders

But the AAI pareto frontier gives me new ideas of old models
to run.
[Qwen 3.5 4B](https://artificialanalysis.ai/models/qwen3-5-4b)
is still on this frontier with a AAI 20, and a smaller size
than the
[Gemma 4 E2B](https://artificialanalysis.ai/models/gemma-4-e2b/)
(AAI 10) I tested last time.

With oMLX and an 8-bit version, it runs using around 10GB
unified memory. The first prompt is always a bit slow, but then
the KV cache kicks in and it feels snappy enough.
But after some time it ended up in a locked grep loop. I think
this is usable for targeted changes.

I had an attempt on my desktop, which is better a prefill (input)
than the Mac. But this time it didn't feel really smart.

In the end, I'm a bit disappointed I couldn't run the newer models,
even though Ling 3.0 Tiny was supposed to fit. But maybe I can
run it later when the tooling has caught up.
I think Qwen 3.5 4B may have a spot for offline use, as I can run
it at 50 tok/s on Mac. I'd like to investigate using it
as an autocomplete model for IDE.
