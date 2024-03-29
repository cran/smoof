context("autoplot function")

test_that("autoplot functions for 1D numeric functions works as expected", {
	fn = makeSingleObjectiveFunction(
		name = "Test function",
		fn = function(x) sum(x^2),
		par.set = makeNumericParamSet("x", len = 1L, lower = -2, upper = 2),
    global.opt.value = 0,
    global.opt.param = 0
	)

	library(ggplot2)
	pl = autoplot(fn)
  plot(fn, show.optimum = TRUE, n.samples = 50L)
  checkGGPlot(pl, title = "Test function", "x", "y")

  pl = autoplot(fn, show.optimum = TRUE, n.samples = 50L)
  checkGGPlot(pl, title = "Test function", "x", "y")

  # Now check for wrapped functions
  fn = addCountingWrapper(fn)
  pl = autoplot(fn)
  checkGGPlot(pl, title = "Test function", "x", "y")
})

test_that("autoplot function for 2D numeric functions works as expected", {
	fn = makeSingleObjectiveFunction(
		name = "2d numeric",
		fn = function(x) x[[1]]^2 + sin(2 * x[[2]]),
		par.set = makeParamSet(
			makeNumericParam("x1", lower = -4, upper = 4),
			makeNumericParam("x2", lower = -4, upper = 4)
		)
	)

	library(ggplot2)
	# at least one of {levels, contours} must be TRUE
	expect_error(autoplot(fn, render.levels = FALSE, render.contours = FALSE))
	pl = autoplot(fn, render.levels = TRUE, render.contours = TRUE)

	for (render.levels in c(TRUE, FALSE)) {
		for (render.contours in c(TRUE, FALSE)) {
      # one of these parameter must be TRUE
			if (render.levels || render.contours) {
				pl = autoplot(fn, render.levels = render.levels, render.contours = render.contours)
        plot(fn, render.levels = render.levels, render.contours = render.contours,
          show.optimum = TRUE, n.samples = 50L)
				checkGGPlot(pl, title = getName(fn), "x1", "x2")
			}
		}
	}
})

test_that("autoplot does not work for certain functions", {
	fn1 = makeSingleObjectiveFunction(
		name = "Function with high dimension",
		fn = function(x) 1,
		par.set = makeNumericParamSet("x", len = 3L)
	)

	fn2 = makeSingleObjectiveFunction(
		name = "Function with unmatching parameters",
		fn = function(x) (as.character(x$disc1) == "a") + as.numeric(x$log1),
		has.simple.signature = FALSE,
		par.set = makeParamSet(
			makeDiscreteParam("disc1", values = letters[1:3]),
			makeLogicalParam("log1")
		)
	)

	library(ggplot2)
	expect_error(autoplot(fn1))
	# expect_error(autoplot(fn2))
})

test_that("autoplot functions for mixed functions (discrete/logical and numeric mixup)", {
	fn.name = "Modified Sphere function"
	fn = makeSingleObjectiveFunction(
		name = fn.name,
		fn = function(x) x$num1^2 + (as.character(x$disc1) == "a"),
		has.simple.signature = FALSE,
		par.set = makeParamSet(
			makeNumericParam("num1", lower = -2, upper = 2),
			makeDiscreteParam("disc1", values = c("a", "b"))
		)
	)

	library(ggplot2)
	pl = autoplot(fn)
  checkGGPlot(pl, title = fn.name, "num1", "y")
  checkGGFacets(pl, "disc1")

  fn = makeSingleObjectiveFunction(
    name = "2d numeric (vec), 2d discrete (vec)",
    fn = function(x) {
      if (x$disc[1] == "a") {
        (x$x[1]^2 + x$x[2]^2) + 10 * as.numeric(x$disc[2] == "a")
      } else {
        x$x[1] + x$x[2] - 10 * as.numeric(x$disc[2] == "a")
      }
    },
    par.set = makeParamSet(
      makeDiscreteVectorParam("disc", len = 2L, values = c("a", "b")),
      makeNumericVectorParam("x", len = 2L, lower = c(-5, -3), upper = c(5, 3))
    ),
    has.simple.signature = FALSE
  )
  pl = autoplot(fn, length.out = 40L)
  checkGGPlot(pl, title = getName(fn), "x1", "x2")
  checkGGFacets(pl, c("disc1", "disc2"))

  fn = makeSingleObjectiveFunction(
    name = "4d SOO function",
    fn = function(x) {
      if (x$disc1 == "a") {
        (x$x1^2 + x$x2^2) + 10 * as.numeric(x$logic)
      } else {
        x$x1 + x$x2 - 10 * as.numeric(x$logic)
      }
    },
    has.simple.signature = FALSE,
    par.set = makeParamSet(
      makeNumericParam("x1", lower = -5, upper = 5),
      makeNumericParam("x2", lower = -3, upper = 3),
      makeDiscreteParam("disc1", values = c("a", "b")),
      makeLogicalParam("logic")
    )
  )
  pl = autoplot(fn)
  checkGGPlot(pl, title = getName(fn), "x1", "x2")
  checkGGFacets(pl, c("disc1", "logic"))

  fn = makeSingleObjectiveFunction(
    name = "1d Real + 1d Int",
    fn = function(x) {
      x$x1 + x$x2
    },
    has.simple.signature = FALSE,
    par.set = makeParamSet(
      makeNumericParam("x1", lower = -5, upper = 5),
      makeIntegerParam("x2", lower = -3, upper = 3)
    )
  )
  pf = autoplot(fn)

})

test_that("3D plots work for two-dimensional funs", {
	fn = makeRastriginFunction(dimensions = 3L)
	expect_error(plot3D(fn, length.out = 10L))
	fn = makeRastriginFunction(dimensions = 2L)
	#FIXME: how to check for plot output of regular plots?
	expect_true(!is.null(plot3D(fn, length.out = 10L)))
})

test_that("Pareto-optimal front can be approximately visualized in 2D", {
	soo.fn = makeSphereFunction(dimensions = 3L)
	expect_error(visualizeParetoOptimalFront(soo.fn))
	moo.fn = makeZDT1Function(dimensions = 2L)
  pl = visualizeParetoOptimalFront(moo.fn)
	expect_is(pl, c("gg", "ggplot"))
	expect_true(grepl("ZDT1", pl$labels$title))
})
