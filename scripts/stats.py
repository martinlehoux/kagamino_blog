#!/usr/bin/env python3
import json
import math
import sys

with open(sys.argv[1]) as f:
    posts = json.load(f)

words = [p["wordCount"] for p in posts]
n = len(words)
total = sum(words)
mean = total / n
stddev = math.sqrt(sum(w * w for w in words) / n - mean * mean)

print(f"Posts:    {n}")
print(f"Total:    {total} words")
print(f"Mean:     {mean:.0f} words")
print(f"Std Dev:  {stddev:.0f} words")
print()
print(f"{'Title':<60s} {'Words'}")
print(f"{'-----':<60s} {'-----'}")
for p in posts:
    print(f"{p['title']:<60s} {p['wordCount']}")
