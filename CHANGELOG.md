# Changelog

Every build bumps the last number of the version while the game is a
prototype. The version lives in `project.godot` (`application/config/version`)
and is shown on the main menu.

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
