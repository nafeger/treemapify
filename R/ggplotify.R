#' @title Draw an exploratory treemap
#' @export
#' @family treemapify
#'
#' @description
#'
#' Takes a data frame of treemap coordinates produced by "treemapify" and
#' draws an exploratory treemap.  The output is a ggplot2 plot, so it can
#' be further manipulated e.g. a title added.
#'
#' @param treeMap a data frame of treemap coordinates produced by
#' "treemapify"
#' @param label.colour colour for individual rect labels; defaults to white
#' @param label.size.factor scaling factor for text size of individual
#' rect labels; defaults to 1
#' @param label.size.threshold (optional) minimum text size for individual
#' rect labels. Labels smaller than this threshold will not be displayed
#' @param label.size.fixed (optional) fixed size for individual rect
#' labels. Overrides label.size.factor
#' @param label.groups should groups be labeled? (Individual observations
#' will be automatically labelled if a "label" parameter was passed to
#' "treemapify")
#' @param group.label.colour colour for group labels; defaults to darkgrey
#' @param group.label.size.factor scaling factor for text size of group
#' labels; defaults to 1
#' @param group.label.size.threshold (optional) minimum text size for
#' group labels. Labels smaller than this threshold will not be displayed
#' @param group.label.size.fixed (optional) fixed size for group labels.
#' Overrides group.label.size.factor

ggplotify <- function(
  treeMap,
  label.colour = "white",
  label.size.factor = 1,
  label.size.threshold = NULL,
  label.size.fixed = NULL,
  label.groups = TRUE,
  group.label.colour = "darkgrey",
  group.label.size.factor = 1,
  group.label.size.threshold = NULL,
  group.label.size.fixed = NULL
) {

  # Required to get rid of check-notes
  fill <- group <- label <- labelx <- labely <- labelsize <- alpha <- NULL

  # Check arguments
  if (missing(treeMap) || is.data.frame(treeMap) == FALSE) {
    stop("Must provide a data frame")
  }
  if (! missing(label.size.fixed) && ! missing(label.size.factor)) {
    warning("label.sized.fixed overriding label.size.factor")
    label.size.factor <- 1
  }
  if (! missing(group.label.size.fixed) && ! missing(
    group.label.size.factor
  )) {
    warning("group.label.sized.fixed overriding group.label.size.factor")
    group.label.size.factor <- 1
  }

  # Determine limits of plot area (usually 100x100)
  xlim <- c(min(treeMap["xmin"]), max(treeMap["xmax"]))
  ylim <- c(min(treeMap["ymin"]), max(treeMap["ymax"]))

  # Set up plot area
  Plot <- ggplot(treeMap)
  Plot <- Plot + coord_cartesian(xlim = xlim, ylim = ylim)

  # Add rects generated by treemapify
  Plot <- Plot + geom_rect(aes(
    xmin = xmin,
    xmax = xmax,
    ymin = ymin,
    ymax = ymax,
    fill = fill
  ))

  # Add borders for individual rects
  Plot <- Plot + geom_rect(aes(
    xmin = xmin,
    xmax = xmax,
    ymin = ymin,
    ymax = ymax
  ), fill = NA, colour = "grey", size = 0.2)

  # Blank out extraneous plot elements
  Plot <- Plot + theme(
    axis.ticks = element_blank(),
    axis.title = element_blank(),
    axis.text = element_blank()
  )

  # Draw legend
  Plot <- Plot + guides(
    fill = guide_legend(title = attributes(treeMap)$fillName)
  )

  # If the rects are grouped, add a nice border around each group
  if ("group" %in% colnames(treeMap)) {

    # Determine x and y extents for each group
    groupRects <- ddply(
      treeMap,
      .(group),
      summarise,
      xmin <- min(xmin),
      xmax <- max(xmax),
      ymin <- min(ymin),
      ymax <- max(ymax)
    )
    names(groupRects) <- c("group", "xmin", "xmax", "ymin", "ymax")

    # Add borders to plot
    Plot <- Plot + geom_rect(
      data = groupRects,
      mapping = aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
      colour = "grey",
      fill = NA,
      size = 1.2
    )
    Plot <- Plot + theme(
      panel.border = element_rect(size = 2, fill = NA, colour = "grey")
    )
  }

  # Add group labels, if asked to
  if (label.groups == TRUE && "group" %in% colnames(treeMap)) {

    # If there's a "label" column (i.e. if individual rects are to be
    # labelled), place in the top left hand corner so the individual and
    # group labels don't overlap
    if ("label" %in% colnames(treeMap)) {
      groupLabels <- ddply(
        treeMap,
        c("group"),
        summarise,
        x = max(xmax) - ((max(xmax) - min(xmin)) * 0.5),
        y = min(ymin) + 2,
        size = (max(xmax) - min(xmin)) / nchar(as.character(group[1]))
      )

      # Otherwise, place in the middle
    } else {
      groupLabels <- ddply(
        treeMap,
        c("group"),
        summarise,
        x = max(xmax) - ((max(xmax) - min(xmin)) * 0.5),
        y = max(ymax) - ((max(ymax) - min(ymin)) * 0.5),
        size = (max(xmax) - min(xmin)) / nchar(as.character(group[1]))
      )
    }

    # Adjust group label text size by scaling factor
    groupLabels$size <- groupLabels$size * group.label.size.factor

    # Override group label text sizes with fixed size, if specified
    if (! missing(group.label.size.fixed)) {
      groupLabels$size <- rep(group.label.size.fixed, nrow(groupLabels))
    }

    # If a minimum group label size has been specified, hide labels smaller
    # than the threshold size
    if (! missing(group.label.size.threshold)) {
      groupLabels$alpha <- ifelse(
        groupLabels$size <group.label.size.threshold,
        0,
        1
      )

    } else {
      groupLabels$alpha <- rep(1, nrow(groupLabels))
    }

    # Add group labels to plot
    Plot <- Plot + annotate(
      "text",
      x = groupLabels$x,
      y = groupLabels$y,
      label = groupLabels$group,
      size = groupLabels$size,
      colour = group.label.colour,
      alpha = groupLabels$alpha,
      fontface = "bold",
      hjust = 0.5,
      vjust = 0,
      show_guide = FALSE
    )
  }

  # Add labels for individual rects, if they are present
  if ("label" %in% colnames(treeMap)) {

    # Determine label size and placement
    treeMap <- ddply(
      treeMap,
      "label",
      mutate,
      # Place in top left
      labelx = xmin + 1,
      labely = ymax - 1,
      # Rough scaling of label size
      labelsize = (xmax - xmin) / (nchar(as.character(label)))
    )

    # Override size with fixed size, if specified
    if (! missing(label.size.fixed)) {
      treeMap$labelsize <- rep(label.size.fixed, nrow(treeMap))
    }

    # If a minimum label size has been specified, hide labels smaller than
    # the threshold size
    if (! missing(label.size.threshold)) {
      treeMap$alpha <- ifelse(
        treeMap$labelsize * label.size.factor < label.size.threshold,
        0,
        1
      )

    } else {
      treeMap$alpha <- rep(1, nrow(treeMap))
    }

    # Add labels
    Plot <- Plot + geom_text(data = treeMap, aes(
      label = label,
      x = labelx,
      y = labely,
      size = labelsize,
      alpha = alpha
    ), hjust = 0, vjust = 1, colour = label.colour, show_guide = FALSE)

    # Scale labels, unless label.size.fixed was specified
    if (missing(label.size.fixed)) {
      Plot <- Plot + scale_size(
        range = c(1,8) * label.size.factor,
        guide = FALSE
      )
    } else {
      Plot <- Plot + scale_size(
        range = c(1, label.size.fixed),
        guide = FALSE
      )
    }
  }

  return(Plot)
}
