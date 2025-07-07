# MLBhitterAdjust

While watching the Toronto Blue Jays this season, I noticed Addison Barger starting to break out at the plate. It made me wonder: How long does it usually take for rookie hitters to adjust to major league pitching? Some players seem to struggle early but then suddenly turn a corner, while others never quite get there. That observation led to this project.

The goal is to explore whether we can quantify the point at which hitters begin to adjust by looking at game-by-game trends in stats like strikeout rate (K%), walk rate (BB%) and more in-depth Plate Discipline statistics such as O-Contact%, Zone%, etc. By tracking performance across a 15-game interval, I hope to find patterns in how rookies progress and whether there is a common adjustment period among successful players.

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


**AVG%, OBP% and SLG% Trends**
![image](https://github.com/user-attachments/assets/164e8cd3-8b48-4676-8b90-e5e4aa34dc93)

![image](https://github.com/user-attachments/assets/94c0130b-1bce-4fc6-8b0c-0f7de2a69701)

![image](https://github.com/user-attachments/assets/f63e9388-9049-48f9-bb7a-70123a660577)


Once again, there does not seem to be an underlying trend or a clear inflection point on AVG%, OBP%, or SLG%. Each statistic exhibits a steady increase, with OBP% and AVG% having similar slopes (2.924e-05 and 1.953e-05, respectively), which is expected since OBP% and AVG% are highly correlated. SLG% has a steeper positive slope, which is interesting.

**O-Swing%, Z-Swing% and Swing% Trends**

![image](https://github.com/user-attachments/assets/2aa4bd95-4ada-40a0-a6af-8cebf26eea48)

![image](https://github.com/user-attachments/assets/a8bcb81d-4198-4c81-a0ad-5df840da856d)

![image](https://github.com/user-attachments/assets/a5180e4c-b4c9-4c61-b039-aa16bf9ed51b)


Each graph tells an interesting story about a hitter's swing decisions. Looking at the O-Swing% (Swings at pitches outside the zone/pitches outside the zone), the trend shows a modest increase in O-Swing% before the breakpoint, followed by a slight decrease afterward. This suggests that rookie hitters may initially become more aggressive on pitches outside the zone due to the breaking and offspeed pitches in the majors has compared to the minor league. The Z-Swing% (Swings at pitches inside the zone/pitches inside the zone) has a sharp initial increase in Z-Swing% up to game 71 is followed by a gradual decline thereafter. This suggests rookie hitters are more aggressive with most pitches in the strike zone until around the breakpoint, where it starts to stabilize possibily due to hitters being more mature and selective on what part of the strike zone to swing at. For Swing%, the swing rate is relatively flat early on, with a slight increase, and then exhibits a notable downward trend after the breakpoint. Hitters appear to swing less frequently overall as they gain more experience, consistent with a more disciplined or selective plate approach. Overall, hitters start with increasing aggressiveness (rising Z-Swing% and O-Swing%) and eventually adjust by becoming more selective.

**O-Contact%, Z-Contact% and Contact% Trends**

![image](https://github.com/user-attachments/assets/37a53cf5-5bbc-4e71-9690-5b23461563c2)

![image](https://github.com/user-attachments/assets/c319e8da-133f-400e-a5fa-4a1c6b94ac08)

![image](https://github.com/user-attachments/assets/e50639d6-2192-4145-88c6-61efefcc948b)


Each graph here tells a similar story. Rookie hitters have a difficult time making contact in general, whether it be inside or outside the zone at the beginning. However, each graph's trend shows a modest linear increase on swings outside the strike-zone (O-Contact) and inside the strike-zone (Z-Contact). Interesting to note that each one of their breakpoints is between 100-150 games, which may be a signal of when hitters finally adjust to major league pitching (i.e., the amount of vertical/horizontal break on pitches, velocity, etc.) to be able to make contact. 

**Zone%, F-Strike% and SwStr% Trends**

![image](https://github.com/user-attachments/assets/8e02ec9e-95a8-479a-a5bd-817549f7d8d7)

![image](https://github.com/user-attachments/assets/3f8acef1-1046-4122-849c-eebf9573f7d7)

![image](https://github.com/user-attachments/assets/bee90227-19fc-411a-bfdf-23f24c079fcd)


These statistics likely reflect not only hitter behavior but also how pitchers approach rookie hitters. Nonetheless, they still offer valuable insight into the adjustments and decision-making patterns of hitters over time. The Zone% (Pitches in the strike zone / Total pitches) trend is relatively flat before the breakpoint, followed by a modest but consistent decline in Zone% afterward. F-Strike% (First pitch strikes / PA) and SwStr% (Swings and misses / Total pitches) also sees a steady decline; however, it is throughout the entire sample. Based on these trends, it suggests pitchers adjust their approach as hitters become more experienced (fewer pitches in the zone and fewer first-pitch strikes) while hitters reduce their swing and miss percentage as they can make more contact with pitches (as seen in the previous Contact graphs).


# Conclusion

Looking back at the original research question, how long does it usually take for rookie hitters to adjust to major league pitching, the analysis suggests that there is no single point in time when success begins. Instead, the data shows that each hitter follows a different path, with progress occurring at varying rates. Although breakpoints were identified for each metric using segmented regression, they were scattered across the career timeline rather than clustered around a specific point. This indicates that most hitters improve gradually, and in many cases, the trends are more linear than abrupt.

Overall, there isn't one moment when a rookie "figures it out." Development happens over time and looks different for every player. These findings reinforce the idea that growth at the major league level is a continuous process, not a sudden shift.
