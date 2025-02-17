library(testthat)
library(recipes)
library(dplyr)

skip_if_not_installed("modeldata")
data(biomass, package = "modeldata")

biomass$carbon <- ifelse(biomass$carbon > 40, biomass$carbon, 40)
biomass$hydrogen <- ifelse(biomass$hydrogen > 5, biomass$carbon, 5)
biomass$has_neg <- runif(nrow(biomass), min = -2)

rec <- recipe(HHV ~ carbon + hydrogen + has_neg,
  data = biomass
)

biomass_tr <- biomass[biomass$dataset == "Training", ]
biomass_te <- biomass[biomass$dataset == "Testing", ]


test_that("basic usage", {
  rec1 <- rec %>%
    step_impute_lower(carbon, hydrogen, id = "")

  untrained <- tibble(
    terms = c("carbon", "hydrogen"),
    value = rep(NA_real_, 2),
    id = ""
  )

  expect_equal(untrained, tidy(rec1, number = 1))

  rec1 <- prep(rec1, biomass_tr)

  trained <- tibble(
    terms = c("carbon", "hydrogen"),
    value = c(40, 5),
    id = ""
  )

  expect_equal(trained, tidy(rec1, number = 1))

  expect_equal(
    c(carbon = 40, hydrogen = 5),
    rec1$steps[[1]]$threshold
  )

  processed <- juice(rec1)
  for (i in names(rec1$steps[[1]]$threshold)) {
    affected <- biomass_tr[[i]] <= rec1$steps[[1]]$threshold[[i]]
    is_less <- processed[affected, i] < biomass_tr[affected, i]
    is_pos <- processed[affected, i] > 0
    expect_true(all(is_less))
    expect_true(all(is_pos))
  }
})

test_that("bad data", {
  expect_snapshot(error = TRUE,
    rec %>%
      step_impute_lower(carbon, hydrogen, has_neg) %>%
      prep()
  )
})

test_that("printing", {
  rec2 <- rec %>%
    step_impute_lower(carbon, hydrogen)

  expect_snapshot(print(rec))
  expect_snapshot(prep(rec2))
})

test_that("empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_impute_lower(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_impute_lower(rec)

  expect <- tibble(terms = character(), value = double(), id = character())

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_impute_lower(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})
