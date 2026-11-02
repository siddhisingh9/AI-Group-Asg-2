(define (problem rover-mission-extended)
  (:domain mars-rover)
  (:objects
    curiosity - rover
    base siteA siteB siteC siteD siteE siteF - location
    rock1 rock2 rock3 rock4 rock5 rock6 rock7 - rock
    bay1 bay2 - bay
    drill1 - drill)

  (:init
    (at curiosity base)
    (has-bay curiosity bay1) (has-bay curiosity bay2)
    (empty bay1) (empty bay2)
    (drill-at drill1 siteE)
    (rock-at rock1 siteA) (soft rock1)
    (rock-at rock2 siteB) (soft rock2)
    (rock-at rock3 siteC) (hard rock3)
    (rock-at rock4 siteD) (soft rock4)
    (rock-at rock5 siteF) (hard rock5)
    (rock-at rock6 siteE) (soft rock6)
    (rock-at rock7 siteF) (hard rock7)
    ; base-siteB closed (storm)
    (connected base siteA) (connected siteA base)
    (connected siteA siteC) (connected siteC siteA)
    (connected siteB siteD) (connected siteD siteB)
    (connected siteC siteE) (connected siteE siteC)
    (connected siteD siteE) (connected siteE siteD)
    (connected siteE siteF) (connected siteF siteE)
    ; one-way slope
    (connected siteC siteD))

  (:goal (and
    (rock-at rock1 base) (rock-at rock2 base) (rock-at rock3 base)
    (rock-at rock4 base) (rock-at rock5 base) (rock-at rock6 base)
    (rock-at rock7 base)
    (at curiosity base))))
