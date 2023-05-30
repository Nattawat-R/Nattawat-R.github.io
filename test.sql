DECLARE
 MORNING_START,
 MORNING_END,
 AFTERNOON_END,
 EVENING_END INT64;
 -- Set the times for the times of the day
SET
 MORNING_START = 6;
SET
 MORNING_END = 12;
SET
 AFTERNOON_END = 18;
SET
 EVENING_END = 21;
 -- Suppose we would like to do an analysis based upon the time of day and day of the week
 -- We will do this at a person level such that we smooth over anomalous days for an individual
WITH
 user_dow_summary AS 
 (
 SELECT
   Id,
   FORMAT_DATE("%w", ActivityDate) AS dow_number,
   FORMAT_DATE("%A", ActivityDate) AS day_of_week,
   CASE
     WHEN FORMAT_DATE("%A", ActivityDate) IN ("Sunday", "Saturday") THEN "Weekend"
     WHEN FORMAT_DATE("%A", ActivityDate) NOT IN ("Sunday","Saturday") THEN "Weekday"
     ELSE "ERROR" END AS part_of_week,
   CASE
     WHEN TIME(Activity_Time) BETWEEN TIME(MORNING_START, 0, 0) AND TIME(MORNING_END, 0, 0) THEN "Morning"
     WHEN TIME(Activity_Time) BETWEEN TIME(MORNING_END, 0, 0) AND TIME(AFTERNOON_END,0, 0) THEN "Afternoon"
     WHEN TIME(Activity_Time) BETWEEN TIME(AFTERNOON_END, 0, 0) AND TIME(EVENING_END, 0, 0) THEN "Evening"
     WHEN TIME(Activity_Time) >= TIME(EVENING_END,0,0) OR TIME(TIME_TRUNC(Activity_Time, MINUTE)) <= TIME(MORNING_START,0,0) THEN "Night"
   ELSE "ERROR" END AS time_of_day,
   SUM(TotalIntensity) AS sum_total_intensity_TimeofDay,
   SUM(AverageIntensity) AS sum_average_intensity_Per_TimeofDay,
   AVG(AverageIntensity) AS avg_average_intensity_Per_TimeofDay,
   MAX(AverageIntensity) AS max_average_intensity_Per_TimeofDay,
   MIN(AverageIntensity) AS min_average_intensity_Per_TimeofDay
 FROM
 `my-first-project-project-51124.Fitabase.Hourly_Intensities_transformed`
 GROUP BY
   1,
   2,
   3,
   4,
   5
   ),
 intensity_deciles AS (
 SELECT
   DISTINCT dow_number,
   part_of_week,
   day_of_week,
   time_of_day,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.1) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_first_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.2) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_second_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.3) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_third_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.4) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_fourth_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.6) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_sixth_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.7) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_seventh_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.8) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_eigth_decile,
   ROUND(PERCENTILE_CONT(sum_total_intensity_TimeofDay,0.9) OVER (PARTITION BY dow_number, part_of_week, day_of_week, time_of_day),4) AS sum_total_intensity_ninth_decile
 FROM
   user_dow_summary ),
 basic_summary AS (
 SELECT
   part_of_week,
   day_of_week,
   time_of_day,
   SUM(sum_total_intensity_TimeofDay) AS sum_total_intensity,
   AVG(sum_total_intensity_TimeofDay) AS avg_total_intensity,
   SUM(sum_average_intensity_Per_TimeofDay) AS sum_total_average_intensity,
   AVG(sum_average_intensity_Per_TimeofDay) AS avg_total_average_intensity,
   SUM(avg_average_intensity_Per_TimeofDay) AS sum_average_intensity,
   AVG(avg_average_intensity_Per_TimeofDay) AS avg_average_intensity,
   AVG(max_average_intensity_Per_TimeofDay) AS average_max_intensity,
   AVG(min_average_intensity_Per_TimeofDay) AS average_min_intensity
 FROM
   user_dow_summary
 GROUP BY
   1,
   dow_number,
   2,
   3)
SELECT
 *
FROM
 basic_summary
LEFT JOIN
 intensity_deciles
USING
 (part_of_week,
   day_of_week,
   time_of_day)
ORDER BY
 1,
 dow_number,
 2,
 CASE
   WHEN time_of_day = "Morning" THEN 0
   WHEN time_of_day = "Afternoon" THEN 1
   WHEN time_of_day = "Evening" THEN 2
   WHEN time_of_day = "Night" THEN 3
END
 ;
