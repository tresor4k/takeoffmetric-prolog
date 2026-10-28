# takeoffmetric-prolog

Dependency-free SWI-Prolog pack (standard libraries only) that embeds version 1.2.0 of the US construction estimating
constants published by [TakeoffMetric](https://takeoffmetric.com/) as read-only records: bag yields, aggregate and soil
densities, swell and compaction ratios, rebar weights, dressed lumber sizes, block counts, shingle coverage, asphalt
unit weights and air properties. These are published constants with their sources, not original research: each record
gives the value, its unit, an SI conversion, the condition it applies to and the source it was read in.

It is a port of the Go module [takeoffmetric-go](https://github.com/tresor4k/takeoffmetric-go): same table, same
lookups. The tests compare every record, the search results and the source list to vectors written by the Go module.

55 of the 148 records carry no value: their publishers do not allow republication. Those records keep the quantity, its
unit and the link to the source; `withheld` is `true`, the dict has no `value` and no `value_si` key, and
`withheld_hosts` lists the domains concerned. Read the value at the URL of the source.

```prolog
:- use_module(library(takeoffmetric)).

?- by_id('CON-007', C).              % fails when the id is unknown
?- search("bank density", Rows).
?- all(All).
?- sources(Sources).
```

Each record is a dict with the keys `id`, `category`, `material_or_item`, `quantity`, `value`, `value_text`, `unit`,
`value_si`, `unit_si`, `condition`, `source` (a dict: `publisher`, `title`, `url`, `type`), `date_opened` (a term
`date(Y, M, D)`), `used_by_tool_url`, `engine_file`, `engine_symbol`, `notes`, `withheld` and `withheld_hosts`. Text
values are strings; `value` and `value_si` are floats.

The pack is a lookup library and computes nothing. To turn dimensions into quantities, use the calculators on the
site, for example the [concrete calculator](https://takeoffmetric.com/concrete/concrete-calculator/). How they use
these values: [methodology](https://takeoffmetric.com/methodology/).

Estimating values only: confirm with your plans, your supplier and your local code before ordering or building.

## Tests

From the pack root:

```
swipl -g run_tests -t halt test/test_takeoffmetric.pl
```

## Updating the data

`python sync_data.py` copies `../TakeoffMetrics-go/data/constants.csv` (or the file given as first argument) into
`data/`, which `prolog/takeoffmetric.pl` reads when it is compiled and stores as facts. It accepts only the 1.1.x
header (with `values_withheld` and `withheld_hosts`). Then regenerate `test/vectors.json` from the Go module and run
the tests.

## Licence

- Code: MIT, see LICENSE.
- Constants (`data/` and the facts compiled from it), see data/LICENSE:
  - the compilation (selection of rows, SI conversions, conditions, notes, column structure): CC BY 4.0, attribution
    TakeoffMetric Editorial;
  - values from federal publications: works of the US government, in the public domain;
  - any other value stays under the terms of its publisher and is not relicensed by CC BY 4.0; each row names its
    publisher and links its source (`source_publisher`, `source_title`, `source_url`);
  - 55 rows carry no value (`values_withheld` = `true`): their publishers do not allow republication.
- Cite as: TakeoffMetric Editorial, *US Construction Estimating Constants*, version 1.2.0, 2026, takeoffmetric.com.
- The calculation engine of takeoffmetric.com is not included in this pack.
