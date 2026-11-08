# Citizen routes and building people

2026-11-08 08:20 EST (09:20 EDT). Role: Game Logic. Branch gameplay/growth-readout, base 9928415.

Equal-length road routes now vary deterministically by citizen/day/leg. Destinations must be reachable from the previous stop; duplicated consecutive destinations are omitted. Default pathfinder calls preserve historical ordering. Saved RNG and economy are untouched. Workplace inspection lists actual living staff with home IDs and needs, and house residents include happiness.

Validation: release suite result included in ZIP test-results.txt; new tests check equal shortest distances, adjacent passable steps, multiple routes, disconnected work, repeatability and unchanged saved hash. Updated house-inspection expectations include happiness.

Limits: these are planned visual routines, not an hourly production/commute economy. No traffic congestion, households/relationships or persistent new citizen traits are introduced. Device movement and panel fit need Claude's build and Jordan's test.
