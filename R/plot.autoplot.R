#' @title
#' Generate ggplot2 object.
#'
#' @description
#' This function expects a smoof function and returns a ggplot object depicting
#' the function landscape. The output depends highly on the decision space of the
#' smoof function or more technically on the \code{\link[ParamHelpers]{ParamSet}}
#' of the function. The following destinctions regarding the parameter types are
#' made. In case of a single numeric parameter a simple line plot is drawn. For
#' two numeric parameters or a single numeric vector parameter of length 2 either a
#' contour plot or a heatmap (or a combination of both depending on the choice
#' of additional parameters) is depicted. If there are both up to two numeric
#' and at least one discrete vector parameter, ggplot facetting is used to
#' generate subplots of the above-mentioned types for all combinations of discrete
#' parameters.
#'
#' @note
#' Keep in mind, that the plots for mixed parameter spaces may be very large and
#' computationally expensive if the number of possible discrete parameter values
#' is large. I.e., if we have d discrete parameter with each n_1, n_2, ..., n_d
#' possible values we end up with n_1 x n_2 x ... x n_d subplots.
#'
#' @param object [\code{smoof_function}]\cr
#'   Objective function.
#' @param ... [any]\cr
#'   Not used.
#' @param show.optimum [\code{logical(1)}]\cr
#'   If the function has a known global optimum, should its location be
#'   plotted by a point or multiple points in case of multiple global optima?
#'   Default is \code{FALSE}.
#' @param main [\code{character(1L)}]\cr
#'   Plot title.
#'   Default is the name of the smoof function.
#' @param render.levels [\code{logical(1)}]\cr
#'   For 2D numeric functions only: Should an image map be plotted? Default is
#'   \code{FALSE}.
#' @param render.contours [\code{logical(1)}]\cr
#'   For 2D numeric functions only: Should contour lines be plotted? Default is
#'   \code{TRUE}.
#' @param log.scale [\code{logical(1)}]\cr
#'   Should the z-axis be plotted on log-scale?
#'   Default is \code{FALSE}.
#' @param length.out [\code{integer(1)}]\cr
#'   Desired length of the sequence of equidistant values generated for numeric parameters.
#'   Higher values lead to more smooth resolution in particular if \code{render.levels}
#'   is \code{TRUE}. Avoid using a very high value here especially if the function
#'   at hand has many parameters.
#'   Default is 50.
#' @return [\code{\link[ggplot2]{ggplot}}]
#' @examples
#' library(ggplot2)
#'
#' # Simple 2D contour plot with activated heatmap for the Himmelblau function
#' fn = makeHimmelblauFunction()
#' print(autoplot(fn))
#' print(autoplot(fn, render.levels = TRUE, render.contours = FALSE))
#' print(autoplot(fn, show.optimum = TRUE))
#'
#' # Now we create 4D function with a mixed decision space (two numeric, one discrete,
#' # and one logical parameter)
#' fn.mixed = makeSingleObjectiveFunction(
#'   name = "4d SOO function",
#'   fn = function(x) {
#'     if (x$disc1 == "a") {
#'       (x$x1^2 + x$x2^2) + 10 * as.numeric(x$logic)
#'     } else {
#'       x$x1 + x$x2 - 10 * as.numeric(x$logic)
#'     }
#'   },
#'   has.simple.signature = FALSE,
#'   par.set = makeParamSet(
#'     makeNumericParam("x1", lower = -5, upper = 5),
#'     makeNumericParam("x2", lower = -3, upper = 3),
#'     makeDiscreteParam("disc1", values = c("a", "b")),
#'     makeLogicalParam("logic")
#'   )
#' )
#' pl = autoplot(fn.mixed)
#' print(pl)
#'
#' # Since autoplot returns a ggplot object we can modify it, e.g., add a title
#' # or hide the legend
#' pl + ggtitle("My fancy function") + theme(legend.position = "none")
#' @export
autoplot.smoof_function = function(object,
  ...,
  show.optimum = FALSE,
  main = getName(x),
  render.levels = FALSE,
  render.contours = TRUE,
  log.scale = FALSE,
  length.out = 50L) {

  x = object
  checkPlotFunParams(x)

  assertFlag(show.optimum)
  assertString(main, na.ok = TRUE)
  length.out = convertInteger(length.out)
  assertInt(length.out, lower = 10L)
  assertFlag(render.levels)
  assertFlag(render.contours)
  assertFlag(log.scale)

  par.set = ParamHelpers::getParamSet(x)
  par.types = getParamTypes(par.set, df.cols = TRUE, with.nr = TRUE)
  par.types.count = getParamTypeCounts(par.set)
  par.names = getParamIds(par.set, with.nr = TRUE, repeated = TRUE)
  n.pars = length(par.names)

  # determine IDs of numeric and factor-like parameters
  numeric.idx = which(par.types %in% c("numeric", "integer"))
  discrete.idx = which(par.types %in% c("factor", "logical"))

  # how many numeric/discrete parameters do exist?
  n.numeric = length(numeric.idx)
  n.discrete = length(discrete.idx)

  if (n.pars > 6L) {
    stopf("At most 4D funtions with mixed parameter spaces can be visualized.")
  }

  if (par.types.count$numeric > 2L || (par.types.count$discrete + par.types.count$logical) > 4L) {
    stopf("Not possible to plot this combination of parameters.")
  }

  if (n.numeric > 1L && !(render.levels || render.contours)) {
    stopf("For functions with 2 numeric parameters one of render.levels or render.contours needs to be TRUE.")
  }

  grid = generateDataframeForGGPlot2(x, length.out)

  # log scale
  if (log.scale) {
    if (any(grid$y < 0)) {
      warning("Log-scale: Negative values occured. Shifting function to apply log transformation.")
      grid$y = grid$y - min(grid$y) + 1
    }
    grid$y = log(grid$y)
  }

  if (n.numeric == 1L) {
    pl = ggplot(grid, aes_string(x = par.names[numeric.idx], y = "y")) + geom_line()
  }
  if (n.numeric == 2L) {
    pl = ggplot(grid, aes_string(x = par.names[numeric.idx[1L]], y = par.names[numeric.idx[2L]]))
    if (render.levels) {

      if (!requireNamespace("RColorBrewer", quietly = TRUE))
        stopf("For render.levels=TRUE the package \"RColorBrewer\" is required.")
      # nice color palette for render.levels
      # see http://learnr.wordpress.com/2009/07/20/ggplot2-version-of-figures-in-lattice-multivariate-data-visualization-with-r-part-6/
      brewer.div = colorRampPalette(RColorBrewer::brewer.pal(11, "Spectral"), interpolate = "spline")

      pl = pl + geom_raster(aes_string(fill = "y"))
      pl = pl + scale_fill_gradientn(colours = brewer.div(200))
    }
    if (render.contours) {
      pl = pl + stat_contour(aes_string(z = "y"), colour = "gray", alpha = 0.8)
    }
  }

  # split with facets if discrete values exist
  if (n.discrete > 0L) {
    if (n.discrete == 1L) {
      formula = as.formula(sprintf(". ~ %s", par.names[discrete.idx]))
    } else if (n.discrete == 2L) {
      formula = as.formula(sprintf("%s ~ %s", par.names[discrete.idx[1L]], par.names[discrete.idx[2L]]))
    } else if (n.discrete == 3L) {
      formula = as.formula(sprintf("%s ~ %s + %s", par.names[discrete.idx[1L]], par.names[discrete.idx[2L]], par.names[discrete.idx[3L]]))
    } else if (n.discrete == 4L) {
      formula = as.formula(sprintf("%s + %s ~ %s + %s", par.names[discrete.idx[1L]], par.names[discrete.idx[2L]], par.names[discrete.idx[3L]], par.names[discrete.idx[4L]]))
    }

    # add labeller (otherwise we only see the values but the user has no clue
    # about which values belong to which parameter)
    pl = pl + facet_grid(formula, labeller = labeller(.rows = label_both, .cols = label_both))
  }

  if (show.optimum && (hasGlobalOptimum(x) || hasLocalOptimum(x))) {
    # get optima coordinates in a nice data.frame
    opt.df = getOptimaDf(x)
    if (n.numeric == 1L) {
      pl = pl + geom_point(opt.df, mapping = aes_string(x = par.names[numeric.idx[1L]], y = "y", colour = "optima", shape = "optima"))
    } else {
      pl = pl + geom_point(opt.df, mapping = aes_string(x = par.names[numeric.idx[1L]], y = par.names[numeric.idx[2L]], colour = "optima", shape = "optima"))
      # opt.df$y = round(opt.df$y, digits = 2L)
      # pl = pl + geom_text(opt.df, mapping = aes_string(x = par.names[numeric.idx[1L]], y = par.names[numeric.idx[2L]], label = "y"))
    }
  }

  # add title
  title = coalesce(main, getName(x))
  pl = pl + ggtitle(title)

  # cosmetic stuff
  pl = pl + theme(legend.position = "top")

  return(pl)
}

#' @export
autoplot.smoof_wrapped_function = function(object,
  ...,
  show.optimum = FALSE,
  main = getName(object),
  render.levels = FALSE,
  render.contours = TRUE,
  log.scale = FALSE,
  length.out = 50L) {
  autoplot(
    getWrappedFunction(object),
    ...,
    show.optimum = show.optimum,
    main = main,
    render.levels = render.levels,
    render.contours = render.contours,
    log.scale = log.scale,
    length.out = length.out)
}
