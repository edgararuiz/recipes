library(testthat)
library(recipes)
library(dplyr)
library(lubridate)


set.seed(145)
example_data <-
  data.frame(
    day = ymd("2012-06-07") + days(1:12),
    x1 = round(runif(12), 2),
    x2 = round(runif(12), 2),
    x3 = round(runif(12), 2)
  )
example_data$x1[c(1, 5, 6)] <- NA
example_data$x2[c(1:4, 10)] <- NA
example_data <- as_tibble(example_data)

test_that("imputation values with 7-pt median", {
  seven_pt <- recipe(~., data = example_data) %>%
    update_role(day, new_role = "time_index") %>%
    step_impute_roll(all_predictors(), window = 7, id = "") %>%
    prep(training = example_data)

  seven_pt_exp <- example_data
  seven_pt_exp$x1[1] <- median(seven_pt_exp$x1[1:7], na.rm = TRUE)
  seven_pt_exp$x1[5] <- median(seven_pt_exp$x1[2:8], na.rm = TRUE)
  seven_pt_exp$x1[6] <- median(seven_pt_exp$x1[3:9], na.rm = TRUE)
  seven_pt_exp$x2[1] <- median(seven_pt_exp$x2[1:7], na.rm = TRUE)
  seven_pt_exp$x2[2] <- median(seven_pt_exp$x2[1:7], na.rm = TRUE)
  seven_pt_exp$x2[3] <- median(seven_pt_exp$x2[1:7], na.rm = TRUE)
  seven_pt_exp$x2[4] <- median(seven_pt_exp$x2[1:7], na.rm = TRUE)
  seven_pt_exp$x2[10] <- median(seven_pt_exp$x2[6:12], na.rm = TRUE)

  expect_equal(seven_pt_exp, juice(seven_pt))

  seven_pt_tidy_tr <-
    tibble(
      terms = paste0("x", 1:3),
      window = rep(7L, 3),
      id = ""
    )
  expect_equal(seven_pt_tidy_tr, tidy(seven_pt, number = 1))
})

test_that("imputation values with 3-pt mean", {
  three_pt <- recipe(~., data = example_data) %>%
    update_role(day, new_role = "time_index") %>%
    step_impute_roll(all_predictors(), window = 3, id = "") %>%
    prep(training = example_data)


  three_pt_exp <- example_data
  three_pt_exp$x1[1] <- mean(three_pt_exp$x1[1:3], na.rm = TRUE)
  three_pt_exp$x1[5] <- mean(three_pt_exp$x1[4:6], na.rm = TRUE)
  three_pt_exp$x1[6] <- mean(example_data$x1[5:7], na.rm = TRUE)
  three_pt_exp$x2[1] <- NA
  three_pt_exp$x2[2] <- NA
  three_pt_exp$x2[3] <- NA
  three_pt_exp$x2[4] <- mean(three_pt_exp$x2[3:5], na.rm = TRUE)
  three_pt_exp$x2[10] <- mean(three_pt_exp$x2[9:11], na.rm = TRUE)

  expect_equal(three_pt_exp, juice(three_pt))

  three_pt_tidy_tr <-
    tibble(
      terms = paste0("x", 1:3),
      window = rep(3L, 3),
      id = ""
    )
  expect_equal(three_pt_tidy_tr, tidy(three_pt, number = 1))
})


test_that("bad args", {
  expect_snapshot(error = TRUE,
    recipe(~., data = example_data) %>%
      step_impute_roll(all_predictors(), window = 3) %>%
      prep(training = example_data)
  )

  expect_snapshot(error = TRUE,
    recipe(~., data = example_data) %>%
      update_role(day, new_role = "time_index") %>%
      step_impute_roll(all_predictors(), window = 4) %>%
      prep(training = example_data)
  )

  example_data$x4 <- 1:12
  expect_snapshot(error = TRUE,
    recipe(~., data = example_data) %>%
      update_role(day, new_role = "time_index") %>%
      step_impute_roll(all_predictors(), window = 3) %>%
      prep(training = example_data)
  )
})



test_that("printing", {
  seven_pt <- recipe(~., data = example_data) %>%
    update_role(day, new_role = "time_index") %>%
    step_impute_roll(all_predictors(), window = 7)
  expect_snapshot(print(seven_pt))
  expect_snapshot(prep(seven_pt))
})


test_that("tunable", {
  rec <-
    recipe(~., data = iris) %>%
    step_impute_roll(all_predictors(), outcome = "Species")
  rec_param <- tunable.step_impute_roll(rec$steps[[1]])
  expect_equal(rec_param$name, c("statistic", "window"))
  expect_true(all(rec_param$source == "recipe"))
  expect_true(is.list(rec_param$call_info))
  expect_equal(nrow(rec_param), 2)
  expect_equal(
    names(rec_param),
    c("name", "call_info", "source", "component", "component_id")
  )
})

test_that("empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_impute_roll(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_impute_roll(rec)

  expect <- tibble(terms = character(), window = integer(), id = character())

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_impute_roll(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})
