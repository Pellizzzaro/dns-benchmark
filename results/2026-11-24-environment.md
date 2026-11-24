# Measurement context — 2026-11-24

All summary values are **user-reported console outputs in a single session**. The raw per-query CSV and live captures from that session were not preserved, so the repository does **not** invent them. Values are rounded as printed by the original tools.

| Item | Observation |
|---|---|
| Client | Windows 11 desktop, wired Ethernet |
| LAN adapter | Realtek PCIe GbE Family Controller |
| Router | Huawei EchoLife HG8245W5-6T |
| Wired link | 1000 Mb/s full duplex |
| Automatic DNS on PC | `192.168.100.1` (router-local DNS forwarder/proxy likely) |
| Public DNS tested | Quad9 `9.9.9.9`, Cloudflare `1.1.1.1`, Google `8.8.8.8` |
| Reported access service | User reported a 1 Gb/s symmetrical fiber subscription; not independently validated |
| Browser throughput test | ~580.6 Mb/s down, ~291.6 Mb/s up; not a direct measurement of port capacity |
| Loaded latency test | 8 ms idle, +10 ms on download load, +0 ms on upload load; waveform score A |
| `1.1.1.1` ICMP | 100/100 received, 8–9 ms displayed Windows round trips |
| Fortaleza / actual match server? | **No**. Fortnite values below are São Paulo **diagnostic** endpoints, not proven game match servers. |

## Research boundaries

- The Huawei is Chinese-manufactured hardware, **not evidence that upstream DNS servers are physically in China**.
- The WAN operator's upstream recursive resolver IP was not observed.
- No actual VALORANT / CS2 / Fortnite match UDP metrics were collected.
- The earlier negative-domain script counted all PowerShell exceptions as "errors"; whether each was NXDOMAIN, timeout, or another DNS status was not preserved.
- DNS A-record answer order can vary without changing the set of endpoints. All three tested providers returned `15.228.25.118`, `.138`, `.140`, and `.156` for the Epic regional diagnostic hostname.
- The original test used `Resolve-DnsName` wrapped in `Stopwatch`, so command/execution overhead is included.
