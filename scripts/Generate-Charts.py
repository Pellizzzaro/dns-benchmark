#!/usr/bin/env python3
"""Regenerate the two dependency-free SVG charts from published summary CSV.

Python 3.9+; no third-party packages needed. SVG charts depict reported data,
not fabricated samples. Run from the repository root:
    python scripts/Generate-Charts.py
"""
from __future__ import annotations

import csv
from pathlib import Path
from html import escape

ROOT = Path(__file__).resolve().parent.parent
source = ROOT / "results" / "2026-11-24-dns-summary.csv"
with source.open(newline="", encoding="utf-8") as file:
    data = list(csv.DictReader(file))

COLORS = {"Huawei": "#50deb9", "Quad9": "#b2a2ff", "Cloudflare": "#81aef7", "Google": "#a0aec5"}
BG = "#0b111d"
CARD = "#151f2e"
FG = "#e9f0fa"
MUTED = "#93a4bb"


def get(workload, provider, field):
    item = next(x for x in data if x["Test"] == workload and x["Resolver"] == provider)
    return float(item[field])


def text(x, y, value, size=16, fill=FG, weight=400, anchor="start"):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Segoe UI,Inter,Arial,sans-serif" font-size="{size}" font-weight="{weight}" fill="{fill}">{escape(str(value))}</text>'


def rect(x,y,w,h,fill,rx=10):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"/>'


def barrow(x,y,label,val,scale,provider,maxwidth=390, suffix=" ms"):
    width = max(4, round(maxwidth * val / scale, 1))
    parts=[text(x, y-9, label, 16), rect(x, y+2, maxwidth, 14, '#27344a', 7), rect(x,y+2,width,14,COLORS[provider],7),text(x+maxwidth+65,y+14,f"{val:.2f}{suffix}",16,FG,600,"end")]
    return "\n".join(parts)


def save(filename, w,h, inner):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="DNS benchmark chart"><rect width="{w}" height="{h}" fill="{BG}"/>{inner}</svg>'''
    (ROOT / 'charts' / filename).write_text(svg, encoding='utf-8')


# Overview: median values from comparable workload groups, kept in separate panels.
p = []
p += [text(36,50,"DNS BENCHMARK LAB",23,FG,700),text(36,78,"November 24, 2026 · Windows 11 · milliseconds · lower is better",14,MUTED)]
p += [rect(24,100,952,214,CARD,16),text(48,133,"01  WARM · 20 COMMON DOMAINS × 5 ROUNDS",16,FG,700)]
for i,provider in enumerate(['Quad9','Cloudflare','Google']):
    val = get('Warm varied domains',provider,'MedianMs')
    p += [barrow(48,176+i*43,provider,val,15,provider,390)]
p += [rect(24,328,461,194,CARD,16),text(48,361,"02  REAL · 30 VARIED WEBSITES",16,FG,700)]
for i,provider in enumerate(['Huawei','Quad9']):
    val=get('Real varied domains',provider,'MedianMs')
    p += [barrow(48,405+i*55,provider,val,18,provider,235)]
p += [rect(498,328,478,194,CARD,16),text(522,361,"03  FORTNITE · REPEATED DNS",16,FG,700)]
for i,provider in enumerate(['Huawei','Quad9','Cloudflare']):
    val=get('Fortnite Sao Paulo DNS',provider,'MedianMs')
    p += [barrow(522,395+i*39,provider,val,12,provider,240)]
p += [text(36,559,"Reported aggregates only · DNS resolution ≠ in-match ping · router timings benefit from cache",13,MUTED)]
save('dns-overview.svg',1000,584,'\n'.join(p))

# Tail and special-workload stats kept separate rather than comparing different scales.
p = [text(36,49,"WHY THE WORKLOAD MATTERS",23,FG,700),text(36,77,"Unique labels, real websites, and random nonexistent names are different experiments",14,MUTED)]
p += [rect(24,100,952,203,CARD,16),text(48,135,"FRESH WILDCARD LABELS · P95 LATENCY",16,FG,700)]
for i, provider in enumerate(['Huawei','Quad9']):
    val=get('Unique wildcard hostnames',provider,'P95Ms')
    p += [barrow(48,187+i*65,provider,val,500,provider,645)]
p += [rect(24,320,952,203,CARD,16),text(48,356,"RANDOM NONEXISTENT .COM NAMES · MEDIAN ERROR TIME",16,FG,700)]
for i, provider in enumerate(['Huawei','Quad9']):
    val=get('Random nonexistent names',provider,'MedianMs')
    p += [barrow(48,406+i*65,provider,val,150,provider,645)]
p += [text(36,559,"Negative-query responses were not RCODE-classified in the original session; errors are not packet loss.",13,MUTED)]
save('latency-tails.svg',1000,584,'\n'.join(p))
print('Wrote charts/dns-overview.svg and charts/latency-tails.svg')
