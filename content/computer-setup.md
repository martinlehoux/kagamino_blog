---
title: Computer setup
date: 2025-11-05
---
## Editors

Of course as a programmer, I use some editors.
My most used day-to-day are [VSCode](https://code.visualstudio.com/) and [Zed](https://zed.dev/).
VSCode extensions are really great, but when I need something really snappy, Zed is now the default.
It has also gained a lot of possibilities recently, with the Debugger and Agent tooling.

In the terminal, my default, when I can, is now [Micro](https://micro-editor.github.io/).
It is easy to install, configurable with highlighting for many languages, and has intuitive default bindgings.

I have a few very specific editors for some use cases, even if nowadays many extensions provide support for other use cases, and in a very usable editor
- [Poedit](https://poedit.net/) is nice when working with translations, in Django for instance

## Postgres

I play a lot with PostgreSQL these days, so I collected tools.
My go to CLI is [pgcli](https://github.com/dbcli/pgcli): it is similar to `psql` in its interface,
but has nice autocompletion and colors. I tried a few IDEs, but in the end I always end up writing
queries in any IDE and running them via a CLI.

## Writing

I have been using [Obsidian](https://obsidian.md/) as a knowledge base, and I'm quite happy with it.
When I don't want to manage a "workspace", I still have [Typora](https://typora.io/) that offers a very pure experience. This is the core of my Markdown experience.

For more precise layouts, I use [typst](https://typst.app/).
It replaces Latex for me, and has LSP support in VSCode at least.
In truth, I haven't used it extensively yet.

## Terminal

I have used the Gnome terminal for a while, but now I'v settled on [Ghostty](https://ghostty.org).
It has a native looka and is quite performant, but I must say I don't know all the features.

## AI Tools

I have tries some AI-first IDEs, like Windsurf, but today I find CLI such as
[claude-code](https://www.anthropic.com/claude-code) and regular IDEs with
autocomplete and agentic mode just good. I don't known if I'm missing on something.

## Unix TUI

I find TUI/CLI are great for tasks you'd like to be very quick to do.
I replaced some aged tools by more modern ones:
- [ripgrep](https://github.com/BurntSushi/ripgrep) over `grep` (the syntax is simpler to me)

I use [hyperfine](https://github.com/sharkdp/hyperfine) for script benchmarks.
[ncdu](https://dev.yorhel.nl/ncdu) helps to interactively find disk usage and clean whole directories.

## Git

[Sublime Merge](https://www.sublimemerge.com/) has a great and snappy interface for staging changes. I find it much quicker to use than VSCode when many files are changed.
I used to use TUI to get this performance, but I don't need it anymore.

My alternative is to use [difftastic](https://github.com/wilfred/difftastic) to review
large intricate changes: this tool provides semantic diffing that shows language specific changes,
all withint the usual git CLI (`git add -p`).

There are also some git tips I sometimes need to find again:
- `git diff --find-renames --diff-filter=M origin/master` reduces file move noise when reviewing large refactors

I can also setup file specific diffing within the CLI:
- [sqldiff](https://sqlite.org/sqldiff.html) provides sqlite file diffs (add `**/*.db diff=sqlite3` in `.gitattributes`)

## Containers

I used Podman for some time, but I went back to Docker to remove some friction.

[lazydocker](https://github.com/jesseduffield/lazydocker) simplifies dynamic container management over
repeated `docker compose ps|stop` ...

[dive](https://github.com/wagoodman/dive) is a great tool to investigate why a container image is small or big.
