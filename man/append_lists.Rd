% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/download_package.R
\name{append_lists}
\alias{append_lists}
\title{Append one list to another.}
\usage{
append_lists(list1, list2)
}
\arguments{
\item{list1}{(list) The list to append to.}

\item{list2}{(list) The list being appended.}
}
\description{
This function appends one list to another list. It can also be used to
prepend, just reverse the order of the lists.
}
\examples{
\dontrun{
appended_lists <- append_lists(list(1:3), list("a", "b", mean))
}

}
\author{
Dominic Mullen, \email{dmullen17@gmail.com}
}
