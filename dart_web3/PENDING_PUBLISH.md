# Pending Packages for Publication

**Status**: ⚠️ PAUSED due to Pub.dev Rate Limit (HTTP 429).
**Resumption Date**: 2026-01-09 14:00+ (Approximate)

## Publication Queue
The following packages MUST be published in the listed order to ensure dependency resolution:

### 1. Client Layer (The current blocker)
- [ ] `web3_universal_client` (Publish this FIRST)

### 2. High-Level Modules (Depend on Client)
- [ ] `web3_universal_contract`
- [ ] `web3_universal_events`
- [ ] `web3_universal_multicall`
- [ ] `web3_universal_ens`
- [ ] `web3_universal_aa`
- [ ] `web3_universal_nft`
- [ ] `web3_universal_swap`
- [ ] `web3_universal_staking`
- [ ] `web3_universal_history`
- [ ] `web3_universal_bridge`
- [ ] `web3_universal_dapp`
- [ ] `web3_universal_compat`

### 3. Meta-Package (Final Step)
- [ ] `web3_universal`

## Instructions
1. Wait for the rate limit to expire (check after the resumption date).
2. Run `melos publish` and select the remaining packages.
3. If `client` fails again, wait another 2-3 hours and try publishing JUST `client` first.
