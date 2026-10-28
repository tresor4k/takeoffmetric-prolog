/*  vectors.json is written by the Go module github.com/tresor4k/takeoffmetric-go
    (every row through ByID, the output of Search for a few queries, Sources).
    The tests compare the whole Prolog table to it; no value is typed by hand.

    Run from the pack root:
        swipl -g run_tests -t halt test/test_takeoffmetric.pl
*/

:- use_module(library(plunit)).
:- use_module(library(http/json)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(yall)).
:- use_module(library(debug)).

:- prolog_load_context(directory, Dir),
   atomic_list_concat([Dir, '/../prolog'], Lib),
   asserta(user:file_search_path(library, Lib)).
:- use_module(library(takeoffmetric)).

:- dynamic test_dir/1.
:- prolog_load_context(directory, Dir), asserta(test_dir(Dir)).

vectors(V) :-
    test_dir(Dir),
    atomic_list_concat([Dir, '/vectors.json'], File),
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       json_read_dict(In, V, [value_string_as(string)]),
                       close(In)).

% The value of Key in C as the vector writes it: null when absent.
number_or_null(C, Key, X) :-
    (   get_dict(Key, C, X0) -> X = X0 ; X = null ).

same_number(null, null) :- !.
same_number(Got, Want) :- number(Got), number(Want), Got =:= Want, float(Got) =:= float(Want).

check_row(W) :-
    Id = W.id,
    (   by_id(Id, C) -> true ; format(user_error, "~w: by_id failed~n", [Id]), fail ),
    check(Id, id, C.id, W.id),
    check(Id, category, C.category, W.category),
    check(Id, material_or_item, C.material_or_item, W.material_or_item),
    check(Id, quantity, C.quantity, W.quantity),
    number_or_null(C, value, V), check_number(Id, value, V, W.value),
    check(Id, value_text, C.value_text, W.value_text),
    check(Id, unit, C.unit, W.unit),
    number_or_null(C, value_si, VSI), check_number(Id, value_si, VSI, W.value_si),
    check(Id, unit_si, C.unit_si, W.unit_si),
    check(Id, condition, C.condition, W.condition),
    check(Id, source, C.source, W.source),
    C.date_opened = date(Y, M, D),
    format(string(DateText), "~d-~|~`0t~d~2+-~|~`0t~d~2+", [Y, M, D]),
    check(Id, date_opened, DateText, W.date_opened),
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, -, -), Stamp),
    check_number(Id, date_opened_unix, Stamp, W.date_opened_unix),
    check(Id, used_by_tool_url, C.used_by_tool_url, W.used_by_tool_url),
    check(Id, engine_file, C.engine_file, W.engine_file),
    check(Id, engine_symbol, C.engine_symbol, W.engine_symbol),
    check(Id, notes, C.notes, W.notes),
    check(Id, withheld, C.withheld, W.withheld),
    check(Id, withheld_hosts, C.withheld_hosts, W.withheld_hosts).

% Dicts compared by their pairs: the tags of two dicts read apart differ.
canon(X, Y) :-
    (   is_dict(X)
    ->  dict_pairs(X, _, Pairs0),
        maplist([K-V0, K-V]>>canon(V0, V), Pairs0, Pairs),
        Y = dict(Pairs)
    ;   is_list(X)
    ->  maplist(canon, X, Y)
    ;   Y = X
    ).

check(Id, Key, Got, Want) :-
    (   canon(Got, G), canon(Want, W), G == W
    ->  true
    ;   format(user_error, "~w ~w: got ~q, want ~q~n", [Id, Key, Got, Want]),
        fail
    ).

check_number(Id, Key, Got, Want) :-
    (   same_number(Got, Want)
    ->  true
    ;   format(user_error, "~w ~w: got ~q, want ~q~n", [Id, Key, Got, Want]),
        fail
    ).

ids(Constants, Ids) :-
    maplist([C, Id]>>get_dict(id, C, Id), Constants, Ids).

% Dict access through get_dict: functional notation is not expanded inside a lambda.
is_withheld(C) :- get_dict(withheld, C, true).
has_ids(S) :- get_dict(ids, S, Ids), Ids \== [].

:- begin_tests(takeoffmetric).

test(counts) :-
    vectors(V),
    assertion(V.dataset_version == "1.2.0"),
    all(All),
    length(All, N),
    assertion(N =:= V.count),
    length(V.constants, NV),
    assertion(NV =:= V.count),
    include(is_withheld, All, Withheld),
    length(Withheld, NW),
    assertion(NW =:= V.withheld_count).

test(every_row_matches_go) :-
    vectors(V),
    all(All),
    ids(All, Ids),
    ids(V.constants, WantIds),
    assertion(Ids == WantIds),
    include([W]>>(\+ check_row(W)), V.constants, Bad),
    assertion(Bad == []).

test(withheld_rows_carry_no_number) :-
    all(All),
    forall(member(C, All),
           (   C.withheld == true
           ->  assertion(( \+ get_dict(value, C, _), \+ get_dict(value_si, C, _),
                           C.value_text == "", C.withheld_hosts \== [],
                           C.source.url \== "" ))
           ;   assertion(( get_dict(value, C, X), float(X), C.withheld_hosts == [] ))
           )).

test(search_matches_go) :-
    vectors(V),
    include(has_ids, V.searches, NonEmpty),
    length(NonEmpty, NE),
    assertion(NE >= 5),
    forall(member(S, V.searches),
           ( search(S.query, Found),
             ids(Found, Ids),
             assertion(Ids == S.ids) )).

test(sources_match_go) :-
    vectors(V),
    sources(Sources),
    canon(Sources, Got),
    canon(V.sources, Want),
    assertion(Got == Want).

test(unknown_id) :-
    assertion(\+ by_id("XXX-000", _)),
    assertion(\+ by_id("", _)).

test(atom_id) :-
    by_id('CON-007', C),
    assertion(C.id == "CON-007").

:- end_tests(takeoffmetric).
