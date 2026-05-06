#!/usr/bin/env python3
"""Compare simulator Linux boot logs for correctness and performance drift."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional


ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


@dataclass
class BootMetrics:
    path: str
    success: bool
    error: bool
    cycles: Optional[int]
    commits: Optional[int]
    loads: Optional[int]
    stores: Optional[int]
    ipc: Optional[float]
    l1d_amat: Optional[float]
    l1i_amat: Optional[float]
    avg_miss_penalty: Optional[float]
    avg_axi_read_latency: Optional[float]
    llc_ddr_read_avg: Optional[float]


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def first_float(pattern: str, text: str) -> Optional[float]:
    match = re.search(pattern, text, flags=re.MULTILINE)
    return float(match.group(1)) if match else None


def parse_log(path: Path) -> BootMetrics:
    text = strip_ansi(path.read_text(errors="replace"))
    sim_match = re.search(
        r"sim-time\(cycle\)=\s*(\d+),\s*"
        r"committed\(total/load/store\)=\s*(\d+)\s*/\s*(\d+)\s*/\s*(\d+)",
        text,
    )
    has_error = any(
        marker in text
        for marker in (
            "Difftest: error",
            "DEADLOCK",
            "HIT BAD TRAP",
            "ASSERT",
            "panic",
        )
    )
    return BootMetrics(
        path=str(path),
        success="Success!!!!" in text,
        error=has_error,
        cycles=int(sim_match.group(1)) if sim_match else None,
        commits=int(sim_match.group(2)) if sim_match else None,
        loads=int(sim_match.group(3)) if sim_match else None,
        stores=int(sim_match.group(4)) if sim_match else None,
        ipc=first_float(r"^ipc\s*:\s*([0-9.]+)", text),
        l1d_amat=first_float(r"^L1D AMAT\(cycles\)\s*:\s*([0-9.]+)", text),
        l1i_amat=first_float(r"^L1I AMAT\(cycles\)\s*:\s*([0-9.]+)", text),
        avg_miss_penalty=first_float(r"^Avg Miss Penalty\s*:\s*([0-9.]+)", text),
        avg_axi_read_latency=first_float(
            r"^Avg AXI Read Latency\s*:\s*([0-9.]+)", text
        ),
        llc_ddr_read_avg=first_float(r"^llc->ddr read avg\s*:\s*([0-9.]+)", text),
    )


def pct_delta(current: float, baseline: float) -> Optional[float]:
    if baseline == 0:
        return None
    return (current - baseline) * 100.0 / baseline


def fmt_value(value: object) -> str:
    if value is None:
        return "missing"
    if isinstance(value, float):
        return f"{value:.6f}"
    return str(value)


def print_row(name: str, base: object, cur: object) -> None:
    delta = ""
    if isinstance(base, (int, float)) and isinstance(cur, (int, float)):
        raw_delta = cur - base
        pct = pct_delta(float(cur), float(base))
        if pct is None:
            delta = f"{raw_delta:+.6g}"
        else:
            delta = f"{raw_delta:+.6g} ({pct:+.4f}%)"
    print(f"{name:22} baseline={fmt_value(base):>12} current={fmt_value(cur):>12} delta={delta}")


def require_metric(metrics: BootMetrics, name: str) -> bool:
    return getattr(metrics, name) is not None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two simulator Linux boot logs and fail on perf drift."
    )
    parser.add_argument("baseline", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument("--max-cycle-delta-pct", type=float, default=1.0)
    parser.add_argument("--max-ipc-drop-pct", type=float, default=1.0)
    parser.add_argument(
        "--require-exact",
        action="store_true",
        help="fail on any cycle or IPC difference; useful for deterministic gates",
    )
    parser.add_argument(
        "--allow-missing-success",
        action="store_true",
        help="do not require Success!!!! marker in both logs",
    )
    parser.add_argument("--json", action="store_true", help="print parsed metrics as JSON")
    args = parser.parse_args()

    baseline = parse_log(args.baseline)
    current = parse_log(args.current)
    failures: list[str] = []

    for label, metrics in (("baseline", baseline), ("current", current)):
        if metrics.error:
            failures.append(f"{label} log contains error/deadlock marker")
        if not args.allow_missing_success and not metrics.success:
            failures.append(f"{label} log is missing Success!!!! marker")
        for metric in ("cycles", "commits", "ipc"):
            if not require_metric(metrics, metric):
                failures.append(f"{label} log is missing {metric}")

    if baseline.commits is not None and current.commits is not None:
        if baseline.commits != current.commits:
            failures.append(
                f"commit count differs: baseline={baseline.commits} current={current.commits}"
            )

    if baseline.cycles is not None and current.cycles is not None:
        cycle_pct = pct_delta(float(current.cycles), float(baseline.cycles))
        if args.require_exact and current.cycles != baseline.cycles:
            failures.append(
                f"cycle count differs under --require-exact: "
                f"baseline={baseline.cycles} current={current.cycles}"
            )
        elif cycle_pct is not None and cycle_pct > args.max_cycle_delta_pct:
            failures.append(
                f"cycle increase {cycle_pct:.4f}% exceeds "
                f"{args.max_cycle_delta_pct:.4f}%"
            )

    if baseline.ipc is not None and current.ipc is not None:
        ipc_drop = -pct_delta(float(current.ipc), float(baseline.ipc))
        if args.require_exact and current.ipc != baseline.ipc:
            failures.append(
                f"IPC differs under --require-exact: "
                f"baseline={baseline.ipc:.6f} current={current.ipc:.6f}"
            )
        elif ipc_drop > args.max_ipc_drop_pct:
            failures.append(
                f"IPC drop {ipc_drop:.4f}% exceeds {args.max_ipc_drop_pct:.4f}%"
            )

    if args.json:
        print(json.dumps({"baseline": asdict(baseline), "current": asdict(current)}, indent=2))
    else:
        print(f"baseline: {baseline.path}")
        print(f"current : {current.path}")
        print_row("cycles", baseline.cycles, current.cycles)
        print_row("commits", baseline.commits, current.commits)
        print_row("loads", baseline.loads, current.loads)
        print_row("stores", baseline.stores, current.stores)
        print_row("ipc", baseline.ipc, current.ipc)
        print_row("L1D AMAT", baseline.l1d_amat, current.l1d_amat)
        print_row("L1I AMAT", baseline.l1i_amat, current.l1i_amat)
        print_row("avg miss penalty", baseline.avg_miss_penalty, current.avg_miss_penalty)
        print_row(
            "avg AXI read latency",
            baseline.avg_axi_read_latency,
            current.avg_axi_read_latency,
        )
        print_row("llc->ddr read avg", baseline.llc_ddr_read_avg, current.llc_ddr_read_avg)

    if failures:
        print("RESULT: FAIL", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
