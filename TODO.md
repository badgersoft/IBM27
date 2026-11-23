# To do

Effort: **XS** under an hour, **S** a few hours, **M** about a day,
**L** a few days, **XL** a week or more.

## Requested

| #  | Item | Effort | Notes |
|----|------|--------|-------|
| 1  | ~~Show the boxer's skills (power, speed, stamina, chin, strength, intelligence) on the career page~~ | S | **Done in 0.1.36.** The header is full: either a compact skills strip under it or a SKILLS panel, with this week's training gains shown against them. |
| 2  | ~~Make the current week and month clearer on the career page~~ | XS | **Done in 0.1.36.** Move "WEEK 1 OF JANUARY 2027" to a large line at the top of the page (and show "FIGHT NIGHT" there in the last week). |
| 3  | ~~Choose height and weight on the new boxer screen~~ | S | **Done in 0.1.37.** < > pickers kept inside his division's range. Height changes reach (longer jab, harder to get inside); weight could nudge power against speed. |

## Left over from earlier

| #  | Item | Effort | Notes |
|----|------|--------|-------|
| 4  | ~~Knockout times: the round clock runs at 3x speed during the count, so about 40% of knockouts are recorded at 3:00~~ | S | **Done in 0.1.39.** Run the clock at real speed during the count; the time of the stoppage then reads true everywhere (results band, fight stats, archive). |
| 5  | ~~Rename STRENGTH to TOUGHNESS on screen~~ | XS | **Done in 0.1.35.** It only affects how well he takes punishment, not how hard he hits, so "strength" misleads. Display only. |
| 6  | Style balance: the Boxer style is noticeably weaker than Brawler and Slugger at the top level | M | Found in the balance tests (it throws about half as many punches). Tune its output or give it more reward for clean work and defence. |
| 7  | ~~Pound for pound: choose a boxer to open his profile~~ | XS | **Done in 0.1.38.** Rows become buttons; BACK returns to the list. |
| 8  | ~~Save slots: delete and rename saved careers~~ | S | **Done in 0.1.40.** From the CONTINUE SAVED CAREER list. |
| 9  | ~~The player's own fight as a newspaper story (not just the first round-up line), with his name highlighted~~ | S | **Done in 0.1.41.** "MURRAY STOPS FONSECA IN FOUR" with the purse and what it does to his ranking. |
| 10 | End of a career: retirement for the player's boxer, with a career summary | M | Today he never retires; skills fade from 32. A RETIRE option (and a forced one at 39) with his record, titles, earnings and best wins. |
| 11 | Technical decisions and no-contests (fights stopped early by cuts or clashes of heads) | L | Needs cuts first (see 13). |
| 12 | ~~Add the trial-career simulator to `tools/`~~ | XS | **Done in 0.1.42.** The balance checks used in 0.1.29 - 0.1.33 (`trial.gd`, `train_curve.gd`), so balance can be re-checked after any change. |

## Ideas to make it more fun and realistic

| #  | Item | Effort | Notes |
|----|------|--------|-------|
| 13 | Cuts and injuries | L | Cuts that open and bleed during a fight, a cutman between rounds, and a doctor who can stop it (a TKO). Bad nights can leave an injury that keeps him out for weeks or months, so a hard fight has a real cost. |
| 14 | Rivalries and hype | M | Beat a man (or lose to him) and a rivalry builds: press-conference trash talk, a bigger crowd and purse for the rematch, newspaper build-up, and the crowd booing the villain. |
| 15 | Moving between divisions | L | Move up or down a weight class mid-career: a weight cut that drains stamina, or carrying power up against bigger men. Titles in two divisions are a legacy goal. |
