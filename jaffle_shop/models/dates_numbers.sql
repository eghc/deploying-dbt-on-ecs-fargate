SELECT
    dates.full_date,
    dates.year_day_number,
    numbers.number,
    dates.month_day_number % numbers.number = 0 as flag
FROM
    {{ref("stg_numbers")}} as numbers
    join {{ref("stg_dates")}} as dates 
    on numbers.number = dates.year_day_number