library(testthat)
library(rlang)
library(recipes)

skip_if_not_installed("modeldata")
data(biomass, package = "modeldata")

means <- vapply(biomass[, 3:7], mean, c(mean = 0))
sds <- vapply(biomass[, 3:7], sd, c(sd = 0))

rec <- recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur,
  data = biomass
)

biomass['zero_variance'] <- 1
rec_zv <- recipe(HHV ~  + carbon + hydrogen + oxygen + nitrogen + sulfur + zero_variance,
data = biomass)


# Note: some tests convert to data frame prior to testing
# https://github.com/tidyverse/dplyr/issues/2751

test_that("correct means and std devs", {
  standardized <- rec %>%
    step_center(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "center") %>%
    step_scale(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "scale")

  cent_tibble_un <-
    tibble(
      terms = c("carbon", "hydrogen", "oxygen", "nitrogen", "sulfur"),
      value = rep(na_dbl, 5),
      id = standardized$steps[[1]]$id
    )
  scal_tibble_un <- cent_tibble_un
  scal_tibble_un$id <- standardized$steps[[2]]$id

  expect_equal(tidy(standardized, 1), cent_tibble_un)
  expect_equal(as.data.frame(tidy(standardized, 2)), as.data.frame(scal_tibble_un))

  standardized_trained <- prep(standardized, training = biomass)

  cent_tibble_tr <-
    tibble(
      terms = c("carbon", "hydrogen", "oxygen", "nitrogen", "sulfur"),
      value = unname(means),
      id = standardized$steps[[1]]$id
    )
  scal_tibble_tr <-
    tibble(
      terms = c("carbon", "hydrogen", "oxygen", "nitrogen", "sulfur"),
      value = sds,
      id = standardized$steps[[2]]$id
    )

  expect_equal(tidy(standardized_trained, 1), cent_tibble_tr)
  expect_equal(
    as.data.frame(tidy(standardized_trained, 2)),
    as.data.frame(scal_tibble_tr)
  )

  expect_equal(standardized_trained$steps[[1]]$means, means)
  expect_equal(standardized_trained$steps[[2]]$sds, sds)
})

test_that("scale by factor of 1 or 2", {
  standardized <- rec %>%
    step_scale(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "scale", factor = 2)

  standardized_trained <- prep(standardized, training = biomass)

  scal_tibble_tr <-
    tibble(
      terms = c("carbon", "hydrogen", "oxygen", "nitrogen", "sulfur"),
      value = unname(sds * 2),
      id = standardized$steps[[1]]$id
    )

  expect_equal(tidy(standardized_trained, 1), scal_tibble_tr)

  expect_equal(standardized_trained$steps[[1]]$sds, 2 * sds)

  expect_snapshot(
    not_recommended_standardized_input <- rec %>%
      step_scale(carbon, id = "scale", factor = 3) %>%
      prep(training = biomass)
  )
})

test_that("training in stages", {
  at_once <- rec %>%
    step_center(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "center") %>%
    step_scale(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "scale")

  at_once_trained <- prep(at_once, training = biomass)

  ## not train in stages
  center_first <- rec %>%
    step_center(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "center")
  center_first_trained <- prep(center_first, training = biomass)
  in_stages <- center_first_trained %>%
    step_scale(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "scale")
  in_stages_trained <- prep(in_stages)
  in_stages_retrained <-
    prep(in_stages, training = biomass, fresh = TRUE)

  expect_equal(at_once_trained, in_stages_trained, ignore_formula_env = TRUE)
  expect_equal(at_once_trained, in_stages_retrained, ignore_formula_env = TRUE)
})


test_that("single predictor", {
  standardized <- rec %>%
    step_center(carbon) %>%
    step_scale(hydrogen)

  standardized_trained <- prep(standardized, training = biomass)
  results <- bake(standardized_trained, biomass)

  exp_res <- biomass[, 3:8]
  exp_res$carbon <- exp_res$carbon - mean(exp_res$carbon)
  exp_res$hydrogen <- exp_res$hydrogen / sd(exp_res$hydrogen)

  expect_equal(as.data.frame(results), exp_res[, colnames(results)])
})


test_that("printing", {
  standardized <- rec %>%
    step_center(carbon) %>%
    step_scale(hydrogen) %>%
    step_normalize(nitrogen, carbon)
  expect_snapshot(print(standardized))
  expect_snapshot(prep(standardized))
})

test_that("correct means and std devs for step_norm", {
  standardized <- rec %>%
    step_normalize(carbon, hydrogen, oxygen, nitrogen, sulfur, id = "norm")

  vrs <- c("carbon", "hydrogen", "oxygen", "nitrogen", "sulfur")
  norm_tibble_un <-
    tibble(
      terms = vrs,
      statistic = rep(na_chr, 5),
      value = rep(na_dbl, 5),
      id = standardized$steps[[1]]$id
    )

  expect_equal(tidy(standardized, 1), norm_tibble_un)

  standardized_trained <- prep(standardized, training = biomass)

  norm_tibble_tr <-
    tibble(
      terms = c(vrs, vrs),
      statistic = rep(c("mean", "sd"), each = 5),
      value = unname(c(means, sds)),
      id = standardized$steps[[1]]$id
    )

  expect_equal(tidy(standardized_trained, 1), norm_tibble_tr)
})

test_that("step_normalize works with 1 column (#963)", {
  standardized <- rec %>%
    step_normalize(carbon, id = "norm")

  standardized_trained <- prep(standardized, training = biomass)

  norm_tibble_tr <-
    tibble(
      terms = c("carbon", "carbon"),
      statistic = c("mean", "sd"),
      value = unname(c(means[["carbon"]], sds[["carbon"]])),
      id = standardized$steps[[1]]$id
    )

  expect_equal(tidy(standardized_trained, 1), norm_tibble_tr)
})

test_that("na_rm argument works for step_scale", {
  mtcars_na <- mtcars
  mtcars_na[1, 1:4] <- NA

  rec_no_na_rm <- recipe(~., data = mtcars_na) %>%
    step_scale(all_predictors(), na_rm = FALSE) %>%
    prep()

  rec_na_rm <- recipe(~., data = mtcars_na) %>%
    step_scale(all_predictors(), na_rm = TRUE) %>%
    prep()

  exp_no_na_rm <- vapply(mtcars_na, FUN = sd, FUN.VALUE = numeric(1))
  exp_na_rm <- vapply(mtcars_na, FUN = sd, FUN.VALUE = numeric(1), na.rm = TRUE)

  expect_equal(
    tidy(rec_no_na_rm, 1)$value,
    unname(exp_no_na_rm)
  )

  expect_equal(
    tidy(rec_na_rm, 1)$value,
    unname(exp_na_rm)
  )
})

test_that("na_rm argument works for step_center", {
  mtcars_na <- mtcars
  mtcars_na[1, 1:4] <- NA

  rec_no_na_rm <- recipe(~., data = mtcars_na) %>%
    step_center(all_predictors(), na_rm = FALSE) %>%
    prep()

  rec_na_rm <- recipe(~., data = mtcars_na) %>%
    step_center(all_predictors(), na_rm = TRUE) %>%
    prep()

  exp_no_na_rm <- vapply(mtcars_na, FUN = mean, FUN.VALUE = numeric(1))
  exp_na_rm <- vapply(mtcars_na, FUN = mean, FUN.VALUE = numeric(1), na.rm = TRUE)

  expect_equal(
    tidy(rec_no_na_rm, 1)$value,
    unname(exp_no_na_rm)
  )

  expect_equal(
    tidy(rec_na_rm, 1)$value,
    unname(exp_na_rm)
  )
})

test_that("na_rm argument works for step_normalize", {
  mtcars_na <- mtcars
  mtcars_na[1, 1:4] <- NA

  rec_no_na_rm <- recipe(~., data = mtcars_na) %>%
    step_normalize(all_predictors(), na_rm = FALSE) %>%
    prep()

  rec_na_rm <- recipe(~., data = mtcars_na) %>%
    step_normalize(all_predictors(), na_rm = TRUE) %>%
    prep()

  exp_no_na_rm <- c(
    vapply(mtcars_na, FUN = mean, FUN.VALUE = numeric(1)),
    vapply(mtcars_na, FUN = sd, FUN.VALUE = numeric(1))
  )
  exp_na_rm <- c(
    vapply(mtcars_na, FUN = mean, FUN.VALUE = numeric(1), na.rm = TRUE),
    vapply(mtcars_na, FUN = sd, FUN.VALUE = numeric(1), na.rm = TRUE)
  )

  expect_equal(
    tidy(rec_no_na_rm, 1)$value,
    unname(exp_no_na_rm)
  )

  expect_equal(
    tidy(rec_na_rm, 1)$value,
    unname(exp_na_rm)
  )
})

test_that("center - empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_center(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("center - empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_center(rec)

  expect_identical(
    tidy(rec, number = 1),
    tibble(terms = character(), value = double(), id = character())
  )

  rec <- prep(rec, mtcars)

  expect_identical(
    tidy(rec, number = 1),
    tibble(terms = character(), value = double(), id = character())
  )
})

test_that("center - empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_center(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})

test_that("scale - empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_scale(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("scale - empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_scale(rec)

  expect <- tibble(terms = character(), value = double(), id = character())

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("scale - empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_scale(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})

test_that("scale - warns on zv",{
  rec1 <- step_scale(rec_zv, all_numeric_predictors())
  expect_snapshot(prep(rec1))
})

test_that("normalize - empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_normalize(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("normalize - empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_normalize(rec)

  expect <- tibble(
    terms = character(),
    statistic = character(),
    value = double(),
    id = character()
  )

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("normalize - empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_normalize(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})

test_that("normalize - warns on zv",{
  rec1 <- step_normalize(rec_zv,all_numeric_predictors())
  expect_snapshot(prep(rec1))
})

test_that("centering with case weights", {
  mtcars_freq <- mtcars
  mtcars_freq$cyl <- frequency_weights(mtcars_freq$cyl)

  rec <-
    recipe(mpg ~ ., mtcars_freq) %>%
    step_center(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    tidy(rec, number = 1)[["value"]],
    unname(averages(mtcars_freq[, -c(1, 2)], mtcars_freq$cyl))
  )

  expect_snapshot(rec)

  mtcars_imp <- mtcars
  mtcars_imp$wt <- importance_weights(mtcars_imp$wt)

  rec <-
    recipe(mpg ~ ., mtcars_imp) %>%
    step_center(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    tidy(rec, number = 1)[["value"]],
    unname(averages(mtcars_imp[, -c(1, 6)], NULL))
  )

  expect_snapshot(rec)
})

test_that("scaling with case weights", {
  mtcars_freq <- mtcars
  mtcars_freq$cyl <- frequency_weights(mtcars_freq$cyl)

  rec <-
    recipe(mpg ~ ., mtcars_freq) %>%
    step_scale(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    tidy(rec, number = 1)[["value"]],
    unname(sqrt(variances(mtcars_freq[, -c(1, 2)], mtcars_freq$cyl)))
  )

  expect_snapshot(rec)

  mtcars_imp <- mtcars
  mtcars_imp$wt <- importance_weights(mtcars_imp$wt)

  rec <-
    recipe(mpg ~ ., mtcars_imp) %>%
    step_scale(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    tidy(rec, number = 1)[["value"]],
    unname(sqrt(variances(mtcars_imp[, -c(1, 6)], NULL)))
  )

  expect_snapshot(rec)
})

test_that("normalizing with case weights", {
  mtcars_freq <- mtcars
  mtcars_freq$cyl <- frequency_weights(mtcars_freq$cyl)

  rec <-
    recipe(mpg ~ ., mtcars_freq) %>%
    step_normalize(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    rec$steps[[1]]$means,
    averages(mtcars_freq[, -c(1, 2)], mtcars_freq$cyl)
  )

  expect_equal(
    rec$steps[[1]]$sds,
    sqrt(variances(mtcars_freq[, -c(1, 2)], mtcars_freq$cyl))
  )

  expect_snapshot(rec)

  mtcars_imp <- mtcars
  mtcars_imp$wt <- importance_weights(mtcars_imp$wt)

  rec <-
    recipe(mpg ~ ., mtcars_imp) %>%
    step_normalize(all_numeric_predictors()) %>%
    prep()

  expect_equal(
    rec$steps[[1]]$means,
    averages(mtcars_imp[, -c(1, 6)], NULL)
  )

  expect_equal(
    rec$steps[[1]]$sds,
    sqrt(variances(mtcars_imp[, -c(1, 6)], NULL))
  )

  expect_snapshot(rec)
})
