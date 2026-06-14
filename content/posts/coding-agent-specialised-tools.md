---
title: "Can we do better than Read - Edit"
draft: false
date: 2026-06-14
lastmod:
description: |
  The landscape of coding agents tooling is fragmented, and there are no
  definitive winners.
categories:
  - LLM
  - Coding Agents
---

Coding agents have agency - they can decide on their own
what files they need to read in order to understand a codebase.
Common harnesses such as Claude Code or Codex provide a
limited set of tools to perform Software Engineering tasks -
Read, Write, Edit.

[Retrieval-Augmented Code Generation](#retrieval-augmented-code-generation-a-survey-with-focus-on-repository-level-approaches)
gives a good understanding of the alternative tools, splitting them in GRAPH vs
TEXT (BM25, Jaccard similarity). They also differentiate one-shot retrieval vs
dynamic exploration, where the agent has the opportunity to deepen its search
based on previous results. AST parsing can be used in both solutions.
Other approaches use sub-agents to explore and summarize.

For pure analysis - answering a question such as "How does authentication
work in here?", a combination of graph database, AST parsing and
embedding models claim up to [50x saved input tokens](#code-review-graph).
This results in faster query answering, but it affects actual costs much
less, [dominated by output tokens](#grepai--benchmark-vs-grep--claude-code).

In a 2024 paper for [SWE-agent](#swe-agent-agent-computer-interfaces-enable-automated-software-engineering),
we could already see a cost tradeoff - tool-based agents beat RAG or shell,
but at a tenfold cost increase.

I couldn't find many benchmarks on editing. And to my knowledge, there are no
well-known benchmarks comparing all sorts of harnesses. Only the base CLIs
are compared (Claude Code vs Codex vs Opencode). The precise values I
get are always self-reported, and rarely compared.

I also found a case study from [ManoMano and Serena](#manomano--serena--project-aegis), a tool
I tried for a week but didn't find so useful (or even used by Claude).
There was a slight cost increase, but it brought a huge quality boost.
Quick explorations are still better with Claude Code, but refactoring
is very fast and precise with Serena.

I hoped I could wrap up this post with a definitive answer, but setting
up reproducible benchmarks to test all those tools is not as easy as I expected.
I think GRAPH-based solutions are more promising, because TEXT predates them
and were put aside by the big labs. I'll try to test some of them.


## Trending projects

| Project | Stars | Capability | Technique |
|---|---|---|---|
| [codegraph](https://github.com/colbymchenry/codegraph) | 42.6k | Read, index | Graph DB |
| [GitNexus](https://github.com/abhigyanpatwari/GitNexus) | 40.8k | Read, Rename, Viz | Graph DB |
| [repomix](https://github.com/yamadashy/repomix) | 25.8k | Code compression? | Text packing |
| [serena](https://github.com/oraios/serena) | 24.8k | Read + Edit | AST / LSP |
| [code-review-graph](https://github.com/tirth8205/code-review-graph) | 17.2k | Read | Graph DB |
| [context-hub](https://github.com/andrewyng/context-hub) | 13.4k | Read | Embedding |
| [claude-context](https://github.com/zilliztech/claude-context) | 11.6k | Read | Embedding |
| [code2prompt](https://github.com/mufeedvh/code2prompt) | 7.4k | Read | Text packing |
| [semble](https://github.com/MinishLab/semble) | 4.6k | Read | BM25 + AST + Embedding |
| [rewrite](https://github.com/openrewrite/rewrite) | 3.5k | Refactoring | AST |
| [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | 2.7k | Read | AST + SQLite |
| [cocoindex-code](https://github.com/cocoindex-io/cocoindex-code) | 1.7k | Read | Embedding |
| [grepai](https://github.com/yoanbernabeu/grepai) | 1.7k | Read | BM25 / Grep |
| [CodeGraphContext](https://github.com/CodeGraphContext/CodeGraphContext) | 3.7k | Read | Graph DB |


## Resources

### [ManoMano & Serena — Project Aegis](https://medium.com/manomano-tech/project-aegis-benchmarking-ai-agents-and-why-serena-is-our-new-must-have-311673db35dd)

> Good size project for the test — information retrieval and refactoring.
> Slight cost increase, time decrease, but most importantly much better quality.
> Used fewer subagents (subagents are long and bad because of context reset).
> Claude Code LSP was bad. CC is still better for quick exploration.
> Refactoring is where Serena shines.

---

### [Codebase-Memory: Tree-Sitter-Based Knowledge Graphs for LLM Code Exploration via MCP](https://arxiv.org/abs/2603.27277v1)
*28 Mar 2026 — 2 citations*

> 10% less accuracy for 10× fewer tokens and 100× faster.
> Uses TreeSitter + SQLite. Doesn't require specialized models, supports many
> languages, auto syncs. The questions in their benchmarks are very precise
> (naming functions) — my use of the tool is much less directed.
> They disregard Code Property Graphs and CodeQL as unfit for LLM (Claude says
> CodeQL needs a compilation step; others need Neo4j and upkeep). I wonder why
> — that seems doable to me. TreeSitter is incremental, so obviously easier.
> They explicitly compare to an "Explorer Agent" and to other groups (RAG,
> Repo-Map, Graph+LLM). Good at exploring relations. The core opposition:
> embedding retrieval (TEXT) vs structural retrieval (AST).

---

### [Code Intelligence Tools — rywalker.com](https://rywalker.com/research/code-intelligence-tools)

> A useful tiering:
> - Knowledge graph engines — GitNexus, CodeGraphContext
> - MCP code search — Octocode, CodePathFinder
> - Context packing — Repomix, code2prompt
>
> It's true that I quite often experience broken tests after refactoring.

---

### [Retrieval-Augmented Code Generation: A Survey with Focus on Repository-Level Approaches](https://arxiv.org/abs/2510.04905)
*6 Oct 2025 — 19 citations*

> Real-life work is more complex than coding challenges — Repository-Level Code
> Generation. They review context construction, retrieval optimization, generation,
> and environment interaction.
> Graph vs non-graph approaches. Non-graph: as text, similarity (BM25, Jaccard).
> One-shot retrieval vs dynamic agentic exploration. Some systems use RL-trained
> models to improve retrieval.
> Increasing model context size provides similar benefits as RAG.
> GRAPH are the next in town vs TEXT — that doesn't mean it's better.

---

### [Subagents — Simon Willison](https://simonwillison.net/guides/agentic-engineering-patterns/subagents/)

> A way to work around limited context. Even 1M context is worse than 200k context
> used well. Claude Code Explore subagent avoids many tokens in the parent context.
> With current caching, it feels like it doesn't cost more?

---

### [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering](https://arxiv.org/abs/2405.15793)
*6 May 2024 — 1159 citations*

> Now an old paper. They introduced the need for tools (shell was too hard),
> simple compact commands, concise feedback, guardrails (read before edit…).
> Things that have aged: edit doesn't have read-before, partial file edit shows
> lint errors.
> They beat the RAG-based previous record — but it costs 10× more.

---

### [code-review-graph](https://github.com/tirth8205/code-review-graph)

> Claim around 50× saved tokens per analysis request.
> I don't know if this works well for editing.

---

### [grepai — Benchmark vs grep / Claude Code](https://yoanbernabeu.github.io/grepai/blog/benchmark-grepai-vs-grep-claude-code/)

> Here too, 50×. Note — it has only a −25% impact on cost.
> Input tokens are not so expensive.


{{< alert info "LLM usage in this article" >}}
- Converting bullet lists to markdown tables
- Structuring research notes into blockquotes
- Replacing footnotes with cross-links to resource analyses
- Correcting spelling and grammar throughout
- Acting as Publisher
{{< /alert >}}
