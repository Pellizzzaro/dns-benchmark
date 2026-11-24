# Methodology and validity notes

## What is being measured?

**DNS query elapsed time** is the time Windows PowerShell takes to issue `Resolve-DnsName -Server ...` and return an answer, as measured with `Stopwatch`. This includes local PowerShell processing, network RTT, server processing, and possibly caching. It is not directly comparable to microsecond-precision DNS protocol wire benchmarks.

**ICMP echo RTT** is Windows' round-trip time for `ping` or .NET `Ping.Send()`, not Fortnite/VALORANT/CS2 gameplay UDP latency. A diagnostic endpoint need not be the server used for a match. DNS no longer participates in the steady-state game packet path once a match's IP has been selected, except for new resolutions.

## Workloads

1. **Warm:** 20 widely used domains, randomized domain order and resolver order over 5 rounds (100 queries per resolver); caches are intentionally allowed to warm.
2. **Repeated single domain:** `github.com` resolved 30 times per resolver. This heavily favors local caching; not a fair cold-cache test.
3. **Fresh labels:** Unique names under `sslip.io` and `nip.io`; exact-name cache hits are unlikely, but delegation and upstream caches remain active. Both zones' authoritative behavior can strongly affect latency.
4. **Negative:** Random long `.com` names, expected not to exist. An NXDOMAIN response is *successful negative resolution*. Historical data recorded generic errors, so do not equate 50 errors with 50 losses or confirmed NXDOMAIN.
5. **Real varied domains:** 30 real, mostly technical websites each queried once per resolver. Prior caches are unknowable; this is not guaranteed cold.
6. **Fortnite DNS:** 20 repetitions of Epic's São Paulo diagnostic hostname, comparing DNS reply times and A-record sets.
7. **Fortnite ICMP:** 30 ping requests each to four IPs resolved in the experiment, with whole-millisecond Windows output.

## Why P95/P99 matter

Median summarizes a typical lookup, while P95/P99 expose the slower tail. For 100 samples, P99 is approximately the second-slowest observation using nearest-rank order statistics. With 30 samples, P95 is unstable; note this when interpreting small differences.

## Fairness / limitations

- Randomize resolver order and domain order in tests to reduce fixed-order advantages.
- **Do not clear a public resolver's cache:** clients generally cannot do that.
- For cold-record testing, distinct hostnames help avoid exact answer caching but can involve unusual authoritative servers and zone-side behavior.
- When comparing two resolvers, ensure the *answers* match (or record when they don't), not only their speed.
- Test several times at different hours; ISP routes, DNS cache state, and server load change over time.
- Compare negative responses by RCODE (NXDOMAIN vs SERVFAIL vs timeouts), not simply exceptions. The improved script attempts to classify NXDOMAIN but may be language-dependent.
- Distinguish a router-local DNS cache from the **upstream recursive DNS provider**. Testing `192.168.100.1` measures the entire local DNS-forwarding path, not the manufacturer.
- The original results are user-supplied summary tables, not independently reproduced in this repository. See `/results/`.

## Privacy

Do not commit screenshots showing WAN public IPs, ONT serial numbers, MAC addresses, ISP credentials, or router admin access URLs. The scripts save new raw query results to the git-ignored `runs/` folder. Inspect traces before voluntarily adding them to Git.
