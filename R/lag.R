#' Create a lagged predictor
#'
#' `step_lag` creates a *specification* of a recipe step that
#'   will add new columns of lagged data. Lagged data will
#'   by default include NA values where the lag was induced.
#'   These can be removed with [step_naomit()], or you may
#'   specify an alternative filler value with the `default`
#'   argument.
#'
#' @inheritParams step_pca
#' @inheritParams step_center
#' @param lag A vector of positive integers. Each specified column will be
#'  lagged for each value in the vector.
#' @param prefix A prefix for generated column names, default to "lag_".
#' @param columns A character string of variable names that will
#'  be populated (eventually) by the `terms` argument.
#' @param default Passed to `dplyr::lag`, determines what fills empty rows
#'   left by lagging (defaults to NA).
#' @template step-return
#' @details The step assumes that the data are already _in the proper sequential
#'  order_ for lagging.
#'
#' @template case-weights-not-supported
#'
#' @family row operation steps
#' @export
#' @rdname step_lag
#'
#' @examples
#' n <- 10
#' start <- as.Date("1999/01/01")
#' end <- as.Date("1999/01/10")
#'
#' df <- data.frame(
#'   x = runif(n),
#'   index = 1:n,
#'   day = seq(start, end, by = "day")
#' )
#'
#' recipe(~., data = df) %>%
#'   step_lag(index, day, lag = 2:3) %>%
#'   prep(df) %>%
#'   bake(df)
step_lag <-
  function(recipe,
           ...,
           role = "predictor",
           trained = FALSE,
           lag = 1,
           prefix = "lag_",
           default = NA,
           columns = NULL,
           skip = FALSE,
           id = rand_id("lag")) {
    add_step(
      recipe,
      step_lag_new(
        terms = enquos(...),
        role = role,
        trained = trained,
        lag = lag,
        default = default,
        prefix = prefix,
        columns = columns,
        skip = skip,
        id = id
      )
    )
  }

step_lag_new <-
  function(terms, role, trained, lag, default, prefix, columns, skip, id) {
    step(
      subclass = "lag",
      terms = terms,
      role = role,
      trained = trained,
      lag = lag,
      default = default,
      prefix = prefix,
      columns = columns,
      skip = skip,
      id = id
    )
  }

#' @export
prep.step_lag <- function(x, training, info = NULL, ...) {
  step_lag_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    lag = x$lag,
    default = x$default,
    prefix = x$prefix,
    columns = recipes_eval_select(x$terms, training, info),
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_lag <- function(object, new_data, ...) {
  if (!all(object$lag == as.integer(object$lag))) {
    rlang::abort("step_lag requires 'lag' argument to be integer valued.")
  }

  make_call <- function(col, lag_val) {
    call2(
      "lag",
      x = sym(col),
      n = lag_val,
      default = object$default,
      .ns = "dplyr"
    )
  }

  grid <- tidyr::expand_grid(col = object$columns, lag_val = object$lag)
  calls <- purrr::map2(grid$col, grid$lag_val, make_call)
  newname <- as.character(glue::glue("{object$prefix}{grid$lag_val}_{grid$col}"))
  calls <- check_name(calls, new_data, object, newname, TRUE)

  new_data <- mutate(new_data, !!!calls)
  new_data
}

print.step_lag <-
  function(x, width = max(20, options()$width - 30), ...) {
    title <- "Lagging "
    print_step(x$columns, x$terms, x$trained, title, width)
    invisible(x)
  }
