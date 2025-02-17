#' Impute nominal data using the most common value
#'
#'   `step_impute_mode` creates a *specification* of a
#'  recipe step that will substitute missing values of nominal
#'  variables by the training set mode of those variables.
#'
#' @inheritParams step_center
#' @param modes A named character vector of modes. This is
#'  `NULL` until computed by [prep()].
#' @param ptype A data frame prototype to cast new data sets to. This is
#'  commonly a 0-row slice of the training set.
#' @template step-return
#' @family imputation steps
#' @export
#' @details `step_impute_mode` estimates the variable modes
#'  from the data used in the `training` argument of
#'  `prep.recipe`. `bake.recipe` then applies the new
#'  values to new data sets using these values. If the training set
#'  data has more than one mode, one is selected at random.
#'
#'  As of `recipes` 0.1.16, this function name changed from `step_modeimpute()`
#'    to `step_impute_mode()`.
#'
#' # Tidying
#'
#' When you [`tidy()`][tidy.recipe()] this step, a tibble with columns
#' `terms` (the selectors or variables selected) and `model` (the mode
#' value) is returned.
#'
#' @template case-weights-unsupervised
#'
#' @examplesIf rlang::is_installed("modeldata")
#' data("credit_data", package = "modeldata")
#'
#' ## missing data per column
#' vapply(credit_data, function(x) mean(is.na(x)), c(num = 0))
#'
#' set.seed(342)
#' in_training <- sample(1:nrow(credit_data), 2000)
#'
#' credit_tr <- credit_data[in_training, ]
#' credit_te <- credit_data[-in_training, ]
#' missing_examples <- c(14, 394, 565)
#'
#' rec <- recipe(Price ~ ., data = credit_tr)
#'
#' impute_rec <- rec %>%
#'   step_impute_mode(Status, Home, Marital)
#'
#' imp_models <- prep(impute_rec, training = credit_tr)
#'
#' imputed_te <- bake(imp_models, new_data = credit_te, everything())
#'
#' table(credit_te$Home, imputed_te$Home, useNA = "always")
#'
#' tidy(impute_rec, number = 1)
#' tidy(imp_models, number = 1)
step_impute_mode <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           modes = NULL,
           ptype = NULL,
           skip = FALSE,
           id = rand_id("impute_mode")) {
    add_step(
      recipe,
      step_impute_mode_new(
        terms = enquos(...),
        role = role,
        trained = trained,
        modes = modes,
        ptype = ptype,
        skip = skip,
        id = id,
        case_weights = NULL
      )
    )
  }

#' @rdname step_impute_mode
#' @export
step_modeimpute <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           modes = NULL,
           ptype = NULL,
           skip = FALSE,
           id = rand_id("impute_mode")) {
    lifecycle::deprecate_stop(
      when = "0.1.16",
      what = "recipes::step_modeimpute()",
      with = "recipes::step_impute_mode()"
    )
    step_impute_mode(
      recipe,
      ...,
      role = role,
      trained = trained,
      modes = modes,
      ptype = ptype,
      skip = skip,
      id = id
    )
  }

step_impute_mode_new <-
  function(terms, role, trained, modes, ptype, skip, id, case_weights) {
    step(
      subclass = "impute_mode",
      terms = terms,
      role = role,
      trained = trained,
      modes = modes,
      ptype = ptype,
      skip = skip,
      id = id,
      case_weights = case_weights
    )
  }

#' @export
prep.step_impute_mode <- function(x, training, info = NULL, ...) {
  col_names <- recipes_eval_select(x$terms, training, info)

  wts <- get_case_weights(info, training)
  were_weights_used <- are_weights_used(wts, unsupervised = TRUE)
  if (isFALSE(were_weights_used)) {
    wts <- NULL
  }

  modes <- vapply(training[, col_names], mode_est, c(mode = ""), wts = wts)
  ptype <- vec_slice(training[, col_names], 0)
  step_impute_mode_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    modes = modes,
    ptype = ptype,
    skip = x$skip,
    id = x$id,
    case_weights = were_weights_used
  )
}

#' @export
#' @keywords internal
prep.step_modeimpute <- prep.step_impute_mode

#' @export
bake.step_impute_mode <- function(object, new_data, ...) {
  for (i in names(object$modes)) {
    if (any(is.na(new_data[, i]))) {
      if (is.null(object$ptype)) {
        rlang::warn(
          paste0(
            "'ptype' was added to `step_impute_mode()` after this recipe was created.\n",
            "Regenerate your recipe to avoid this warning."
          )
        )
      } else {
        new_data[[i]] <- vec_cast(new_data[[i]], object$ptype[[i]])
      }
      mode_val <- cast(object$modes[[i]], new_data[[i]])
      new_data[is.na(new_data[[i]]), i] <- mode_val
    }
  }
  new_data
}

#' @export
#' @keywords internal
bake.step_modeimpute <- bake.step_impute_mode

#' @export
print.step_impute_mode <-
  function(x, width = max(20, options()$width - 30), ...) {
    title <- "Mode imputation for "
    print_step(names(x$modes), x$terms, x$trained, title, width,
               case_weights = x$case_weights)
    invisible(x)
  }

#' @export
#' @keywords internal
print.step_modeimpute <- print.step_impute_mode

mode_est <- function(x, wts = NULL) {
  if (!is.character(x) & !is.factor(x))
    rlang::abort("The data should be character or factor to compute the mode.")
  tab <- weighted_table(x, wts = wts)
  modes <- names(tab)[tab == max(tab)]
  sample(modes, size = 1)
}

#' @rdname tidy.recipe
#' @export
tidy.step_impute_mode <- function(x, ...) {
  if (is_trained(x)) {
    res <- tibble(
      terms = names(x$modes),
      model = unname(x$modes)
    )
  } else {
    term_names <- sel2char(x$terms)
    res <- tibble(terms = term_names, model = na_chr)
  }
  res$id <- x$id
  res
}

#' @export
#' @keywords internal
tidy.step_modeimpute <- tidy.step_impute_mode
