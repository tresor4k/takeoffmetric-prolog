"""Copy the TakeoffMetric constants CSV (dataset version 1.2.0) into data/constants.csv, which
prolog/takeoffmetric.pl compiles into facts when it is loaded.

Usage: python sync_data.py [source.csv]
Default source: ../TakeoffMetrics-go/data/constants.csv (the table embedded by the Go module)
Only the header with the values_withheld and withheld_hosts columns (introduced in 1.1.0, unchanged in 1.2.0) is accepted.
Then regenerate test/vectors.json from the Go module and run:
swipl -g run_tests -t halt test/test_takeoffmetric.pl
"""
import csv
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT = HERE.parent / "TakeoffMetrics-go" / "data" / "constants.csv"
HEADER = ("id,category,material_or_item,quantity,value,unit,value_si,unit_si,condition,source_publisher,"
          "source_title,source_url,source_type,date_opened,used_by_tool_url,engine_file,engine_symbol,notes,"
          "values_withheld,withheld_hosts")

src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
raw = src.read_bytes()
text = raw.decode("utf-8")
rows = list(csv.reader(text.splitlines(keepends=True)))
if ",".join(rows[0]) != HEADER:
    sys.exit(f"unexpected header in {src}: {rows[0]}")
if "\r" in text or not text.endswith("\n"):
    sys.exit(f"{src} must use LF line endings and end with a line feed")

(HERE / "data" / "constants.csv").write_bytes(raw)
print(f"synced {len(rows) - 1} rows from {src}")
