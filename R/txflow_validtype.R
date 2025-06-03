#' Utility function to assert if a data file or blob type is valid
#' 
#' @param x The type
#' 
#' @return Invisible logical 
#' 
#' @description
#' Asserts if `x` is a valid type reference.
#' 
#' A type is a character string 
#' \itemize{
#'   \item case insensitive
#'   \item containing the letters A-Z, digits 0-9 and punctuations period 
#'   `.` and underscore `_` 
#'   \item starts with a character or digit
#'   \item consist of at least 1 character and maximum of 64
#' }
#' 
#' `type` with prefix `custom:` is assumed a non-standard bespoke type.
#' 
#' Supported standard types are 
#' \itemize{
#'   \item `datafile`
#'   \item `datafile.sas`
#'   \item `datafile.rds`
#'   \item `datafile.rda` 
#'   \item `datafile.csv`
#'   \item `datafile.xlsx`
#'   \item `datafile.text`
#' }
#' 
#' 
#' 
#' @export


txflow_validtype <- function(x) {
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, c( "character", "numeric") ) ||
       (base::trimws(as.character(x)) == "" ) )
    return(invisible(FALSE))
  
  if ( ! grepl( "^(custom:)?[a-z0-9][a-z0-9\\-\\.]*$", base::trimws(as.character(x)), ignore.case = TRUE ) )
    return(FALSE)
  
  # -- bespoke
  if ( base::startsWith( base::tolower(base::trimws(x)), "custom:" ) )
    return(TRUE)
  
  
  # -- standard types
  supported <- c( "datafile", "datafile.sas", "datafile.rds", "datafile.rda", "datafile.csv", "datafile.xlsx", "datafile.text" )
  
  if ( base::tolower(base::trimws(x)) %in% supported )
    return(invisible(TRUE))
  
  
  
  return(invisible(FALSE))
}
