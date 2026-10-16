import importlib.util
import sys
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "cost-compare.py"

spec = importlib.util.spec_from_file_location("cost_compare", _SCRIPT)
assert spec is not None and spec.loader is not None
cost_compare = importlib.util.module_from_spec(spec)
sys.modules["cost_compare"] = cost_compare
spec.loader.exec_module(cost_compare)

onprem_monthly = cost_compare.onprem_monthly
cloud_monthly = cost_compare.cloud_monthly
render_table = cost_compare.render_table


def test_onprem_defaults():
    # 3500/48=72.92, power 0.18*730*0.18=23.65, +20+15 => ~131.57
    result = onprem_monthly(3500.0, 48, 180.0, 0.18)
    assert result["total"] == round(3500.0 / 48 + 0.18 * 730 * 0.18 + 35.0, 2)


def test_cloud_defaults():
    result = cloud_monthly()
    assert result["compute"] == 600.0
    assert result["total"] == round(600.0 + 40.0 + 18.0 + 5.0 + 45.0, 2)


def test_render_table_verdict():
    onprem = onprem_monthly(3500.0, 48, 180.0, 0.18)
    cloud = cloud_monthly()
    table = render_table(onprem, cloud)
    assert "ON-PREM CHEAPER" in table
    assert "TOTAL" in table


def test_zero_hardware_is_cheapest():
    onprem = onprem_monthly(0.0, 48, 0.0, 0.0, isp_share=0.0, maintenance=0.0)
    assert onprem["total"] == 0.0


def test_invalid_inputs_raise():
    import pytest

    with pytest.raises(ValueError):
        onprem_monthly(100.0, 0, 100.0, 0.2)
    with pytest.raises(ValueError):
        onprem_monthly(-1.0, 48, 100.0, 0.2)
    with pytest.raises(ValueError):
        cloud_monthly(n_vms=-1)
