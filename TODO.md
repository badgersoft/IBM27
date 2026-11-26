# To do

Effort: **XS** under an hour, **S** a few hours, **M** about a day,
**L** a few days, **XL** a week or more.

## Open, quickest first

| #  | Item | Effort | From | Notes |
|----|------|--------|------|-------|
| 20 | Fewer repeated first names | S | Requested | Each country has only 6 - 15 first names (China 12, for about one boxer in ten; the USA 15, for one in four), so the same names keep coming round ("too many Qiangs"). Give every country 25 - 40 first names (and more surnames), and have the generator avoid a first name already used in the same division where it can. Duplicates stay possible, just rarer. |
| 10 | End of a career: retirement for the player's boxer, with a career summary | M | Left over | Today he never retires; skills fade from 32. A RETIRE option (and a forced one at 39) with his record, titles, earnings and best wins. |
| 14 | Rivalries and hype | M | Idea | Beat a man (or lose to him) and a rivalry builds: press-conference trash talk, a bigger crowd and purse for the rematch, newspaper build-up, and the crowd booing the villain. |
| 16 | Style balance below world class: Sluggers and Brawlers beat every careful style at skill 60 or lower | M | Found | Found with `tools/style_matrix.gd` in 0.1.44: at skill 60 a Slugger wins 88% of its fights and a Brawler 71%, a Boxer 44%, Counter and Evasive 24 - 28% (at skill 85 every style is 42 - 59%). Their toughness and power bonuses count for more when defence is poor. Matters early in a career, when the player's boxer (a Boxer by default) is at that level. Best done with 19. |
| 19 | Rebalance the divisions: easier at the bottom, harder at the top | M | Requested | The men at the bottom of each division (where a new boxer starts) are too strong to beat early on: roll their skills lower. Lift the top few a little so a title is a harder climb. Re-check with `tools/trial_career.gd` (time to contender and champion) and keep 16 in mind - part of the early difficulty is the style gap. |
| 11 | Technical decisions and no-contests (fights stopped early by cuts or clashes of heads) | L | Left over | Needs cuts first (see 13). |
| 13 | Cuts and injuries | L | Idea | Cuts that open and bleed during a fight, a cutman between rounds, and a doctor who can stop it (a TKO). Bad nights can leave an injury that keeps him out for weeks or months, so a hard fight has a real cost. |
| 15 | Moving between divisions | L | Idea | Move up or down a weight class mid-career: a weight cut that drains stamina, or carrying power up against bigger men. Titles in two divisions are a legacy goal. |
| 18 | Special punches: an overhand right or a windmill for a few boxers | L | Requested | Today every boxer has the same five punches: jab, cross, hook, uppercut and body shot (the uppercut is already in). Add one or two special punches (an overhand right, a windmill haymaker) that only a few boxers have, at most one each: new poses and animation, its damage, reach and risk (slow, easy to see coming, big if it lands), when the AI throws it, and showing it on his profile and the tale of the tape. Could be a perk the player's boxer earns or picks. |

## Done

| #  | Item | Effort | Done in |
|----|------|--------|---------|
| 5  | Rename STRENGTH to TOUGHNESS on screen | XS | 0.1.35 |
| 2  | Make the current week and month clearer on the career page | XS | 0.1.36 |
| 1  | Show the boxer's skills on the career page, with this week's gains | S | 0.1.36 |
| 3  | Choose height and weight on the new boxer screen | S | 0.1.37 |
| 7  | Pound for pound: choose a boxer to open his profile | XS | 0.1.38 |
| 4  | Knockout times read true (the clock ran at 3x during the count) | S | 0.1.39 |
| 8  | Save slots: delete and rename saved careers | S | 0.1.40 |
| 9  | The player's own fight as a newspaper story, his name highlighted | S | 0.1.41 |
| 12 | Add the trial-career simulator to `tools/` | XS | 0.1.42 |
| 6  | Style balance: the Boxer style was weakest at the top level | M | 0.1.44 |
| 17 | Fight offer reply: both answers at full size, the details on their own lines | XS | 0.1.46 |
