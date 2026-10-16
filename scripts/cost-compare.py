#!/usr/bin/env python3
"""Compare on-prem lab cost vs cloud equivalent (AWS / DigitalOcean).

Formula:
  monthly_onprem = hardware / amort_months + watts/1000 * 730 * kwh_price
                   + isp_share + maintenance
  monthly_cloud  = per_vm * n_vms + storage + load_balancer + registry + egress

Defaults model 5 VMs (tools/devx2/test/staging) as t3.xlarge-class + 100GB gp3 each.
Override any input via CLI flags or --params-json. Prints ASCII table + verdict.
"""
from __future__ import annotations

import argparse
import json
import sys


def onprem_monthly(
    hardware_cost: float,
    amort_months: int,
    power_watts: float,
    kwh_price: float,
    isp_share: float = 20.0,
    maintenance: float = 15.0,
    hours_per_month: float = 730.0,
) -> dict:
    if amort_months <= 0:
        raise ValueError("amort_months must be > 0")
    if hardware_cost < 0 or power_watts < 0 or kwh_price < 0:
        raise ValueError("cost inputs must be non-negative")
    amort = hardware_cost / amort_months
    power = (power_watts / 1000.0) * hours_per_month * kwh_price
    total = amort + power + isp_share + maintenance
    return {
        "amortization": round(amort, 2),
        "power": round(power, 2),
        "isp_share": round(isp_share, 2),
        "maintenance": round(maintenance, 2),
        "total": round(total, 2),
    }


def cloud_monthly(
    n_vms: int = 5,
    per_vm: float = 120.0,
    storage_gb: float = 500.0,
    storage_per_gb: float = 0.08,
    lb: float = 18.0,
    registry: float = 5.0,
    egress_tb: float = 0.5,
    egress_per_tb: float = 90.0,
) -> dict:
    if n_vms < 0:
        raise ValueError("n_vms must be non-negative")
    compute = n_vms * per_vm
    storage = storage_gb * storage_per_gb
    egress = egress_tb * egress_per_tb
    total = compute + storage + lb + registry + egress
    return {
        "compute": round(compute, 2),
        "storage": round(storage, 2),
        "lb": round(lb, 2),
        "registry": round(registry, 2),
        "egress": round(egress, 2),
        "total": round(total, 2),
    }


def render_table(onprem: dict, cloud: dict) -> str:
    cl = cloud["total"]
    op = onprem["total"]
    diff = round(cl - op, 2)
    pct = round((diff / cl * 100) if cl else 0.0, 1)
    verdict = "ON-PREM CHEAPER" if diff > 0 else ("CLOUD CHEAPER" if diff < 0 else "BREAK-EVEN")
    lines = [
        f"{'Component':<16}{'On-Prem $/mo':>14}{'Cloud $/mo':>14}",
        "-" * 44,
        f"{'Amort/Compute':<16}{onprem['amortization']:>14.2f}{cloud['compute']:>14.2f}",
        f"{'Power/Storage':<16}{onprem['power']:>14.2f}{cloud['storage']:>14.2f}",
        f"{'ISP+Maint/LB+Reg':<16}{(onprem['isp_share'] + onprem['maintenance']):>14.2f}{(cloud['lb'] + cloud['registry']):>14.2f}",
        f"{'Egress':<16}{'—':>14}{cloud['egress']:>14.2f}",
        "-" * 44,
        f"{'TOTAL':<16}{op:>14.2f}{cl:>14.2f}",
        f"Monthly savings (cloud - onprem): ${diff:.2f} ({pct}% of cloud) => {verdict}",
    ]
    return "\n".join(lines)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="On-prem vs cloud cost comparison")
    p.add_argument("--hardware-cost", type=float, default=3500.0)
    p.add_argument("--amort-months", type=int, default=48)
    p.add_argument("--power-watts", type=float, default=180.0)
    p.add_argument("--kwh-price", type=float, default=0.18)
    p.add_argument("--isp-share", type=float, default=20.0)
    p.add_argument("--maintenance", type=float, default=15.0)
    p.add_argument("--n-vms", type=int, default=5)
    p.add_argument("--per-vm", type=float, default=120.0,
                   help="Cloud $/mo per t3.xlarge-class VM")
    p.add_argument("--storage-gb", type=float, default=500.0)
    p.add_argument("--storage-per-gb", type=float, default=0.08)
    p.add_argument("--lb", type=float, default=18.0)
    p.add_argument("--registry", type=float, default=5.0)
    p.add_argument("--egress-tb", type=float, default=0.5)
    p.add_argument("--egress-per-tb", type=float, default=90.0)
    p.add_argument("--params-json", type=str, default=None,
                   help="JSON file overriding any of the above (snake_case keys)")
    p.add_argument("--json", action="store_true", help="Emit JSON instead of table")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.params_json:
        with open(args.params_json, encoding="utf-8") as f:
            overrides = json.load(f)
        for k, v in overrides.items():
            if hasattr(args, k):
                setattr(args, k, v)
    onprem = onprem_monthly(
        args.hardware_cost, args.amort_months, args.power_watts,
        args.kwh_price, args.isp_share, args.maintenance,
    )
    cloud = cloud_monthly(
        args.n_vms, args.per_vm, args.storage_gb, args.storage_per_gb,
        args.lb, args.registry, args.egress_tb, args.egress_per_tb,
    )
    if args.json:
        print(json.dumps({"onprem": onprem, "cloud": cloud}, indent=2))
    else:
        print(render_table(onprem, cloud))
    return 0


if __name__ == "__main__":
    sys.exit(main())
