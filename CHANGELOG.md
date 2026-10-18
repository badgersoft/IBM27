# Changelog

Every build bumps the last number of the version while the game is a
prototype. The version lives in `project.godot` (`application/config/version`)
and is shown on the main menu.

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
