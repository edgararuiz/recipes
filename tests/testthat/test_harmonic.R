library(testthat)
library(recipes)

x_year <- seq(0, 86400 * 365 * 4, by = 31556926)
x_month_sidereal <- seq(0, 86400 * 7, by = 2360592)
x_month_synodic <- seq(0, 86400 * 7, by = 2551443)
x_month_average <- seq(0, 86400 * 365, by = 2629744)
x_week <- seq(0, 86400 * 365, by = 86400 * 7)
x_day <- seq(0, 86400 * 365, by = 86400)
x_hour <- seq(0, 86400 * 7, by = 3600)
x_minute <- seq(0, 86400, by = 60)
x_second <- 0:86400




test_that("harmonic error", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * x_second / (3600 * 6)),
    time_var = x_second
  )


  # missing input
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(time_var,
        frequency = 1,
        cycle_size = NA
      )
  )
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(time_var,
        frequency = 1,
        starting_val = 0,
        cycle_size = NA
      )
  )
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
     step_harmonic(time_var,
       frequency = 1,
       starting_val = 0,
       cycle_size = "a"
     )
  )

  # starting_val is numeric, Date or POSIXt
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(time_var,
        frequency = 1,
        starting_val = "a",
        cycle_size = 86400
      )
  )

  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(
        time_var,
        frequency = 1,
        starting_val = factor("a"),
        cycle_size = 86400
      )
  )
})

test_that("harmonic multiple variables", {
  harmonic_dat_mult <- tibble(
    osc = sin(2 * pi * x_second / (3600 * 6)),
    time_var_1 = x_second,
    time_var_2 = x_second * 2
  )

  rec <- recipe(osc ~ time_var_1 + time_var_2, data = harmonic_dat_mult) %>%
    step_harmonic(time_var_1, time_var_2,
      frequency = c(5, 10),
      cycle_size = 1
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(rec$time_var_1_sin_1, rec$time_var_2_sin_2)
  expect_equal(rec$time_var_1_cos_1, rec$time_var_2_cos_2)
})


test_that("harmonic frequencies", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * x_second / (3600 * 6)),
    time_var = x_second
  )

  rec <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = c(1, 1.93, 2),
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(ncol(rec), 7)
})


test_that("harmonic keep_original_cols", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * x_second / (3600 * 6)),
    time_var = x_second
  )

  rec <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = c(1, 1.93, 2),
      cycle_size = 86400,
      keep_original_cols = TRUE
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(ncol(rec), 8)
})


test_that("harmonic phase", {
  harmonic_dat_1 <- tibble(
    osc = sin(2 * pi * x_second / 86400),
    time_var = x_second
  )

  rec_1 <- recipe(osc ~ time_var, data = harmonic_dat_1) %>%
    step_harmonic(time_var,
      frequency = 1,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  # different starting point
  harmonic_dat_2 <- tibble(
    osc = sin(2 * pi * (x_second + 43200) / 86400),
    time_var = x_second
  )
  rec_2 <- recipe(osc ~ time_var, data = harmonic_dat_2) %>%
    step_harmonic(time_var,
      frequency = 1,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)
  fit_1 <- lm(osc ~ time_var_sin_1 + time_var_cos_1 - 1, rec_1)
  fit_2 <- lm(osc ~ time_var_sin_1 + time_var_cos_1 - 1, rec_2)
  co_1 <- coefficients(fit_1)
  co_2 <- coefficients(fit_2)
  expect_equal(as.numeric(atan2(co_1[1], co_1[2]) - atan2(co_2[1], co_2[2])), pi,
    ignore_attr = TRUE
  )


  # set reference (starting_val) at half period
  rec_3 <- recipe(osc ~ time_var, data = harmonic_dat_2) %>%
    step_harmonic(time_var,
      frequency = 1,
      starting_val = 43200,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)
  fit_3 <- lm(osc ~ time_var_sin_1 + time_var_cos_1 - 1, rec_3)
  co_3 <- coefficients(fit_3)
  expect_equal(atan2(co_1[1], co_1[2]), atan2(co_3[1], co_3[2]))
})

test_that("harmonic model recovers amplitude", {
  set.seed(123)
  amplitude <- abs(rnorm(1))
  harmonic_dat <- tibble(
    osc = amplitude * sin(2 * pi * x_second / (3600 * 6)),
    time_var = x_second
  )
  rec <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = 4,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)
  fit <- lm(osc ~ time_var_sin_1 + time_var_cos_1 - 1, rec)
  expect_equal(sqrt(sum(coefficients(fit)^2)), amplitude)
})



test_that("harmonic datetime, numeric and date columns", {
  x_datetime <- as.POSIXct(x_second,
    origin = "1970-01-01",
    tz = "UTC"
  )

  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var_posixt = x_datetime,
    time_var_int = x_second
  )

  rec_datetime <- recipe(osc ~ time_var_posixt, data = harmonic_dat) %>%
    step_harmonic(time_var_posixt,
      frequency = 4,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  rec_numeric <- recipe(osc ~ time_var_int, data = harmonic_dat) %>%
    step_harmonic(time_var_int,
      frequency = 4,
      cycle_size = 86400
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(rec_datetime[[3]],
    rec_numeric[[3]],
    ignore_attr = TRUE
  )


  x_date <- as.Date(x_second[1:366], origin = "1970-01-01") # one year
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_date)),
    time_var_date = x_date
  )

  rec_date <- recipe(osc ~ time_var_date, data = harmonic_dat) %>%
    step_harmonic(time_var_date,
      frequency = 12,
      cycle_size = 366
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  x_date_sec <- seq(0, 365, 1) * 86400 # one year
  harmonic_dat <- tibble(
    osc = sin(2 * pi * x_date_sec),
    time_var_date_s = x_date_sec
  )

  rec_date_s <- recipe(osc ~ time_var_date_s, data = harmonic_dat) %>%
    step_harmonic(time_var_date_s,
      frequency = 12,
      cycle_size = 86400 * 366
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(rec_date[[3]],
    rec_date_s[[3]],
    ignore_attr = TRUE
  )
})


test_that("harmonic NA in term", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var = x_second
  )
  harmonic_dat[20, "time_var"] <- NA
  harmonic_dat[3, "time_var"] <- NA
  rec_na <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = 4,
      cycle_size = 86400,
      keep_original_cols = TRUE
    ) %>%
    prep() %>%
    bake(new_data = NULL)

  expect_equal(sum(is.na(rec_na)), 2 * 3)

  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var = NA_real_
  )

  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(time_var,
        frequency = 4,
        cycle_size = 86400
      ) %>%
      prep() %>%
      bake(new_data = NULL)
  )
})

test_that("harmonic character in term", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var = "x_second"
  )
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var, data = harmonic_dat) %>%
      step_harmonic(time_var,
        frequency = 4,
        cycle_size = 86400
      ) %>%
      prep() %>%
      bake(new_data = NULL)
  )
})


test_that("harmonic cycle_size length", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var_1 = x_second,
    time_var_2 = x_second,
    time_var_3 = x_second
  )
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var_1 + time_var_2 + time_var_3, data = harmonic_dat) %>%
      step_harmonic(time_var_1, time_var_2, time_var_3,
        frequency = 4,
        cycle_size = c(86400, 86400)
      ) %>%
      prep()
  )
})

test_that("harmonic starting_val length", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var_1 = x_second,
    time_var_2 = x_second,
    time_var_3 = x_second
  )
  expect_snapshot(error = TRUE,
    recipe(osc ~ time_var_1 + time_var_2 + time_var_3, data = harmonic_dat) %>%
      step_harmonic(time_var_1, time_var_2, time_var_3,
        frequency = 4,
        starting_val = c(86400, 86400),
        cycle_size = 86400
      ) %>%
      prep()
  )
})

test_that("harmonic check tidy starting value", {
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_second) / (3600 * 6)),
    time_var = x_second
  )

  tidy_starting <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = 4,
      cycle_size = 86400
    ) %>%
    prep() %>%
    tidy(number = 1)


  expect_equal(tidy_starting$starting_val[[1]], 0,
    ignore_attr = TRUE
  )


  tidy_starting <- recipe(osc ~ time_var, data = harmonic_dat) %>%
    step_harmonic(time_var,
      frequency = 4,
      starting_val = 10,
      cycle_size = 86400
    ) %>%
    prep() %>%
    tidy(number = 1)



  expect_equal(tidy_starting$starting_val[[1]], 10,
    ignore_attr = TRUE
  )


  x_datetime <- as.POSIXct(x_second,
    origin = "1990-01-01 01:02:23",
    tz = "UTC"
  )
  harmonic_dat <- tibble(
    osc = sin(2 * pi * as.numeric(x_datetime) / (3600 * 6)),
    time_var_posixt = x_datetime
  )

  tidy_starting <- recipe(osc ~ time_var_posixt, data = harmonic_dat) %>%
    step_harmonic(time_var_posixt,
      frequency = 4,
      starting_val = as.POSIXct(100, origin = "1970-01-01"),
      cycle_size = 86400
    ) %>%
    prep() %>%
    tidy(number = 1)


  expect_equal(tidy_starting$starting_val[[1]],
    100,
    ignore_attr = TRUE
  )
})

test_that("empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_harmonic(rec1, frequency = 1 / 11, cycle_size = 1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_harmonic(rec, frequency = 1 / 11, cycle_size = 1)

  expect <- tibble(
    terms = character(),
    starting_val = double(),
    cycle_size = double(),
    frequency = double(),
    key = character(),
    id = character()
  )

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  with_harmonic <- rec %>% step_harmonic(hp, frequency = 1 / 11, cycle_size = 1)
  expect_snapshot(print(with_harmonic))
  expect_snapshot(prep(with_harmonic))
})

test_that("empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_harmonic(rec, frequency = 1 / 11, cycle_size = 1)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})
