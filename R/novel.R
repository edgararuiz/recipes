#' Simple Value Assignments for Novel Factor Levels
#'
#' `step_novel` creates a *specification* of a recipe
#'  step that will assign a previously unseen factor level to a
#'  new value.
#'
#' @inheritParams step_center
#' @param new_level A single character value that will be assigned
#'  to new factor levels.
#' @param objects A list of objects that contain the information
#'  on factor levels that will be determined by [prep()].
#' @template step-return
#' @family dummy variable and encoding steps
#' @seealso [dummy_names()]
#' @export
#' @details The selected variables are adjusted to have a new
#'  level (given by `new_level`) that is placed in the last
#'  position. During preparation there will be no data points
#'  associated with this new level since all of the data have been
#'  seen.
#'
#' Note that if the original columns are character, they will be
#'  converted to factors by this step.
#'
#' Missing values will remain missing.
#'
#' If `new_level` is already in the data given to `prep`, an error
#'  is thrown.
#'
#' When fitting a model that can deal with new factor levels, consider using
#'  [workflows::add_recipe()] with `allow_novel_levels = TRUE` set in
#'  [hardhat::default_recipe_blueprint()]. This will allow your model to handle
#'  new levels at prediction time, instead of throwing warnings or errors.
#'
#' # Tidying
#'
#' When you [`tidy()`][tidy.recipe()] this step, a tibble with columns
#' `terms` (the columns that will be affected) and `value` (the factor
#' levels that is used for the new value) is returned.
#'
#' @template case-weights-not-supported
#'
#' @examplesIf rlang::is_installed("modeldata")
#' data(Sacramento, package = "modeldata")
#'
#' sacr_tr <- Sacramento[1:800, ]
#' sacr_te <- Sacramento[801:806, ]
#' sacr_te$city[3] <- "beeptown"
#' sacr_te$city[4] <- "boopville"
#'
#' rec <- recipe(~ city + zip, data = sacr_tr)
#'
#' rec <- rec %>%
#'   step_novel(city, zip)
#' rec <- prep(rec, training = sacr_tr)
#'
#' processed <- bake(rec, sacr_te)
#' tibble(old = sacr_te$city, new = processed$city)
#'
#' tidy(rec, number = 1)
step_novel <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           new_level = "new",
           objects = NULL,
           skip = FALSE,
           id = rand_id("novel")) {
    add_step(
      recipe,
      step_novel_new(
        terms = enquos(...),
        role = role,
        trained = trained,
        new_level = new_level,
        objects = objects,
        skip = skip,
        id = id
      )
    )
  }

step_novel_new <-
  function(terms, role, trained, new_level, objects, skip, id) {
    step(
      subclass = "novel",
      terms = terms,
      role = role,
      trained = trained,
      new_level = new_level,
      objects = objects,
      skip = skip,
      id = id
    )
  }

get_existing_values <- function(x) {
  if (is.character(x)) {
    out <- unique(x)
    attr(out, "is_ordered") <- FALSE
  } else {
    if (is.factor(x)) {
      out <- levels(x)
      attr(out, "is_ordered") <- is.ordered(x)
    } else {
      rlang::abort("Data should be either character or factor")
    }
  }
  out
}

#' @export
prep.step_novel <- function(x, training, info = NULL, ...) {
  col_names <- recipes_eval_select(x$terms, training, info)

  col_check <- dplyr::filter(info, variable %in% col_names)

  if (any(col_check$type != "nominal")) {
    rlang::abort(
      paste0(
        "Columns must be character or factor: ",
        paste0(col_check$variable[col_check$type != "nominal"],
          collapse = ", "
        )
      )
    )
  }

  # Get existing levels and their factor type (i.e. ordered)
  objects <- lapply(training[, col_names], get_existing_values)
  # Check to make sure that there are not duplicate levels
  level_check <-
    map_lgl(objects, function(x, y) y %in% x, y = x$new_level)
  if (any(level_check)) {
    rlang::abort(
      paste0(
        "Columns already contain the new level: ",
        paste0(names(level_check)[level_check], collapse = ", ")
      )
    )
  }

  step_novel_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    new_level = x$new_level,
    objects = objects,
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_novel <- function(object, new_data, ...) {
  for (i in names(object$objects)) {
    new_data[[i]] <- ifelse(
      # Preserve NA values by adding them to the list of existing
      # possible values
      !(new_data[[i]] %in% c(object$object[[i]], NA)),
      object$new_level,
      as.character(new_data[[i]])
    )

    new_data[[i]] <-
      factor(new_data[[i]],
        levels = c(object$object[[i]], object$new_level),
        ordered = attributes(object$object[[i]])$is_ordered
      )
  }
  new_data
}

print.step_novel <-
  function(x, width = max(20, options()$width - 30), ...) {
    title <- "Novel factor level assignment for "
    print_step(names(x$objects), x$terms, x$trained, title, width)
    invisible(x)
  }

#' @rdname tidy.recipe
#' @export
tidy.step_novel <- function(x, ...) {
  if (is_trained(x)) {
    res <- tibble(
      terms = names(x$objects),
      value = rep(x$new_level, length(x$objects))
    )
  } else {
    term_names <- sel2char(x$terms)
    res <- tibble(
      terms = term_names,
      value = rep(x$new_level, length(term_names))
    )
  }
  res$id <- x$id
  res
}
