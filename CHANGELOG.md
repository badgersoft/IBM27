# Changelog

Every build bumps the last number of the version while the game is a
prototype. The version lives in `project.godot` (`application/config/version`)
and is shown on the main menu.

## 0.1.17

* Head to head records, from every fight the two men have had this season
  (exhibitions don't count):
  * Schedule: a VS YOU column with your record against each man (your wins
    first, gold if you lead, "-" if you have never met), and the purse
    offer says FIRST MEETING, YOU LEAD 2-0, HE LEADS 1-0 or ALL SQUARE.
  * Tale of the tape: a HEAD TO HEAD row with each man's wins, or FIRST
    MEETING (the tape is a row taller).
  * Newspaper: a rematch says so ("IT WAS THEIR SECOND MEETING: MURRAY
    LEADS THEIR SERIES 2-0."), in the round-up just the series. The
    player's own fight now always heads the round-up.
* Developer option `--career=<path>` loads a saved career (a fight scene
  then shows his next fight).


* New boxer screen: POINTS AVAILABLE (was POINTS LEFT) now sits at the top
  of the SKILLS box, level with NAME and SURNAME, so the six skills line up
  with the six pickers beside them (DIVISION to TRUNKS).
* Bigger amateur purses: the amateur range is now $1.2K - $5K (was $200 -
  $10K), before the usual cuts for a non-title fight and the division. The
  bottom fight of all, two lightweights, pays about $500 (was about $85);
  at heavyweight about $850. The best amateur fights now pay the same as
  the lowest semi-pro ones, so purses climb steadily up the rankings.


* New boxer screen tidied: the BOXER and SKILLS boxes are the same height
  and their rows line up (POINTS LEFT sits level with TRUNKS); NICKNAME and
  FROM start and end level, and the lists show whole rows only (no half
  rows when they scroll).
* Fewer fight offers at the start: offers piled up over the warm-up before
  January (five at the start of a career). Now only January's count, a
  manager who fancies the new man only sometimes makes the offer, and no
  more than two offer in a month. Sponsor offers for an unknown are rarer
  too. In a test of four new careers over four months: 0-1 fight offers
  and 0-2 sponsor offers a month.
* A new career no longer starts with everyone around him booked for months
  ahead: their fights after January are called off so he has men to
  approach in Schedule.
* Developer options for the career screenshots: `--train=<0-4>` and
  `--offers=<n>`.
* Training has a fifth choice, RECOVERY: no skill gains, but extra health
  back that week (more at a better recovery centre).
* The training buttons are tinted steel blue so they stand apart from the
  menu buttons below.
* Fight offers read "OFFERING A FIGHT", in columns: ranking (right-aligned),
  name, then the offer. The Schedule list uses the same words.
* A new boxer starts with every skill at 35 (was 25) and 45 points to spend
  (was 40), and with $5,000 (was $20,000).

## 0.1.14

* Main menu: START is now **EXHIBITION** and SEASON is now **CAREER**.
* **Exhibition**: the Boxers list in pick mode. Choose the red corner, then
  the blue (any division), or RANDOM to let the computer choose, then
  FIGHT!. Exhibitions are 3 rounds and count for nothing: no record, purse
  or ranking change. After the fight, NEW EXHIBITION picks again.
* **Career** pops up START NEW CAREER, and CONTINUE SAVED CAREER when
  there are saved careers (a list, newest first).
* **New boxer** screen: a random look to start with; name and surname;
  division (Lightweight by default), style, skin, hair colour, haircut and
  trunks colour with < and >; a nickname from ten made up for him or none;
  scrolling lists of countries and their cities; every skill at 25 with a
  pool of 40 points to spend with - and +.
* **Career page**: the boxer's portrait, overall rating, ranking, level,
  record, health, money ($20,000 to start), earnings, sponsor and rent; his
  next fight and the fight offers; the week's training (WEIGHTS, SPEED,
  STAMINA or PUNCHING, one a week, the rest greyed out); and SCHEDULE,
  FACILITIES, FIXTURES, NEWS, BOXERS, SAVE, MAIN MENU and NEXT WEEK (FIGHT
  NIGHT in the last week of the month).
* **Facilities**: five gyms from the free Local Gym to the Olympic Complex
  and five recovery centres from the Local Day Spa to the Elite Medical
  Institute, rented by the week; and sponsors - a long list of made-up
  firms, from local shops to global brands, offering a one-off payment
  for 3, 6 or 12 months depending on how valuable the boxer is.
* **Schedule**: the men he may fight (4 above to 6 below in his division,
  free, plus anyone who has asked), five purse offers from LOW to HIGH
  (half the purse must be in the bank), keen men nearly always accept and
  unsure ones are swayed by the money; one fight at a time, with CANCEL
  FIGHT for a forfeit of a quarter of the purse.
* A boxer who isn't fully recovered starts a fight with less health.
* Careers are saved in `user://careers/`: at the start, at every month
  end, on SAVE and when going back to the main menu.

## 0.1.13

* The new IBC belt, design B (Classic): a black strap, lit along its top
  edge and stitched in silver so it stands out on the dark screens. It has
  a big oval silver centre plate, engraved with a ring and a star, and a
  smaller riveted silver plate either side. It is drawn a little bigger:
  64 x 24 on the name plates and fixtures, 96 x 36 in the Boxers list and
  128 x 48 on the profile.

## 0.1.12

* Developer tool: `scenes/debug/belt_sheet.tscn` shows the current IBC
  belt and four candidate designs (Classic, Crest, Globe, Jewel) at the
  sizes the game uses and in a Boxers list row, so one can be chosen. The
  pictures are in `docs/design/`. The game itself is unchanged.

## 0.1.11

* Big punches spray blood instead of flashing: drops fly off away from the
  puncher and leave spots on the canvas for the rest of the fight.
* Between rounds, once a boxer sits down in his corner his health and
  energy bars climb to where his corner can get him. They move quickly at
  first, then ease. Stamina and the recovery stat decide how far they go,
  and the corner does less in later rounds.
* The crowd cheers longer: a cheering loop swells for significant strikes,
  one-twos and big punches, longest for knockdowns (through the count) and
  the winner's name, and holds a while before it dies away.
* Monsters: two of the best boxers in each division are knockout artists.
  They have huge power, a granite chin and records with 90-100% KOs. They
  hit harder, land more big punches, knock men down more often and come
  forward looking for the finish.
* Glass jaws: one boxer per division looks and punches like a monster but
  has a poor chin. A significant punch on it is more than twice as likely
  to put him down, and he is slower to get up.
* Knockdowns and damage are scaled by fight length, so 10- and 12-round
  fights no longer end early most of the time.
* Excitement ratings re-centred to suit.
* Managers no longer arrange a rematch within 9 months unless there is no
  one else to fight.

## 0.1.10

* The season. SEASON on the main menu opens the Fixtures screen,
  starting in January 2027.
  - Each month the managers arrange fights two months ahead. That is the
    training camp, where the boxer trains 50% harder.
  - Everyone fights three or four times a year, at least three months
    apart, and about a quarter of the boxers fight in any month.
  - Opponents follow the challenge rules: no more than 4 places above or
    6 below in his own division, only the bottom two available men of the
    division above, only the top three of the division below.
  - Each manager picks by type: the biggest purse, the weakest man, or
    anyone at all.
* Champions defend often, and at least once a year. A retiring champion
  leaves the title vacant, and the two best contenders fight for it.
* Fight night is the end of the month. Watch any fixture in the ring, or
  PLAY MONTH to have the rest fought: every fight is a full simulation by
  the same fight engine, run in the background with results filling in
  as they come. BOOKED and LAST MONTH tabs show what's coming and what
  happened.
* Month end: boxers train and age (young men improve, from 32 skills
  fade), old boxers retire and young prospects replace them.
* The monthly newspaper, THE RINGSIDE GAZETTE.
  - Title fights make the main headline (new champions first), with more
    stories under it.
  - Professional fights rated 9 out of 10 or better, with a top-ten man in
    them, get a feature.
  - A round-up of the other results.
  - IN BRIEF: rankings climbers in the player's division (middleweight for
    now), retirements and new faces.
  - A results page with every fight's rating.
* Excitement ratings: every fight is rated out of 10. Most fall between 3
  and 7, 9+ is rare and 10 is next to impossible.
* Post-fight stats: after the verdict, CONTINUE opens a full screen of
  both boxers' numbers side by side (thrown, landed, accuracy, jabs, power
  punches, significant strikes, big punches, one-twos, punches avoided,
  knockdowns, health). It also shows the result, purse, ranking changes
  and the match rating.
* Purses never go past their level's top figure ($100M at the most).

## 0.1.9

* Rankings: every division is ranked from top to bottom and split into
  thirds, which are the boxers' levels. The top third is Professional
  (12-round fights), the middle Semi-Pro (10 rounds) and the bottom
  Amateur (6 rounds).
* The IBC title: one per division, held to begin with by the division's
  best man. The champion is listed as "C" with his belt (black, with a
  silver centre plate and a smaller silver plate either side) beside his
  name: in the Boxers list, on his profile and on his name plate in the
  ring (under his record). His ranking is shown in gold on the tale of the
  tape.
* Title fights end with "...AND STILL IBC HEAVYWEIGHT CHAMPION" or
  "...AND NEW IBC HEAVYWEIGHT CHAMPION" as the winner's name is called.
  A drawn title fight leaves the champion with his belt.
* Purses: each fight is worth an amount set by the two boxers' level and
  rankings. Amateur fights pay a few hundred dollars ($10K at most),
  Semi-Pro mostly $5K-$25K ($50K at most), and Professional fights tens of
  millions, up to $100M for a heavyweight title fight. Fights without a
  title pay 70%, middleweight fights 80% and lightweight fights 60%. The
  winner takes 60% and the loser 40%. The purse is shown on the tale of
  the tape.
* Career earnings: every boxer has them (on his profile), with starting
  figures that fit his ranking and career so far.
* Managers: every boxer has his own, of one of three types: Money Man,
  Protective or Old School. They are shown on the profile and are ready
  for arranging fights in the next build.
* Two ranking systems, as asked (`--ranking=ladder`, the default, or
  `--ranking=points`); see the README for how each works.
* START now picks an opponent ranked near the first boxer (no more than 4
  places above or 6 below). The length, purse and venue suit their level.
  A fight involving the champion is for his title, at the Grand Arena.
  Results move both boxers in the rankings.
* The Boxers list has RANK and LEVEL columns (CM made way, as height is on
  the profile) and an ORDER button to switch between overall rating and
  ranking order. The profile has a new CAREER panel: ranking, level,
  earnings and manager.

## 0.1.8

* Thirty boxers in every division (was ten). The Boxers list shows them
  best first by overall rating, ten to a page, with arrows beside the tabs
  (or Page Up / Page Down) to turn the pages. PREV and NEXT on a profile
  step through the division in the same order, and BACK returns to the
  page he is on. Each division has two or three showboats.
* The one-two: skilled boxers now throw a jab followed straight away by a
  cross, and counter-punchers fire one back after slipping or blocking a
  punch. If the jab lands clean, the cross does 25% more damage and is a
  little likelier to be a big punch. A landed one-two shows "ONE-TWO!"
  over the boxer and gets a roar from the crowd.
* At the bell the boxers walk briskly to the middle of the ring, meeting
  in about 3 seconds instead of 8 or 9. A really defensive boxer (evasive,
  told to defend, or still badly hurt) still takes his time.
* The legs no longer look back to front. The front leg is now the long,
  nearly straight one, and the back leg is bent with the heel just off the
  floor, so the boxers stand in a proper stance.
* Knockdowns are a touch rarer, to keep stoppage rates where they were with
  the extra action (about 26% light, 37% middle, 53% heavy over six
  rounds).

## 0.1.7

* The game is now laid out for a 1280 x 800 window (was 1280 x 720), with
  16 px margins round the fight screen so it feels less squashed.
* The panels under the ring are taller and show THROWN again, on its own
  row, between ENERGY and LANDED, with SIG. STRIKES below.
* The Boxers list rows, the profile portrait and skills, and the main menu
  all use the extra height.

## 0.1.6

* Showboats show off much less often, at two levels: during the fight they
  now and then point a glove at the opponent or drop their hands and stick
  out the chin; in the second half, when on top, they throw both arms in
  the air. Half the time they also do it over a man they have knocked down.
* New stat, SIGNIFICANT STRIKES: hard, clean power shots that really hurt
  (about one landed punch in five in every division). The panels under the
  ring now show LANDED as landed/thrown and SIG. STRIKES under it. Each
  judge has a secret liking for them: some weight them heavily, others
  count them like any other landed punch.
* The ring aprons have no lettering, and the hall's back banner is a blank
  box for now.

## 0.1.5

* Scorecards for every fight length: 3 rounds (exhibition), 6 (amateur),
  10 (semi-pro) and 12 (professional). Each round is a box coloured by who
  won it (red, blue, grey for even, gold edge for a 10-8 round) with the
  round numbers above, sized so every length fills the card neatly. The
  pundit's card and the full-width official card both use it, and totals
  have room for three digits (12-round cards go past 100).
* Fight length is now a setting of each fight (6 rounds for now;
  `--rounds=3|6|10|12` to test the others). The tale of the tape shows the
  length and level, e.g. "6 ROUNDS - AMATEUR - ...".

## 0.1.4

* Fights are now 6 rounds. The pundit's card shows the rounds in two rows
  of three beside the total; at the verdict a full-width official card
  (all six rounds for each judge) takes over the bottom of the screen.
* Balance for the longer fights: the late-round damage boost is spread over
  the whole fight, boxers shake off 12-28% of their damage in the corner
  (by their recovery stat, now shown on the profile), knockdowns are a
  little less likely and earlier knockdowns slow the count less.
* Fix: two cautious boxers (e.g. a counter-puncher against an evasive
  boxer) could stand out of range for whole rounds. A boxer who has not
  thrown for a couple of seconds now edges closer.
* In simulation, stoppages now end about 28% of lightweight, 38% of
  middleweight and 51% of heavyweight six-round fights.
* Face-on boxers: narrower, lower, more natural shoulders without the
  rounded "pads".
* Profile: every line is now the same 16 px size (the hometown has its own
  row, the style description is full size and shortened to fit).

## 0.1.3

* Sound: the start-of-round bell is a single shorter, lower, softer ring;
  the end-of-round bell is a little quieter.
* The judges' read-out is a second slower per judge and has no ding; the
  crowd gives a small cheer for a fair-looking score and an "oooh" for one
  that seems wrong.
* Boxers list: the line-up picture is gone and the table fills the screen,
  with taller rows and more room for nicknames. Columns are evenly spaced,
  W / L / D / KO are centred under their headings, styles are shortened
  (BRL, SLG, BOX, CNR, EVA, SHW), the individual skills are replaced by the
  overall rating, and the RECORD heading sits clear of its rule.
* New boxer profile screen: choose a boxer in the list to see his portrait,
  details and all six skills, with PREV / NEXT through the division.
* New style, SHOWBOAT (one or two per division): quick reactions and good
  at slipping punches, but drops his guard and taunts a lot, so he gets
  caught.
* The trainers are no longer drawn between rounds; their advice bubbles
  point down to the corners.

## 0.1.2

* Fight screen name plates are bigger (520 x 56): the record and nickname
  are now 16 px like the name. The name and record share the top line and
  the nickname sits under the name. To make room, the score bug is narrower
  and the panels under the ring are 8 px shorter.
* The winner is announced with his nickname between his first name and
  surname, e.g. JAKE "MAMMOTH" HARRIS!

## 0.1.1

* Version numbering: every build from now on bumps the last number.

## 0.1.0

Everything up to this point, built up over the first prototype rounds:

* Main menu (START, BOXERS); fight screen with name plates, score bug,
  condition panels and scorecard; three 1-minute rounds shown as 3:00.
* Four venues: Small Town Gym, City Gym, Boxing Hall and Grand Arena.
* Procedural pixel-art boxers: build from height and weight, side-on fight
  rig with the full animation set, face-on rig for the weigh-in line-up and
  the verdict.
* Lightweight, middleweight and heavyweight divisions of ten boxers each,
  with records, skills, styles and unique nicknames.
* AI driven by skills and style; trainer advice between rounds; blocking,
  big punches, knockdowns and the count.
* Pool of 15 judges with public fairness and secret preferences; ringside
  pundit's card filled in after each round; verdict read out judge by judge
  while the referee waits to raise the winner's arm.
* Boxers screen with a tab per division; headless fight simulator for balance.
