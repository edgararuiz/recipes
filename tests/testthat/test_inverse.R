library(testthat)
library(recipes)
library(tibble)

n <- 20
set.seed(1)
ex_dat <- data.frame(
  x1 = exp(rnorm(n, mean = .1)),
  x2 = 1 / abs(rnorm(n)),
  x3 = rep(1:2, each = n / 2),
  x4 = rexp(n),
  x5 = rep(0:1, each = n / 2)
)

test_that("simple inverse trans", {
  rec <- recipe(~ x1 + x2 + x3 + x4, data = ex_dat) %>%
    step_inverse(x1, x2, x3, x4)

  rec_trained <- prep(rec, training = ex_dat, verbose = FALSE)
  rec_trans <- bake(rec_trained, new_data = ex_dat)

  exp_res <- as_tibble(lapply(ex_dat[, -5], function(x) 1 / x))

  expect_equal(rec_trans, exp_res)
})

test_that("alt offset", {
  rec <- recipe(~., data = ex_dat) %>%
    step_inverse(x1, x2, x3, x4, x5, offset = 0.1)

  rec_trained <- prep(rec, training = ex_dat, verbose = FALSE)
  rec_trans <- bake(rec_trained, new_data = ex_dat)

  exp_res <- as_tibble(lapply(ex_dat, function(x) 1 / (x + 0.1)))

  expect_equal(rec_trans, exp_res)
})

test_that("printing", {
  rec <- recipe(~., data = ex_dat) %>%
    step_inverse(x1, x2, x3, x4)
  expect_snapshot(print(rec))
  expect_snapshot(prep(rec))
})

test_that("empty selection prep/bake is a no-op", {
  rec1 <- recipe(mpg ~ ., mtcars)
  rec2 <- step_inverse(rec1)

  rec1 <- prep(rec1, mtcars)
  rec2 <- prep(rec2, mtcars)

  baked1 <- bake(rec1, mtcars)
  baked2 <- bake(rec2, mtcars)

  expect_identical(baked1, baked2)
})

test_that("empty selection tidy method works", {
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_inverse(rec)

  expect <- tibble(
    terms = character(),
    id = character()
  )

  expect_identical(tidy(rec, number = 1), expect)

  rec <- prep(rec, mtcars)

  expect_identical(tidy(rec, number = 1), expect)
})

test_that("empty printing", {
  skip_if(packageVersion("rlang") < "1.0.0")
  rec <- recipe(mpg ~ ., mtcars)
  rec <- step_inverse(rec)

  expect_snapshot(rec)

  rec <- prep(rec, mtcars)

  expect_snapshot(rec)
})
