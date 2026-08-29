# Canonical Findings Index — Kleidi Pre-Audit Evaluation

20 distinct issues across 9 independent reviewers (Code4rena, Certora, Claude, Codex, DeepSeek v4, GLM 5.2, GLM 5.3, GLM 5.3 Flash, v12) after deduplication.

**Severity methodology:** Certora baseline = reference calibration. C4 judge rulings = binding where available. Multi-auditor LLM consensus de-inflated ~1 notch per observed severity drift. Single-LLM findings accepted at reported severity unless contradicted.

---

## Master Table

| ID | Severity | Title | Component | Old IDs | Auditors (original severity) |
|----|----------|-------|-----------|---------|------------------------------|
| KLD-001 | **High** | Guardian pause permanently killable via unbounded proposal flooding | Timelock / ConfigurablePause | C4-M1, F10, Certora M-01 | C4 (M), Certora (M), GLM 5.3 (H), v12 (M) |
| KLD-002 | Medium | Index +1 length bug in sliceBytes | BytesHelper / Timelock | C4-M2 | C4 (M) |
| KLD-003 | Medium | _afterCall re-checks with post-execution expirationPeriod | Timelock | C4-M3 | C4 (M), GLM 5.2 (M), v12 (M) |
| KLD-004 | Medium | Swap-and-pop revocation desync | Timelock | B-M2 | Certora (M) |
| KLD-005 | Medium | Recovery spell mutual non-exclusivity | RecoverySpell | B-M3 | Certora (M) |
| KLD-006 | Medium | expirationPeriod overflow permanently bricks governance | Timelock | F1 | Certora (I), GLM 5.3 Flash (M), Codex (M), v12 (M) |
| KLD-007 | Medium | Off-by-one in calldata-check overlap rejects adjacent ranges | Timelock | F3 | Certora (L), Claude (M), GLM 5.3 (M), v12 (M) |
| KLD-008 | Medium | SENTINEL/Safe-address owners permanently brick recovery | RecoverySpellFactory | F4 | Certora (L), Claude (M), GLM 5.3 (M), Codex (M) |
| KLD-009 | Medium | Zero recoveryThreshold enables unauthorized recovery | RecoverySpellFactory | F5 | Claude (M) |
| KLD-010 | Medium | Wildcard cETH mint + unchecked value freezes native balance | Timelock (config) | F8 | DeepSeek v4 (M) |
| KLD-012 | Medium | Recovery delay pre-elapses before module enablement | RecoverySpell / InstanceDeployer | F11 | GLM 5.3 (M), Codex (M) |
| KLD-013 | Medium | Survivor-collision permanently bricks recovery rotation | RecoverySpell | F12 | Certora (L), GLM 5.3 (M) |
| KLD-014 | Medium | Failed Safe-module calls silently recorded as executed | Timelock | F13 | Certora (L), Codex (M) |
| KLD-015 | Low | Transient storage leak in RecoverySpellFactory | RecoverySpellFactory | F2 | Certora (L), Claude (M), GLM 5.3 Flash (M) |
| KLD-016 | Low | Initialize front-run on direct TimelockFactory use | Timelock / TimelockFactory | F6 | Claude (M), GLM 5.2 (M) |
| KLD-017 | Low | 1-of-1 wallet silently deployed for single-owner instances | InstanceDeployer | F9 | Certora (I), DeepSeek v4 (M) |
| KLD-018 | Low | Zero guardian disables emergency pause at deployment | Timelock / ConfigurablePause | — | v12 (M) |
| KLD-019 | Low | Paused batch continues after callback-triggered pause | Timelock | — | v12 (M) |
| KLD-020 | Info | Hot signers not revoked when Safe owner removed | Timelock | — | v12 (M) |
| KLD-021 | Info | Pause predicate doesn't special-case zero pauseStartTime | ConfigurablePause | — | v12 (M) |

---

## Coverage Matrix

Legend: **+** = found · **~** = partial/adjacent · **.** = missed

| ID | Severity | C4 | Certora | Claude | Codex | DeepSeek v4 | GLM 5.2 | GLM 5.3 | GLM 5.3 Flash | v12 |
|----|----------|-----|---------|--------|-------|----------|---------|---------|----------|-----|
| KLD-001 | High | + | + | . | . | . | . | + | . | + |
| KLD-002 | Med | + | . | . | . | . | . | . | . | . |
| KLD-003 | Med | + | . | . | . | . | + | . | . | + |
| KLD-004 | Med | . | + | . | . | . | . | . | . | . |
| KLD-005 | Med | . | + | . | . | . | . | . | . | . |
| KLD-006 | Med | . | ~ | . | + | . | . | . | + | + |
| KLD-007 | Med | . | ~ | + | . | . | . | + | . | + |
| KLD-008 | Med | . | ~ | + | + | . | . | + | . | . |
| KLD-009 | Med | . | . | + | . | . | . | . | . | . |
| KLD-010 | Med | . | . | . | . | + | . | . | . | . |
| KLD-012 | Med | . | . | . | + | . | . | + | . | . |
| KLD-013 | Med | . | ~ | . | . | . | . | + | . | . |
| KLD-014 | Med | . | ~ | . | + | . | . | . | . | . |
| KLD-015 | Low | . | + | + | . | . | . | . | + | . |
| KLD-016 | Low | . | . | + | . | . | + | . | . | . |
| KLD-017 | Low | . | ~ | . | . | + | . | . | . | . |
| KLD-018 | Low | . | . | . | . | . | . | . | . | + |
| KLD-019 | Low | . | . | . | . | . | . | . | . | + |
| KLD-020 | Info | . | . | . | . | . | . | . | . | + |
| KLD-021 | Info | . | . | . | . | . | . | . | . | + |
| **Total (+ only)** | | **3** | **4** | **5** | **4** | **2** | **2** | **5** | **2** | **8** |
| **Mapped (+/~)** | | **3** | **10** | **5** | **4** | **2** | **2** | **5** | **2** | **8** |

**Recall (exact matches only):** C4 3/20 (15%) · Certora 4/20 (20%) · Claude 5/20 (25%) · Codex 4/20 (20%) · DeepSeek v4 2/20 (10%) · GLM 5.2 2/20 (10%) · GLM 5.3 5/20 (25%) · GLM 5.3 Flash 2/20 (10%) · v12 8/20 (40%)

**Mapped coverage (+ or ~):** C4 3/20 (15%) · Certora 10/20 (50%) · Claude 5/20 (25%) · Codex 4/20 (20%) · DeepSeek v4 2/20 (10%) · GLM 5.2 2/20 (10%) · GLM 5.3 5/20 (25%) · GLM 5.3 Flash 2/20 (10%) · v12 8/20 (40%)

---

## Auditor Cross-Reference

### Code4rena
| Local ID | Canonical | Notes |
|----------|-----------|-------|
| M-01 | KLD-001 | Gas griefing angle; GLM 5.3 escalated to permanent brake kill |
| M-02 | KLD-002 | 10 duplicate finders; sliceBytes length off-by-one |
| M-03 | KLD-003 | _afterCall re-check with new expirationPeriod |

### Certora
| Local ID | Canonical | Notes |
|----------|-----------|-------|
| M-01 | KLD-001 | Unbounded loop in pause(); rated Medium |
| M-02 | KLD-004 | Swap-and-pop desync — sole finder |
| M-03 | KLD-005 | Spell mutual non-exclusivity — sole finder |
| L-02 | KLD-007 | Adjacent range overlap; partial match |
| L-05 | KLD-015 | Transient storage leak |
| L-07 | KLD-013 | Survivor collision; partial match |
| L-09 | KLD-008 | SENTINEL owner; partial match |
| I-01 | KLD-006 | expirationPeriod overflow; rated Informational |
| I-05 | KLD-017 | 1-of-1 threshold; partial match |
| L-06 | KLD-014 | Failed module calls; partial match |

### Claude
| Local finding | Canonical |
|---------------|-----------|
| Off-by-one overlap | KLD-007 |
| Transient storage leak | KLD-015 |
| SENTINEL owners | KLD-008 |
| Initialize front-run | KLD-016 |
| Zero recoveryThreshold | KLD-009 |

### Codex
| Local finding | Canonical |
|---------------|-----------|
| Recovery delay pre-elapse | KLD-012 |
| Unbounded expirationPeriod | KLD-006 |
| Factory accepts bad owners | KLD-008 |
| Failed module calls recorded | KLD-014 |

### DeepSeek v4
| Local finding | Canonical |
|---------------|-----------|
| Wildcard cETH mint | KLD-010 |
| 1-of-1 wallet threshold | KLD-017 |

### GLM 5.2
| Local finding | Canonical |
|---------------|-----------|
| _afterCall expirationPeriod | KLD-003 |
| Initialize no access control | KLD-016 |

### GLM 5.3
| Local finding | Canonical |
|---------------|-----------|
| Guardian pause OOG kill (HIGH) | KLD-001 |
| Recovery delay pre-elapse | KLD-012 |
| Off-by-one overlap | KLD-007 |
| SENTINEL owners | KLD-008 |
| Survivor-collision brick | KLD-013 |

### GLM 5.3 Flash (glm-5.3-flash)
| Local finding | Canonical |
|---------------|-----------|
| expirationPeriod overflow | KLD-006 |
| Transient storage leak | KLD-015 |

### v12
| Local finding (ticket) | Canonical |
|------------------------|-----------|
| Paused Batch Continues (#251886) | KLD-019 |
| Zero Guardian (#251920) | KLD-018 |
| Adjacent ranges rejected (#251931) | KLD-007 |
| Expiry changes (#251933) | KLD-003 |
| Unbounded proposal purge (#251934) | KLD-001 |
| Unbounded expirationPeriod (#251936) | KLD-006 |
| Hot signers not bound (#251939) | KLD-020 |
| Pause predicate sentinel (#251942) | KLD-021 |
