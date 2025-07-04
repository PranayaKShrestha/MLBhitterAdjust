# MLBhitterAdjust

While watching the Toronto Blue Jays this season, I noticed Addison Barger starting to break out at the plate. It made me wonder: how long does it usually take for rookie hitters to adjust to major league pitching? Some players seem to struggle early but then suddenly turn a corner, while others never quite get there. That observation led to this project.

The goal is to explore whether we can quantify the point at which hitters begin to adjust by looking at game-by-game trends in stats like strikeout rate (K%), walk rate (BB%) and more in-depth Plate Discipline statistics such as O-Contact%, Zone%, etc. By tracking performance across a 15 games interval, I hope to find patterns in how rookies progress and whether there is a common adjustment period among successful players.

Research Question: When do rookie hitters begin to adjust to MLB pitching, and how can we measure that adjustment using performance data?

# SetUp/Methodology
The goal of this project is to examine how long it takes for rookie hitters to adjust to major league pitching by analyzing trends in plate discipline and batted-ball metrics over time. To do this, I collected and processed game-by-game performance data for rookies who debuted between 2002 and 2022.

Using the mlb_stats() function from the baseballr package, I pulled seasonal hitting stats for all MLB rookies from 2000 to 2022. For each player, I used the mlb_people() function to retrieve their MLB debut year and last active season, and filtered out pitchers and any players with incomplete or invalid records.

To access game-level data, I joined the player dataset with a Fangraphs ID file (fangraphsplayerid.csv). This provided a unique Fangraphs player ID for each hitter, which was necessary to query their game logs. One limitation of the dataset is the Fangraphs ID match rate. Of the 1,956 rookie hitters who debuted between 2000 and 2022, only 34% could be successfully matched to a valid Fangraphs player ID. This reduced the effective sample size for game-level analysis and may introduce selection bias if unmatched players differ systematically from those included.

For each player’s career game log, I computed rolling 15-game averages and totals for key statistics like:

**Plate discipline:** K%, BB%, BB/K, O-Swing%, Z-Swing%, Contact%, etc.

**Batting performance:** OBP, SLG, AVG

**Pitch tracking:** First-pitch strike rate, zone %, swinging strike %

To do this, I used rollapply() from the zoo package, which allowed for a right-aligned rolling window on cumulative and average stats. 

*One limitation of the analysis is that raw pitch-by-pitch data needed to manually calculate plate discipline metrics such as O-Swing%, Z-Swing%, Contact%, and others, was not available, so I relied on averaging the pre-calculated rate statistics provided in the Fangraphs game logs.

To investigate potential early-career adjustments by rookie hitters, I first examined the distribution of game-level observations using a histogram with an overlaid density curve. The resulting distribution is right-skewed, indicating that the majority of observations are concentrated in the earlier stages of player careers. Using the quantile() function, I determined that the 50th percentile corresponds to game 373. To focus the analysis on the initial adjustment period, I restricted the dataset to observations occurring at or before a player’s 373rd career game. This filtering approach helps isolate trends that are more likely to reflect early developmental changes rather than long-term performance patterns. 

![image](https://github.com/user-attachments/assets/ce77f998-607a-4c4c-bfe7-23480fc76b14)

Furthermore, to reduce noise and randomness, I grouped each game number and averaged each statistic for that set of game numbers.

# Analysis

To identify when rookie hitters begin to adjust to major league pitching, I used segmented regression. This method is well-suited for detecting structural changes or breakpoints in a time series. These breakpoints provide a way to estimate when a hitter begins to "adjust" or improve in a measurable way.

**K% and BB% Trends**

![image](https://github.com/user-attachments/assets/8c8a91eb-8546-4d32-87f4-b5622bc144b1)

The segmented() function in R estimates breakpoints in a dataset by fitting piecewise linear regressions. However, it will return a breakpoint even if the underlying trend does not exhibit a clear structural change. In the case of the K% and BB% trends, visual inspection suggests that neither metric displays a pronounced inflection point. Instead, K% shows a strong negative linear trend, while BB% exhibits a relatively flat or modest positive slope. This divergence implies that although hitters tend to strike out less as their careers progress, this improvement is not necessarily accompanied by a corresponding increase in walk rate. Hitters may be making more contact and putting the ball in play earlier in counts.


**AVG, OBP and SLG Trends**

![image](https://github.com/user-attachments/assets/7b0dcaf0-571c-4051-a668-0c62b5770189)
![image](https://github.com/user-attachments/assets/6aa4d338-e0d4-4eb6-8334-d038fbe0b38a)
![image](https://github.com/user-attachments/assets/d84ec02e-e1db-4ab3-93d4-af29f3f3e256)









