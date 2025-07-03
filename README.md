# MLBhitterAdjust

While watching the Toronto Blue Jays this season, I noticed Addison Barger starting to break out at the plate. It made me wonder: how long does it usually take for rookie hitters to adjust to major league pitching? Some players seem to struggle early but then suddenly turn a corner, while others never quite get there. That observation led to this project.

The goal is to explore whether we can quantify the point at which hitters begin to adjust by looking at game-by-game trends in stats like strikeout rate (K%), walk rate (BB%) and more in-depth Plate Discipline statistics such as O-Contact%, Zone%, etc. By tracking performance across a 15 games interval, I hope to find patterns in how rookies progress and whether there is a common adjustment period among successful players.

Research Question: When do rookie hitters begin to adjust to MLB pitching, and how can we measure that adjustment using performance data?

# SetUp/Methodology
The goal of this project is to examine how long it takes for rookie hitters to adjust to major league pitching by analyzing trends in plate discipline and batted-ball metrics over time. To do this, I collected and processed game-by-game performance data for rookies who debuted between 2002 and 2022.

Using the mlb_stats() function from the baseballr package, I pulled seasonal hitting stats for all MLB rookies from 2000 to 2022. For each player, I used the mlb_people() function to retrieve their MLB debut year and last active season, and filtered out pitchers and any players with incomplete or invalid records.

To access game-level data, I joined the player dataset with a Fangraphs ID file (fangraphsplayerid.csv). This provided a unique Fangraphs player ID for each hitter, which was necessary to query their game logs. One limitation was that the sample rate was only 34% meaning I was only able to find the Fangraphs IDs of 34% of the 1956 hitters who debuted from 2000-2022. 

For each player’s career game log, I computed rolling 15-game averages and totals for key statistics like:

Plate discipline: K%, BB%, BB/K, O-Swing%, Z-Swing%, Contact%, etc.

Batting performance: OBP, SLG, AVG

Pitch tracking: First-pitch strike rate, zone %, swinging strike %

To do this, I used rollapply() from the zoo package, which allowed for a right-aligned rolling window on cumulative and average stats.
