library(testthat)
library(recipes)
skip_if_not_installed("modeldata")
data(biomass, package = "modeldata")

biomass_tr <- biomass[1:10, ]
biomass_te <- biomass[c(13:14, 19, 522), ]

rec <- recipe(HHV ~ carbon + hydrogen,
  data = biomass_tr
)

test_that("correct values", {
  standardized <- rec %>%
    step_range(carbon, hydrogen, min = -12, id = "")

  standardized_trained <- prep(standardized, training = biomass_tr, verbose = FALSE)

  obs_pred <- bake(standardized_trained, new_data = biomass_te, all_predictors())
  obs_pred <- as.matrix(obs_pred)

  mins <- apply(biomass_tr[, c("carbon", "hydrogen")], 2, min)
  maxs <- apply(biomass_tr[, c("carbon", "hydrogen")], 2, max)

  new_min <- -12
  new_max <- 1
  new_range <- new_max - new_min

  carb <- ((new_range * (biomass_te$carbon - mins["carbon"])) /
    (maxs["carbon"] - mins["carbon"])) + new_min
  carb <- ifelse(carb > new_max, new_max, carb)
  carb <- ifelse(carb < new_min, new_min, carb)

  hydro <- ((new_range * (biomass_te$hydrogen - mins["hydrogen"])) /
    (maxs["hydrogen"] - mins["hydrogen"])) + new_min
  hydro <- ifelse(hydro > new_max, new_max, hydro)
  hydro <- ifelse(hydro < new_min, new_min, hydro)

  exp_pred <- cbind(carb, hydro)
  colnames(exp_pred) <- c("carbon", "hydrogen")
  expect_equal(exp_pred, obs_pred)

  rng_tibble_un <-
    tibble(
      terms = c("carbon", "hydrogen"),
      min = rep(NA_real_, 2),
      max = rep(NA_real_, 2),
      id = ""
    )
  rng_tibble_tr <-
    tibble(
      terms = c("carbon", "hydrogen"),
      min = unname(mins),
      max = unname(maxs),
      id = ""
    )

  expect_equal(tidy(standardized, 1), rng_tibble_un)
  expect_equal(tidy(standardized_trained, 1), rng_tibble_tr)
})


test_that("defaults", {
  standardized <- rec %>%
    step_range(carbon, hydrogen)

  standardized_trained <- prep(standardized, training = biomass_tr, verbose = FALSE)

  obs_pred <- bake(standardized_trained, new_data = biomass_te, all_predictors())
  obs_pred <- as.matrix(obs_pred)

  mins <- apply(biomass_tr[, c("carbon", "hydrogen")], 2, min)
  maxs <- apply(biomass_tr[, c("carbon", "hydrogen")], 2, max)

  new_min <- 0
  new_max <- 1
  new_range <- new_max - new_min

  carb <- ((new_range * (biomass_te$carbon - mins["carbon"])) /
    (maxs["carbon"] - mins["carbon"])) + new_min
  carb <- ifelse(carb > new_max, new_max, carb)
  carb <- ifelse(carb < new_min, new_min, carb)

  hydro <- ((new_range * (biomass_te$hydrogen - mins["hydrogen"])) /
    (maxs["hydrogen"] - mins["hydrogen"])) + new_min
  hydro <- ifelse(hydro > new_max, new_max, hydro)
  hydro <- ifelse(hydro < new_min, new_min, hydro)

  exp_pred <- cbind(carb, hydro)
  colnames(exp_pred) <- c("carbon", "hydrogen")
  expect_equal(exp_pred, obs_pred)
})


test_that("one variable", {
  standardized <- rec %>%
    step_range(carbon)

  standardized_trained <- prep(standardized, training = biomass_tr, verbose = FALSE)

  obs_pred <- bake(standardized_trained, new_data = biomass_te)

  mins <- min(biomass_tr$carbon)
  maxs <- max(biomass_tr$carbon)

  new_min <- 0
  new_max <- 1
  new_range <- new_max - new_min

  carb <- ((new_range * (biomass_te$carbon - mins)) /
    (maxs - mins)) + new_min
  carb <- ifelse(carb > new_max, new_max, carb)
  carb <- ifelse(carb < new_min, new_min, carb)

  expect_equal(carb, obs_pred$carbon)
})


test_that("printing", {
  standardized <- rec %>%
    step_range(carbon, hydrogen, min = -12)
  expect_snapshot(print(standardized))
  expect_snapshot(prep(standardized))
})

test_that("empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_range(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_range(rec)

  expect <- tibble(terms = character(), min = double(), max = double(), id = character())

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_range(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})
