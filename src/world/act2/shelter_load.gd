class_name ShelterLoad
extends RefCounted

## The arithmetic behind Act 2's load-shedding puzzle, on its own.
##
## Split out from `ShelterLogic` because it is the one part of the act that is
## pure numbers, and pure numbers are worth being able to test without a level,
## a player or a frame of simulation. `ShelterLogic` decides *when* to ask; this
## decides the answer.
##
## The rules are ordinary generator sizing, which is the point -- this is the
## most everyday calculation in building services and the game does not dress it
## up. See `docs/PUZZLES.md`, P2.3.

## The set's plate: 30 KW 37.5 KVA 0.8 PF. Continuous rating, in kilowatts.
const CAPACITY_KW := 30.0

## What it will ride for a moment. A diesel set takes a transient well above its
## continuous rating and recovers; 150% is the ordinary figure, and it is the
## number that makes an allocation which boots still able to fail.
const PEAK_KW := 45.0


## Everything drawing right now.
static func running(breakers: Array) -> float:
	var total := 0.0
	for node in breakers:
		var breaker := node as DeviceToggle
		if breaker != null and breaker.on:
			total += breaker.load_kw
	return total


## Whether the set will carry what is connected, continuously.
static func carries(breakers: Array) -> bool:
	return running(breakers) <= CAPACITY_KW


## What the bus sees at the instant `starting` starts: everything already
## running, less that load's own running draw, plus what it asks for to get
## moving. A motor pulls several times its running current until it is up to
## speed, and this is the moment allocations die.
static func inrush(breakers: Array, starting: DeviceToggle) -> float:
	if starting == null or not starting.on:
		return running(breakers)
	return running(breakers) - starting.load_kw + maxf(starting.surge_kw, starting.load_kw)


static func survives_start(breakers: Array, starting: DeviceToggle) -> bool:
	return inrush(breakers, starting) <= PEAK_KW


## How much has to come off before the set will hold, continuously. Zero when it
## already will. Reported so the act can say what it refused rather than only
## that it refused -- the trip is legible at the panel, and this is what lets
## the debug overlay and the suite say why.
static func overload_kw(breakers: Array) -> float:
	return maxf(0.0, running(breakers) - CAPACITY_KW)
