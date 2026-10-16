# Cost Model

Compares amortized on-prem lab vs renting the equivalent in public cloud.

## Formula

```text
onprem $/mo = hardware_cost / amort_months
            + (power_watts / 1000) * 730h * kwh_price
            + isp_share + maintenance

cloud $/mo  = n_vms * per_vm
            + storage_gb * storage_per_gb
            + lb + registry
            + egress_tb * egress_per_tb
```

## Defaults (`scripts/cost-compare.py`)

| Input | Default | Rationale |
|-------|---------|-----------|
| `hardware_cost` | $3500 | Mid-range single server, NVMe + HDD |
| `amort_months` | 48 | 4-year write-off |
| `power_watts` | 180W | Measured wall draw, 5 VMs active |
| `kwh_price` | $0.18 | US/EU blended residential |
| `isp_share` | $20 | Fraction of home/office fiber attributed to lab |
| `maintenance` | $15 | Fans, thermal paste, USB rotation amortized |
| `n_vms / per_vm` | 5 × $120 | `t3.xlarge`-class (4vCPU/16GB) on-demand |
| `storage` | 500GB × $0.08 | gp3 equivalent |
| `lb / registry` | $18 / $5 | ALB + ECR baseline |
| `egress` | 0.5TB × $90 | First-TB blended AWS/DO |

Worked example:

```text
onprem = 3500/48 (72.92) + 0.18*730*0.18 (23.65) + 20 + 15 = $131.57/mo
cloud  = 5*120 (600) + 500*0.08 (40) + 18 + 5 + 0.5*90 (45) = $708.00/mo
savings = 708.00 - 131.57 = $576.43/mo (~81%), break-even ~6 months
```

Run it:

```bash
python3 scripts/cost-compare.py
python3 scripts/cost-compare.py --power-watts 250 --kwh-price 0.30 --json
python3 scripts/cost-compare.py --params-json params.json
```

`params.json` keys mirror CLI flags in snake_case.

## When Cloud Wins

- Utilization <10% (server idle but powered).
- Power >$0.40/kWh with no sunk hardware.
- Need multi-AZ, compliance certs, or burst >3× lab capacity.
- Team has no hardware/ops time (factor ~2h/mo at your rate into `maintenance`).

## Method Notes

- Sunk server = `hardware_cost: 0` shows marginal cost only; CI test covers this.
- Add GPUs, 10GbE, or second node by raising `hardware_cost` / `power_watts`.
- Re-run quarterly; commit the output table to PRs that grow the VM matrix.
- This is a planning aid, not a quote. Cloud prices move; adjust `per_vm` from your AWS Pricing Calculator / DO invoice.
