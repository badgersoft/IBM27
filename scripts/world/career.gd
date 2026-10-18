class_name Career
extends RefCounted
## Made-up career histories for the starting boxers.
##
## Every boxer starts the game with career earnings that fit where he is now
## and how long he has been at it. His past fights are replayed on paper: he
## starts at the bottom of the division and climbs steadily to where he is
## ranked today, reaching it CLIMB_SHARE of the way through his fights, and
## each fight pays the purse for its level (see Purse) and his usual share
## of it (more for a man who wins most of his fights). A champion has also
## had a few title fights. A heavyweight who has had thirty fights and sits
## in the top ten has banked a few hundred million dollars; a young amateur
## has a few thousand.

## How far through his career a boxer reached his current place.
const CLIMB_SHARE := 0.75
## Title fights already behind a champion, at random in this range.
const CHAMPION_TITLE_FIGHTS := Vector2i(1, 3)


## Career earnings, in dollars, for [param b] sitting at [param index] of a
## [param count]-man division ([param champion] if he holds the title).
static func estimate_earnings(b: BoxerData, index: int, count: int, champion: bool,
		rng: RandomNumberGenerator) -> int:
	var fights := b.total_fights()
	if fights == 0:
		return 0
	var win_rate := float(b.wins) / fights
	var share := 1.0 - Purse.WINNER_SHARE + (Purse.WINNER_SHARE * 2.0 - 1.0) * win_rate
	var total := 0.0
	for k in fights:
		var climbed := clampf((k + 1.0) / (fights * CLIMB_SHARE), 0.0, 1.0)
		var place := roundi(lerpf(count - 1, index, climbed))
		var opponent := clampi(place + rng.randi_range(-2, 3), 0, count - 1)
		if opponent == place:
			opponent = mini(place + 1, count - 1)
		total += Purse.for_fight(place, opponent, count, b.division, false, rng) * share
	if champion:
		for t in rng.randi_range(CHAMPION_TITLE_FIGHTS.x, CHAMPION_TITLE_FIGHTS.y):
			total += Purse.for_fight(0, rng.randi_range(1, 3), count, b.division, true, rng) * Purse.WINNER_SHARE
	return roundi(total)
