library(baseballr)
library(dplyr)
library(lubridate)
library(zoo)
library(ggplot2)
library(segmented)
library(patchwork) 
library(cluster)
library(tidyr)  # Or library(tidyverse) to load all tidyverse packages

#Get hitter data who were rookies from 2000 to 2022 
hitters <- data.frame(player_full_name = character(), player_id = integer())
for (i in 2000:2022) {
  rookies <- data.frame(mlb_stats(stat_type = 'season', stat_group = 'hitting', season = i,
                                  player_pool = 'Rookies',
                                  league_id = 104))
  hitters = rbind(hitters, rookies[, c('player_full_name','player_id')])
  }


hitters$season_debut <- 2010 #dummy variables
hitters$season_played <- 1
hitters$position <- 'Hitter'

#filter pitchers and the debut seasons of each hitter
for (i in 1:nrow(hitters)) {
  season <- mlb_people(person_ids = hitters[i, 2])
  
  # Safely extract debut_year (assuming hitters[i, 2] is numeric)
  hitters[i,3] <- as.integer(substr(as.character(season$mlb_debut_date), 1, 4))
  debut_year <- as.integer(substr(as.character(season$mlb_debut_date), 1, 4))
  
  # Safely extract last_played_year
  last_played_year <- if (!is.null(season$last_played_date) && 
                          !is.na(season$last_played_date)) {
    as.integer(substr(as.character(season$last_played_date), 1, 4))
  } else {
    as.integer(format(Sys.Date(), "%Y"))  # Assume active in current year
  }
  
  # Calculate seasons (only if debut_year is valid)
  if (!is.na(debut_year)) {
    hitters[i, 4] <- last_played_year - debut_year + 1
    hitters[i,5] <- as.character(season$primary_position_type)
  } else {
    hitters[i, 4] <- NA  # Could not calculate
    hitters[i,5] <- as.character(season$primary_position_type)
  }
}

hitters <- hitters %>% filter(position != 'Pitcher')


# Read and prepare the Fangraphs ID data
fangraphsplayerid <- read.csv('fangraphsplayerid.csv', header = TRUE) %>%
  rename(player_full_name = PLAYERNAME)

# Perform the join and select
hitters_final <- hitters %>%
  left_join(fangraphsplayerid, by = "player_full_name")
hitters_final <- hitters_final %>%
  dplyr::select('player_full_name', 'player_id', 'season_debut', 'season_played', 'IDFANGRAPHS')


hitters_final <- hitters_final %>% distinct(player_id, .keep_all = TRUE) %>% 
  filter(season_debut >= 2002)  %>% filter(!is.na(IDFANGRAPHS) == TRUE)


final_dat <- data.frame(
  PlayerName = character(),
  playerid = integer(),
  season = integer(),
  gm15_groupnumber = integer(),
  stringsAsFactors = FALSE
)
row <- 0
for (i in 1:nrow(hitters_final)) {
  row <- row + 1
  if (!is.na(hitters_final[i,"IDFANGRAPHS"])) {
    fangraphs_id <- as.integer(hitters_final[i,"IDFANGRAPHS"])
    debut_year_data <- tryCatch({
      log_data <- fg_batter_game_logs(playerid = fangraphs_id,
                                      year = as.integer(hitters_final[i, "season_debut"]))
      if (nrow(log_data) > 0) log_data else NULL
    }, error = function(e) NULL)
    
    if (!is.null(debut_year_data)) {
      every_season_game_log <- data.frame()
      for (j in (as.integer(hitters_final[i, "season_debut"])+1):2024) {
        tryCatch({
          log_data <- fg_batter_game_logs(playerid = fangraphs_id,
                                        year = j)
          if (nrow(log_data) > 0) {
            every_season_game_log <- bind_rows(every_season_game_log,log_data)
            }
          }, error = function(e) {message(paste("Skipping year", j, "–", e$message))
          })
      }
      required_cols <- c("K%", "BB%", 'O-Swing%', 'Z-Swing%', 'Swing%',
                         'O-Contact%', 'Z-Contact%', 'Contact%',
                         'Zone%', 'F-Strike%', 'SwStr%')
      if (all(required_cols %in%  colnames(every_season_game_log))) {
        if (nrow(every_season_game_log) > 0)
          every_season_game_log_date <- every_season_game_log  %>% 
            arrange(ymd(every_season_game_log$Date)) %>% filter(PA > 0)
        if (nrow(every_season_game_log_date) > 14) {
          every_season_game_log_15gms <- every_season_game_log_date %>%
            mutate(across(
              c(`O-Swing%`, `Z-Swing%`, `Swing%`,
                `O-Contact%`, `Z-Contact%`, `Contact%`,
                `F-Strike%`, `SwStr%`), ~ 
                rollapply(., 15, mean, na.rm = TRUE, fill = NA, align = "right"),
              .names = "avg_{.col}"
            )) %>%
            mutate(across(c('AB','PA','H','1B','2B','3B','HR',
                            'R','BB','IBB','SO','HBP','SF','Strikes',
                            'Balls','Pitches'),
                          ~ rollapply(., 15, sum, na.rm = TRUE, fill = NA, align = "right"),
                          .names = "total_{.col}")) %>%
            mutate(`avg_AVG%` = total_H/total_AB,
                  `avg_OBP%` = (total_H+total_BB+total_HBP)/(total_AB+total_BB+total_HBP+total_SF),
                  `avg_SLG%` = (total_1B + 2*total_2B + 3*total_3B + 4*total_HR)/total_AB,
                  `avg_K%` = (total_SO)/(total_PA),
                  `avg_BB%` = (total_BB)/(total_PA),
                  `BB/K` = (total_BB)/(total_SO),
                  `avg_Zone%` = (total_Strikes)/(total_Pitches)) %>%
            dplyr::select(PlayerName, playerid, season, 
                          `avg_AVG%`, `avg_OBP%`, `avg_SLG%`,`BB/K`,
                          `avg_K%`, `avg_BB%`, `avg_Zone%`, `avg_O-Swing%`,
                          `avg_Z-Swing%`, `avg_Swing%`, `avg_O-Contact%`,
                          `avg_Z-Contact%`, `avg_Contact%`,
                          `avg_F-Strike%`, `avg_SwStr%`) %>%
            slice(-c(1:14)) %>% 
            mutate(gm15_groupnumber = row_number())
          final_dat <- bind_rows(final_dat, every_season_game_log_15gms)
        }
      }
    }
  }
}



ggplot(final_dat, aes(x = gm15_groupnumber)) +
  geom_histogram(binwidth = 50, fill = "blue", alpha = 0.7) +
  geom_density(aes(y = after_stat(count) * 50), color = "red") +
  labs(title = "Distribution of gm15_gmnumber")
quantile(final_dat$gm15_groupnumber, probs = c(0.5, 0.90, 0.95, 0.99))

gm50percentile_dat <- final_dat %>% filter(gm15_groupnumber < 373)
gm90percentile_dat <- final_dat %>% filter(gm15_groupnumber < 1071)


analysis_dat_50gms <- gm50percentile_dat


analysis_dat_50gms <- analysis_dat_50gms %>% group_by(gm15_groupnumber) %>%
  summarise(`gm15_avg_AVG%` = mean(`avg_AVG%`),
            `gm15_avg_OBP%` = mean(`avg_OBP%`),
            `gm15_avg_SLG%` = mean(`avg_SLG%`),
            `gm15_avg_BB/K%` = mean(`BB/K`),
            `gm15_avg_K%` = mean(`avg_K%`),
            `gm15_avg_BB%` = mean(`avg_BB%`),
            `gm15_avg_O-Swing%` = mean(`avg_O-Swing%`),
            `gm15_avg_Z-Swing%` = mean(`avg_Z-Swing%`),
            `gm15_avg_Swing%` = mean(`avg_Swing%`),
            `gm15_avg_O-Contact%` = mean(`avg_O-Contact%`),
            `gm15_avg_Z-Contact%` = mean(`avg_Z-Contact%`), 
            `gm15_avg_Contact%` = mean(`avg_Contact%`),
            `gm15_avg_Zone%` = mean(`avg_Zone%`),
            `gm15_avg_F-Strike%` = mean(`avg_F-Strike%`),
            `gm15_avg_SwStr%` = mean(`avg_SwStr%`))

analysis_dat <- analysis_dat %>% 
  mutate(approx_PA = gm15_groupnumber * 60) # Assuming ~60 PA per 15G segment




fit_Zone_50_avg <- lm(`gm15_avg_Zone%` ~ gm15_groupnumber, data =analysis_dat_50gms)
fit_Zone_90 <- lm(`avg_Zone%` ~ gm15_groupnumber, data =gm90percentile_dat)
os_Zone1 <- segmented(fit_Zone_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
os_Zone2 <- segmented(fit_Zone_90, seg.Z = ~gm15_groupnumber, npsi = 1)

summary(os_Zone1)

newdata_Zone1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_Zone1$pred <- predict(os_Zone1, newdata = newdata_Zone1)
breakpoint_Zone1 <- os_Zone1$psi[2]

ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_Zone%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "Zone% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_Zone1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) + 
  geom_text(aes(x= breakpoint_Zone1 + 23, y= max(`gm15_avg_Zone%`), label = 'Breakpoint: 189'),
                color = 'red', size = 4) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_Zone1,
    linetype = "dashed",
    color = "red"
  ) +
  scale_y_continuous(
    limits = c(0.62, 0.65),  # Custom y-axis bounds
    breaks = seq(0.62, 0.65, by = 0.005)  # Tick marks every 0.005
  ) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))


#K% and BB% Trends
fit_k_50_avg <- lm(`gm15_avg_K%` ~ gm15_groupnumber, data =analysis_dat_50gms)
fit_BB_50_avg <- lm(`gm15_avg_BB%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_BB1 <- segmented(fit_BB_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
os_K1 <- segmented(fit_k_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)

newdata_BB1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_BB1$pred <- predict(os_BB1, newdata = newdata_BB1)
breakpoint_BB1 <- os_BB1$psi[2]

newdata_K1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))

newdata_K1$pred <- predict(os_K1, newdata = newdata_K1)
breakpoint_K1 <- os_1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_K%`), color = 'black', alpha = 0.5,shape = 17) +
  geom_point(aes(y = `gm15_avg_BB%`), color = 'black', alpha = 0.5,shape = 16) +
  geom_line(  # Segmented regression line
    data = newdata_K1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) + geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_K1,
    linetype = "dashed",
    color = "red"
  ) +  
  geom_text(aes(x= breakpoint_K1 -23, y= max(`gm15_avg_K%`), label = 'Breakpoint: 150'),
                 color = 'red', size = 4) +
  geom_line(  # Segmented regression line
    data = newdata_BB1,
    aes(x = gm15_groupnumber, y = pred),
    color = "blue",
    linewidth = 1
  ) + geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_BB1,
    linetype = "dashed",
    color = "blue"
  ) +  geom_text(aes(x= breakpoint_BB1 + 23, y= max(`gm15_avg_BB%`)+0.01, label = 'Breakpoint: 192'),
                 color = 'blue', size = 4) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "K% vs. BB% Trends") +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_BB1)
summary(os_K1)


#AVG Trend
fit_AVG_50_avg <- lm(`gm15_avg_AVG%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_AVG1 <- segmented(fit_AVG_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_AVG1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_AVG1$pred <- predict(os_AVG1, newdata = newdata_AVG1)
breakpoint_AVG1 <- os_AVG1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_AVG%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "AVG% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_AVG1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_AVG1,
    linetype = "dashed",
    color = "red"
  ) +  
  geom_text(aes(x= breakpoint_AVG1 + 23, y= max(`gm15_avg_AVG%`), label = 'Breakpoint: 341'),
                 color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.240, 0.280),  # Custom y-axis bounds
    breaks = seq(0.240, 0.280, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))


#OBP Trend
fit_OBP_50_avg <- lm(`gm15_avg_OBP%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_OBP1 <- segmented(fit_OBP_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_OBP1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_OBP1$pred <- predict(os_OBP1, newdata = newdata_OBP1)
breakpoint_OBP1 <- os_OBP1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_OBP%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "OBP% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_OBP1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_OBP1,
    linetype = "dashed",
    color = "red"
  ) +  geom_text(aes(x= breakpoint_OBP1 + 23, y= max(`gm15_avg_OBP%`), label = 'Breakpoint: 48'),
                 color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.3, 0.35),  # Custom y-axis bounds
    breaks = seq(0.3, 0.4, by = 0.005)) +  # Tick marks every 0.005
      theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))


#SLG Trend
fit_SLG_50_avg <- lm(`gm15_avg_SLG%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_SLG1 <- segmented(fit_SLG_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_SLG1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_SLG1$pred <- predict(os_SLG1, newdata = newdata_SLG1)
breakpoint_SLG1 <- os_SLG1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_SLG%`), color = 'black', alpha = 0.5,shape = 16) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "SLG% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_SLG1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_SLG1,
    linetype = "dashed",
    color = "red"
  ) +
  geom_text(aes(x= breakpoint_SLG1 + 22, y= max(`gm15_avg_SLG%`), label = 'Breakpoint: 58'),
            color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.38, 0.45),  # Custom y-axis bounds
    breaks = seq(0.38, 0.45, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_SLG1)

#O-Swing Trend
fit_O_Swing_50_avg <- lm(`gm15_avg_O-Swing%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_O_Swing1 <- segmented(fit_O_Swing_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_O_Swing1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_O_Swing1$pred <- predict(os_O_Swing1, newdata = newdata_O_Swing1)
breakpoint_O_Swing1 <- os_O_Swing1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_O-Swing%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "O-Swing% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_O_Swing1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_O_Swing1,
    linetype = "dashed",
    color = "red"
  ) + 
  geom_text(aes(x= breakpoint_O_Swing1 + 23, y= max(`gm15_avg_O-Swing%`), label = 'Breakpoint: 228'),
                color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.280, 0.315),  # Custom y-axis bounds
    breaks = seq(0.280, 0.315, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_O_Swing1)


#Z_Swing Trend
fit_Z_Swing_50_avg <- lm(`gm15_avg_Z-Swing%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_Z_Swing1 <- segmented(fit_Z_Swing_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_Z_Swing1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_Z_Swing1$pred <- predict(os_Z_Swing1, newdata = newdata_Z_Swing1)
breakpoint_Z_Swing1 <- os_Z_Swing1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_Z-Swing%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "Z-Swing% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_Z_Swing1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) + 
  geom_text(aes(x= breakpoint_Z_Swing1 + 23, y= max(`gm15_avg_Z-Swing%`), label = 'Breakpoint: 71'),
            color = 'red', size = 4) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_Z_Swing1,
    linetype = "dashed",
    color = "red"
  ) + 
  scale_y_continuous(
    limits = c(0.660, 0.690),  # Custom y-axis bounds
    breaks = seq(0.660, 0.690, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))


summary(os_Z_Swing1)

#Swing Trend
fit_Swing_50_avg <- lm(`gm15_avg_Swing%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_Swing1 <- segmented(fit_Swing_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_Swing1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_Swing1$pred <- predict(os_Swing1, newdata = newdata_Swing1)
breakpoint_Swing1 <- os_Swing1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_Swing%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "Swing% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_Swing1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_Swing1,
    linetype = "dashed",
    color = "red"
  ) +
  geom_text(aes(x= breakpoint_Swing1 + 23, y= max(`gm15_avg_Swing%`), label = 'Breakpoint: 214'),
            color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.470, 0.500),  # Custom y-axis bounds
    breaks = seq(0.470, 0.500, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_Swing1)

#O_Contact Trend
fit_O_Contact_50_avg <- lm(`gm15_avg_O-Contact%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_O_Contact1 <- segmented(fit_O_Contact_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_O_Contact1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_O_Contact1$pred <- predict(os_O_Contact1, newdata = newdata_O_Contact1)
breakpoint_O_Contact1 <- os_O_Contact1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_O-Contact%`), color = 'black', alpha = 0.5,shape = 17) +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "O-Contact% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_O_Contact1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_O_Contact1,
    linetype = "dashed",
    color = "red"
  ) + 
  geom_text(aes(x= breakpoint_O_Contact1 + 23, y= max(`gm15_avg_O-Contact%`), label = 'Breakpoint: 147'),
            color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.58, 0.66),  # Custom y-axis bounds
    breaks = seq(0.58, 0.66, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_O_Contact1)

#Z_Contact Trend
fit_Z_Contact_50_avg <- lm(`gm15_avg_Z-Contact%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_Z_Contact1 <- segmented(fit_Z_Contact_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_Z_Contact1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_Z_Contact1$pred <- predict(os_Z_Contact1, newdata = newdata_Z_Contact1)
breakpoint_Z_Contact1 <- os_Z_Contact1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_Z-Contact%`), color = 'black', alpha = 0.5,shape = 17) +
  
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "Z-Contact% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_Z_Contact1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_Z_Contact1,
    linetype = "dashed",
    color = "red"
  ) + 
  geom_text(aes(x= breakpoint_Z_Contact1 + 23, y= max(`gm15_avg_Z-Contact%`), label = 'Breakpoint: 71'),
            color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.850, 0.890),  # Custom y-axis bounds
    breaks = seq(0.850, 0.890, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_Z_Contact1)


#Contact Trend
fit_Contact_50_avg <- lm(`gm15_avg_Contact%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_Contact1 <- segmented(fit_Contact_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_Contact1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_Contact1$pred <- predict(os_Contact1, newdata = newdata_Contact1)
breakpoint_Contact1 <- os_Contact1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_Contact%`), color = 'black', alpha = 0.5,shape = 17) +
  '' +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "Contact% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_Contact1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_Contact1,
    linetype = "dashed",
    color = "red"
  ) +  
  geom_text(aes(x= breakpoint_Contact1 + 23, y= max(`gm15_avg_Contact%`), label = 'Breakpoint: 133'),
                 color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.770, 0.810),  # Custom y-axis bounds
    breaks = seq(0.770, 0.810, by = 0.005)) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))


summary(os_Contact1)

#F_Strike Trend
fit_F_Strike_50_avg <- lm(`gm15_avg_F-Strike%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_F_Strike1 <- segmented(fit_F_Strike_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_F_Strike1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))

newdata_F_Strike1$pred <- predict(os_F_Strike1, newdata = newdata_F_Strike1)
breakpoint_F_Strike1 <- os_F_Strike1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_F-Strike%`), color = 'black', alpha = 0.3,shape = 17) +
  '' +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "F-Strike% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_F_Strike1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_F_Strike1,
    linetype = "dashed",
    color = "red"
  ) + 
  geom_text(aes(x= breakpoint_F_Strike1 + 23, y= max(`gm15_avg_F-Strike%`), label = 'Breakpoint: 103'),
                 color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.62, 0.71), 
    breaks = seq(0.62, 0.71, by = 0.005)
  ) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_F_Strike1)

#SwStr Trend
fit_SwStr_50_avg <- lm(`gm15_avg_SwStr%` ~ gm15_groupnumber, data =analysis_dat_50gms)
os_SwStr1 <- segmented(fit_SwStr_50_avg, seg.Z = ~gm15_groupnumber, npsi = 1)
newdata_SwStr1 <- data.frame(gm15_groupnumber = seq(
  min(analysis_dat_50gms$gm15_groupnumber),
  max(analysis_dat_50gms$gm15_groupnumber),
  length.out = 372
))
newdata_SwStr1$pred <- predict(os_SwStr1, newdata = newdata_SwStr1)
breakpoint_SwStr1 <- os_SwStr1$psi[2]


ggplot(analysis_dat_50gms, aes(x = gm15_groupnumber)) +
  geom_point(aes(y = `gm15_avg_SwStr%`), color = 'black', alpha = 0.5,shape = 17) +
  '' +
  labs(x = "Approximate Career GM", y = "Rate", 
       title = "SwStr% Trends") +
  geom_line(  # Segmented regression line
    data = newdata_SwStr1,
    aes(x = gm15_groupnumber, y = pred),
    color = "red",
    linewidth = 1
  ) +
  geom_vline(  # Optional: Add vertical line at breakpoint
    xintercept = breakpoint_SwStr1,
    linetype = "dashed",
    color = "red"
  ) + 
  geom_text(aes(x= breakpoint_SwStr1 + 23, y= max(`gm15_avg_SwStr%`), label = 'Breakpoint: 128'),
            color = 'red', size = 4) +
  scale_y_continuous(
    limits = c(0.0920, 0.120), 
    breaks = seq(0.0920, 0.120, by = 0.005)  
  ) +
  theme_minimal() +
  theme(plot.title = element_text(size = 15, hjust = 0.5), 
        plot.subtitle = element_text(size = 10, hjust = 0.5), 
        axis.title = element_text(size = 10),
        axis.text = element_text(size = 7))

summary(os_SwStr1)


breakpoints <- data.frame(stats = c('AVG','OBP','SLG','K','BB','OSwing','Z_Swing',
                                    'Swing','O_Contact',
                                    'Z_Contact','Contact','Zone','F_Strike', 'SwStr'),
                          breakpoints = c(breakpoint_AVG1,breakpoint_OBP1,breakpoint_SLG1,
                                           breakpoint_K1,breakpoint_BB1,breakpoint_O_Swing1,
                                           breakpoint_Z_Swing1, breakpoint_Swing1, 
                                           breakpoint_O_Contact1, breakpoint_Z_Contact1,
                                           breakpoint_Contact1, breakpoint_Zone1,
                                           breakpoint_F_Strike1,breakpoint_SwStr1))

breakpoints$stats <- reorder(breakpoints$stats, breakpoints$breakpoints)

ggplot(breakpoints, aes(x = stats, y = breakpoints, fill = stats)) +
  geom_bar(stat = 'identity') +
  geom_text(data = breakpoints,
            aes(x = stats, y = breakpoints + 5,  
                label = paste0("", round(breakpoints, 1))),
            color = "black", size = 2.5) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  theme_minimal() +
  labs(x = "Stat", y = "Breakpoint (Career Games)", title = "Breakpoints by Stat") +
  theme(legend.position = 'None',
        plot.title = element_text(size = 15, hjust = 0.5),
        axis.title = element_text(size = 9, hjust = 0.5))




