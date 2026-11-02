(define (domain mars-rover)
  (:requirements :strips :typing)
  (:types rover location rock bay drill)

  (:predicates
    (at ?r - rover ?l - location)
    (rock-at ?k - rock ?l - location)
    (drill-at ?d - drill ?l - location)
    (connected ?from - location ?to - location)
    (soft ?k - rock)
    (hard ?k - rock)
    (has-bay ?r - rover ?b - bay)
    (empty ?b - bay)
    (in-bay ?k - rock ?b - bay)
    (has-drill ?r - rover))

  ; move between connected locations
  (:action move
    :parameters (?r - rover ?from - location ?to - location)
    :precondition (and (at ?r ?from) (connected ?from ?to))
    :effect (and (at ?r ?to) (not (at ?r ?from))))

  ; pick drill, keep forever
  (:action pick-drill
    :parameters (?r - rover ?d - drill ?l - location)
    :precondition (and (at ?r ?l) (drill-at ?d ?l))
    :effect (and (has-drill ?r) (not (drill-at ?d ?l))))

  ; collect soft rock
  (:action collect-soft
    :parameters (?r - rover ?k - rock ?b - bay ?l - location)
    :precondition (and (at ?r ?l) (rock-at ?k ?l) (soft ?k)
                       (has-bay ?r ?b) (empty ?b))
    :effect (and (in-bay ?k ?b) (not (rock-at ?k ?l)) (not (empty ?b))))

  ; hard rock needs drill
  (:action collect-hard
    :parameters (?r - rover ?k - rock ?b - bay ?l - location)
    :precondition (and (at ?r ?l) (rock-at ?k ?l) (hard ?k)
                       (has-drill ?r) (has-bay ?r ?b) (empty ?b))
    :effect (and (in-bay ?k ?b) (not (rock-at ?k ?l)) (not (empty ?b))))

  ; drop rock, free bay
  (:action deposit
    :parameters (?r - rover ?k - rock ?b - bay ?l - location)
    :precondition (and (at ?r ?l) (has-bay ?r ?b) (in-bay ?k ?b))
    :effect (and (rock-at ?k ?l) (empty ?b) (not (in-bay ?k ?b)))))
