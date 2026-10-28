/*  TakeoffMetric US construction estimating constants, dataset version 1.2.0.

    A port of the Go module github.com/tresor4k/takeoffmetric-go: the same
    table (data/constants.csv), compiled into the module at load time as
    read-only facts. Lookup only: the pack computes nothing.
    Method: https://takeoffmetric.com/methodology/

    Estimating values only: confirm with your plans, your supplier and your
    local code before ordering or building.

    License: code MIT; constants (data/) see data/LICENSE.
*/

:- module(takeoffmetric,
          [ by_id/2,          % +Id, -Constant
            search/2,         % +Query, -Constants
            all/1,            % -Constants
            sources/1         % -Sources
          ]).
:- use_module(library(csv)).
:- use_module(library(apply)).
:- use_module(library(lists)).

/** <module> TakeoffMetric US construction estimating constants (lookup only)

A constant is a dict with the keys `id`, `category`, `material_or_item`,
`quantity`, `value_text`, `unit`, `unit_si`, `condition`, `source`,
`date_opened` (a term date(Y,M,D)), `used_by_tool_url`, `engine_file`,
`engine_symbol` (lists of strings), `notes`, `withheld` (true or false) and
`withheld_hosts` (list of strings), plus `value` and `value_si` (floats).
Text values are strings. `source` is a dict with the keys `publisher`,
`title`, `url` and `type`.

When `withheld` is true the publisher does not allow republication: the
dict has no `value` and no `value_si` key, `value_text` is the empty string,
and the value is read at the URL of the source. `value_si` is also absent
when the table leaves it empty.
*/

%!  all(-Constants:list(dict)) is det.
%
%   Every constant, in table order.

all(Constants) :-
    findall(C, constant_(_, C), Constants).

%!  by_id(+Id, -Constant:dict) is semidet.
%
%   The constant with the given id (atom or string), for example 'CON-001'.
%   Fails when the id is unknown.

by_id(Id, Constant) :-
    text_to_string(Id, S),
    constant_(S, C),
    !,
    Constant = C.

%!  search(+Query, -Constants:list(dict)) is det.
%
%   The constants whose id, category, material, quantity, condition,
%   publisher or notes contain every word of Query, ignoring case. An empty
%   query returns the empty list.

search(Query, Constants) :-
    text_to_string(Query, Q0),
    string_lower(Q0, Q),
    split_string(Q, " \t\n\r\v\f", " \t\n\r\v\f", Parts),
    exclude(==(""), Parts, Words),
    (   Words == []
    ->  Constants = []
    ;   findall(C, (constant_(_, C), matches(Words, C)), Constants)
    ).

matches(Words, C) :-
    atomics_to_string([C.id, " ", C.category, " ", C.material_or_item, " ",
                       C.quantity, " ", C.condition, " ", C.source.publisher,
                       " ", C.notes], Text0),
    string_lower(Text0, Text),
    forall(member(W, Words), sub_string(Text, _, _, _, W)).

%!  sources(-Sources:list(dict)) is det.
%
%   Each distinct source of the table once, sorted by publisher, then title,
%   then URL (code order, as the byte order of the Go module for this table).

sources(Sources) :-
    findall(k(P, T, U, Ty), ( constant_(_, C),
                              _{publisher:P, title:T, url:U, type:Ty} :< C.source
                            ), Keys),
    sort(Keys, Sorted),
    maplist(key_source, Sorted, Sources).

key_source(k(P, T, U, Ty), _{publisher:P, title:T, url:U, type:Ty}).

% Loading: the table is read when this file is compiled and stored as
% constant_(Id, Dict) facts, in table order.

header([id, category, material_or_item, quantity, value, unit, value_si,
        unit_si, condition, source_publisher, source_title, source_url,
        source_type, date_opened, used_by_tool_url, engine_file,
        engine_symbol, notes, values_withheld, withheld_hosts]).

table_clauses(File, Clauses) :-
    csv_read_file(File, [Header|Rows], [convert(false), strip(false)]),
    Header =.. [_|Names],
    (   header(Names)
    ->  true
    ;   throw(error(format("~w: unexpected header", [File]), _))
    ),
    foldl(row_clause, Rows, Clauses, 2, _).

row_clause(Row, constant_(Id, C), Line0, Line) :-
    Line is Line0 + 1,
    Row =.. [_|Atoms],
    maplist(atom_string, Atoms, Fields),
    catch(parse(Fields, C),
          error(format(Fmt, Args), _),
          ( format(string(Msg), Fmt, Args),
            throw(error(format("data/constants.csv row ~w: ~w", [Line0, Msg]), _)) )),
    Id = C.id.

parse(Fields, C) :-
    (   length(Fields, 20)
    ->  true
    ;   length(Fields, N), throw(error(format("~w fields, want 20", [N]), _))
    ),
    Fields = [Id, Category, Material, Quantity, Value, Unit, ValueSI, UnitSI,
              Condition, Publisher, Title, URL, Type, Date, UsedBy, EngineFile,
              EngineSymbol, Notes, Withheld0, Hosts],
    withheld(Withheld0, Value, ValueSI, Hosts, Withheld),
    date(Date, DateOpened),
    split_list(UsedBy, "; ", UsedByList),
    split_list(EngineFile, "; ", EngineFileList),
    split_list(EngineSymbol, "; ", EngineSymbolList),
    split_list(Hosts, ";", HostList),
    C0 = _{id:Id, category:Category, material_or_item:Material,
           quantity:Quantity, value_text:Value, unit:Unit, unit_si:UnitSI,
           condition:Condition,
           source:_{publisher:Publisher, title:Title, url:URL, type:Type},
           date_opened:DateOpened, used_by_tool_url:UsedByList,
           engine_file:EngineFileList, engine_symbol:EngineSymbolList,
           notes:Notes, withheld:Withheld, withheld_hosts:HostList},
    optional_number(Withheld, value, Value, C0, C1),
    optional_number(false, value_si, ValueSI, C1, C).

withheld("true", Value, ValueSI, _, true) :-
    !,
    % A withheld row must carry no number at all.
    (   Value == "", ValueSI == ""
    ->  true
    ;   throw(error(format("withheld row has a value", []), _))
    ).
withheld("false", Value, _, Hosts, false) :-
    !,
    (   Hosts \== ""
    ->  throw(error(format("withheld_hosts set on a row that is not withheld", []), _))
    ;   Value == ""
    ->  throw(error(format("value missing on a row that is not withheld", []), _))
    ;   true
    ).
withheld(Other, _, _, _, _) :-
    throw(error(format("values_withheld: \"~w\", want true or false", [Other]), _)).

optional_number(true, _, _, C, C) :- !.
optional_number(_, _, "", C, C) :- !.
optional_number(_, Key, Text, C0, C) :-
    (   catch(number_string(N, Text), _, fail), number(N)
    ->  F is float(N),
        put_dict(Key, C0, F, C)
    ;   throw(error(format("~w: \"~w\"", [Key, Text]), _))
    ).

date(Text, date(Y, M, D)) :-
    (   split_string(Text, "-", "", [YS, MS, DS]),
        string_length(YS, 4), string_length(MS, 2), string_length(DS, 2),
        number_string(Y, YS), number_string(M, MS), number_string(D, DS),
        integer(Y), integer(M), integer(D),
        between(1, 12, M), D >= 1,
        days_in_month(Y, M, Max), D =< Max
    ->  true
    ;   throw(error(format("date_opened: \"~w\"", [Text]), _))
    ).

days_in_month(Y, 2, D) :-
    !,
    (   ( Y mod 4 =:= 0, Y mod 100 =\= 0 ; Y mod 400 =:= 0 ) -> D = 29 ; D = 28 ).
days_in_month(_, M, D) :-
    nth1(M, [31, _, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31], D).

split_list("", _, []) :- !.
split_list(Text, Separator, Parts) :-
    atomic_list_concat(Atoms, Separator, Text),
    maplist(atom_string, Atoms, Parts).

term_expansion(constant_table, Clauses) :-
    prolog_load_context(directory, Dir),
    atomic_list_concat([Dir, '/../data/constants.csv'], File0),
    absolute_file_name(File0, File, [access(read)]),
    table_clauses(File, Clauses).

constant_table.
