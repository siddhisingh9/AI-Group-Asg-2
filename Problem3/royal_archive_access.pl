% Royal Archive Access Verification
% Run: swipl royal_archive_access.pl

:- initialization(main).
:- dynamic cl/3.

% ============================================
% Step 1: Predicate logic representation
% ============================================
% Constants: mira, scroll_7
% Variables: x, y
% Predicates: archivist(x), verifies(x,y), trusted(x),
%   has_access(x,y), sealed(y), permitted(x,y),
%   inspects(x,y), finds_mark(x,y), stored_in_archive(y)

fol(1, all(x, all(y, imp(and(archivist(x), verifies(x, y)), trusted(x))))).
fol(2, all(x, all(y, imp(and(trusted(x), and(has_access(x, y), sealed(y))), permitted(x, y))))).
fol(3, all(x, all(y, imp(and(inspects(x, y), finds_mark(x, y)), verifies(x, y))))).
fol(4, all(y, imp(stored_in_archive(y), sealed(y)))).
fol(5, stored_in_archive(scroll_7)).
fol(6, has_access(mira, scroll_7)).
fol(7, and(inspects(mira, scroll_7), finds_mark(mira, scroll_7))).
fol(8, archivist(mira)).

goal(trusted(mira)).

% ============================================
% Step 2: Negation of goal
% ============================================
negated_goal(9, neg(G)) :- goal(G).

kb(Id, F) :- fol(Id, F).
kb(Id, F) :- negated_goal(Id, F).

% ============================================
% Step 3: Implication removal
% ============================================
impl_free(imp(A, B), or(neg(A1), B1)) :- !, impl_free(A, A1), impl_free(B, B1).
impl_free(and(A, B), and(A1, B1)) :- !, impl_free(A, A1), impl_free(B, B1).
impl_free(or(A, B), or(A1, B1)) :- !, impl_free(A, A1), impl_free(B, B1).
impl_free(neg(A), neg(A1)) :- !, impl_free(A, A1).
impl_free(all(V, A), all(V, A1)) :- !, impl_free(A, A1).
impl_free(ex(V, A), ex(V, A1)) :- !, impl_free(A, A1).
impl_free(A, A).

step3(Id, F) :- kb(Id, F0), impl_free(F0, F).

% ============================================
% Step 4: Negation movement
% ============================================
nnf(neg(neg(A)), F) :- !, nnf(A, F).
nnf(neg(and(A, B)), or(F1, F2)) :- !, nnf(neg(A), F1), nnf(neg(B), F2).
nnf(neg(or(A, B)), and(F1, F2)) :- !, nnf(neg(A), F1), nnf(neg(B), F2).
nnf(neg(all(V, A)), ex(V, F)) :- !, nnf(neg(A), F).
nnf(neg(ex(V, A)), all(V, F)) :- !, nnf(neg(A), F).
nnf(and(A, B), and(F1, F2)) :- !, nnf(A, F1), nnf(B, F2).
nnf(or(A, B), or(F1, F2)) :- !, nnf(A, F1), nnf(B, F2).
nnf(all(V, A), all(V, F)) :- !, nnf(A, F).
nnf(ex(V, A), ex(V, F)) :- !, nnf(A, F).
nnf(A, A).

step4(Id, F) :- step3(Id, F0), nnf(F0, F).

% ============================================
% Step 5: Standardization
% ============================================
% substitute Old by New
sub(O, N, T, N) :- T == O, !.
sub(O, N, T, R) :- compound(T), !, T =.. [F|As], maplist(sub(O, N), As, Bs), R =.. [F|Bs].
sub(_, _, T, T).

% rename x -> x<Id>
std(all(V, A), Id, all(V1, B)) :- !, atom_concat(V, Id, V1), sub(V, V1, A, A1), std(A1, Id, B).
std(ex(V, A), Id, ex(V1, B)) :- !, atom_concat(V, Id, V1), sub(V, V1, A, A1), std(A1, Id, B).
std(and(A, B), Id, and(C, D)) :- !, std(A, Id, C), std(B, Id, D).
std(or(A, B), Id, or(C, D)) :- !, std(A, Id, C), std(B, Id, D).
std(A, _, A).

step5(Id, F) :- step4(Id, F0), std(F0, Id, F).

% ============================================
% Step 6: Skolemization
% ============================================
% no existentials here
sk(all(V, A), Us, all(V, B)) :- !, sk(A, [V|Us], B).
sk(ex(V, A), Us, B) :- !,
    atom_concat(sk_, V, S),
    ( Us == [] -> T = S ; T =.. [S|Us] ),
    sub(V, T, A, A1), sk(A1, Us, B).
sk(and(A, B), Us, and(C, D)) :- !, sk(A, Us, C), sk(B, Us, D).
sk(or(A, B), Us, or(C, D)) :- !, sk(A, Us, C), sk(B, Us, D).
sk(A, _, A).

step6(Id, F) :- step5(Id, F0), sk(F0, [], F).

% ============================================
% Step 7: CNF clauses
% ============================================
% drop universal quantifiers
drop_q(all(V, A), F, [V|Vs]) :- !, drop_q(A, F, Vs).
drop_q(F, F, []).

cnf(and(A, B), and(A1, B1)) :- !, cnf(A, A1), cnf(B, B1).
cnf(or(A, B), F) :- !, cnf(A, A1), cnf(B, B1), dist(A1, B1, F).
cnf(A, A).

dist(and(A, B), C, and(D, E)) :- !, dist(A, C, D), dist(B, C, E).
dist(A, and(B, C), and(D, E)) :- !, dist(A, B, D), dist(A, C, E).
dist(A, B, or(A, B)).

clauses_of(and(A, B), Cs) :- !, clauses_of(A, C1), clauses_of(B, C2), append(C1, C2, Cs).
clauses_of(F, [L]) :- disj(F, L).

disj(or(A, B), L) :- !, disj(A, L1), disj(B, L2), append(L1, L2, L).
disj(A, [A]).

build_clauses :-
    retractall(cl(_, _, _)),
    forall(step6(Id, F),
      ( drop_q(F, M, Vs), cnf(M, C), clauses_of(C, Cs), length(Cs, N),
        forall(nth1(K, Cs, Lits),
          ( ( N =:= 1 -> format(atom(Name), 'C~w', [Id])
            ; format(atom(Name), 'C~w.~w', [Id, K]) ),
            assertz(cl(Name, Lits, Vs)) )) )).

% ============================================
% Step 8: Resolution implementation and execution
% ============================================
% fresh vars per use
fresh(Lits, [], Lits, []).
fresh(Lits, [A|As], Out, [A=V|Ps]) :- sub(A, V, Lits, L1), fresh(L1, As, Out, Ps).

complementary(neg(A), B) :- B \= neg(_), unify_with_occurs_check(A, B).
complementary(A, neg(B)) :- A \= neg(_), unify_with_occurs_check(A, B).

dedup([], []).
dedup([H|T], R) :- ( member(X, T), X == H -> R = R1 ; R = [H|R1] ), dedup(T, R1).

% unbound, one name each
unbound(Ps, R) :- unbound(Ps, [], R).
unbound([], _, []).
unbound([N=V|T], Seen, R) :-
    ( var(V), \+ (member(S, Seen), S == V) -> R = [N=V|R1], Seen1 = [V|Seen]
    ; R = R1, Seen1 = Seen ),
    unbound(T, Seen1, R1).

bound_now(Ps, R) :- bound_now(Ps, [], R).
bound_now([], _, []).
bound_now([N=V|T], Prev, R) :-
    ( nonvar(V) -> R = [N/V|R1]
    ; member(N2=V2, Prev), V2 == V -> R = [N/N2|R1]
    ; R = R1 ),
    bound_now(T, [N=V|Prev], R1).

% linear input resolution
search(Goal, _, _, _, []) :- Goal == [], !.
search(Goal, GName, Pairs, D, [step(GName, Pre, Post)|Rest]) :-
    D > 0,
    select(L, Goal, GRest),
    cl(Name, Lits, Vs), \+ sub_atom(Name, 0, _, _, 'C9'),
    fresh(Lits, Vs, Lits1, New),
    append(Pairs, New, All),
    copy_term(p(Goal, Name, Lits1, All), Pre),
    unbound(All, Before),
    select(M, Lits1, CRest),
    complementary(L, M),
    bound_now(Before, Subst),
    append(GRest, CRest, R0), dedup(R0, R),
    copy_term(q(Subst, R, All), Post),
    D1 is D - 1,
    search(R, r, All, D1, Rest).

prove(Steps) :-
    cl(G, Start, []), sub_atom(G, 0, _, _, 'C9'),
    between(1, 15, D), search(Start, G, [], D, Steps), !.

% printing helpers
name_vars([]).
name_vars([N=V|T]) :- ( var(V) -> V = N ; true ), name_vars(T).

pp(all(V, F)) :- !, format('forall ~w ', [V]), pp(F).
pp(ex(V, F)) :- !, format('exists ~w ', [V]), pp(F).
pp(imp(A, B)) :- !, write('('), pp(A), write(' => '), pp(B), write(')').
pp(and(A, B)) :- !, write('('), pp(A), write(' & '), pp(B), write(')').
pp(or(A, B)) :- !, write('('), pp(A), write(' | '), pp(B), write(')').
pp(neg(A)) :- !, write('~'), pp(A).
pp(A) :- write(A).

pc([]) :- !, write('[]  (empty clause)').
pc(Ls) :- write('{ '), pl(Ls), write(' }').
pl([L]) :- !, pp(L).
pl([L|Ls]) :- pp(L), write(' | '), pl(Ls).

show(Title, P) :-
    format('~n% ~w~n', [Title]),
    forall(call(P, Id, F), (format('  ~w: ', [Id]), pp(F), nl)).

print_steps([], _).
print_steps([step(GName, p(G, CName, CL, A1), q(S, R, A2))|T], N) :-
    name_vars(A1), name_vars(A2),
    format('~nResolvent R~w:~n', [N]),
    format('  ~w: ', [GName]), pc(G), nl,
    format('  ~w: ', [CName]), pc(CL), nl,
    format('  unifier: ~w~n', [S]),
    format('  => R~w: ', [N]), pc(R), nl,
    N1 is N + 1, print_steps(T, N1).

main :-
    show('Step 1: Predicate logic representation', fol),
    show('Step 2: Negation of goal', negated_goal),
    show('Step 3: Implication removal', step3),
    show('Step 4: Negation movement', step4),
    show('Step 5: Standardization', step5),
    show('Step 6: Skolemization (none needed)', step6),
    build_clauses,
    format('~n% Step 7: CNF clauses~n'),
    forall(cl(N, L, _), (format('  ~w: ', [N]), pc(L), nl)),
    format('~n% Step 8: Resolution refutation~n'),
    ( prove(Steps) ->
        renumber(Steps, Steps1), print_steps(Steps1, 1),
        format('~nEmpty clause derived. Contradiction found.~n'),
        format('Therefore trusted(mira) is PROVED.~n')
    ;   format('~nNo refutation found.~n') ).

% fix resolvent labels
renumber(Steps, Out) :- renumber(Steps, 'C9', 1, Out).
renumber([], _, _, []).
renumber([step(_, P, Q)|T], G, N, [step(G, P, Q)|T1]) :-
    format(atom(G1), 'R~w', [N]), N1 is N + 1, renumber(T, G1, N1, T1).
