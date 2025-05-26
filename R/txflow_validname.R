#' Function to validate Flow references names
#' 
#' @param x Character string
#' @param context Force context 
#' 
#' @return Invisible logical 
#' 
#' @description
#' Flow repository names are restricted by the different service that actually
#' store the repository.
#' 
#' A value delimited by a foward slash `/` is assumed to represent a snapshot
#' reference. A value without the slash delimited represents a repsitory.
#' 
#' If name `x` is valid, `TRUE` is returned. Otherwise, `FALSE`.
#' 
#' A repository name is restricted to the following conditions
#' 
#' \itemize{
#'   \item Consists of letters a-z, digits 0-9 and punctuation dash `-`
#'   \item Starts and ends with a letter or number
#'   \item All dashes `-` must be preceded and followed by letter or digit
#'   \item Length is between 3 and 63 characters
#' }
#' 
#' A snapshot name is restricted to the following conditions
#' 
#' \itemize{
#'   \item Consists of letters a-z, digits 0-9 and punctuation dash `-` and underscore `_`
#'   \item Starts and ends with a letter or number
#'   \item All dashes `-` and underscores `_` must be preceded and followed by letter or digit
#'   \item Length is between 3 and 256 characters
#' }
#' 
#' Reference names are case insensitive
#' 
#' @export 


txflow_validname <- function( x, context = NULL ) {
  
  
  # -- obviously false
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") || (base::trimws(x) == "") )
    return(invisible(FALSE))
  
  
  # -- references 
  ref <- base::unlist(base::strsplit( x, "/", fixed = TRUE ), use.names = FALSE)
  
  if ( length(ref) > 2 )
    stop("Snapshot reference invalid" )
  
  base::names(ref) <- c( "repository", "snapshot" )[ 1:length(ref) ]

  
  # -- force repository context
  if ( ! is.null(context) && (base::tolower(base::trimws(context)) == "repository") &&
       ( length(ref) != 1 ) )
    return(invisible(FALSE))
  
  
  # -- force snapshot context
  if ( ! is.null(context) && (base::tolower(base::trimws(context)) == "snapshot") &&
       ! "snapshot" %in% base::names(ref) )
    return(invisible(FALSE))
    
  
  
  # -- dynamic context 
  
  rslt <- base::rep_len(FALSE, length(ref) )
  base::names(rslt) <- base::names(ref)
  
  if ( "repository" %in% base::names(ref)  && 
       grepl( "^[a-z0-9]+(-[a-z0-9]+)*$" , ref[["repository"]], ignore.case = TRUE ) &&
       (base::nchar(base::trimws(ref[["repository"]])) >= 3) && (base::nchar(base::trimws(ref[["repository"]])) <= 63) )
    rslt[[ "repository" ]] <- TRUE
  
  if ( "snapshot" %in% base::names(ref)  && 
       grepl( "^[a-z0-9]+([-_][a-z0-9]+)*$" , ref[["snapshot"]], ignore.case = TRUE ) &&
       (base::nchar(base::trimws(ref[["snapshot"]])) >= 3) && (base::nchar(base::trimws(ref[["snapshot"]])) <= 256) )
    rslt[[ "snapshot" ]] <- TRUE
  
  if ( all(rslt) )
    return(invisible(TRUE))
  
  
  return(invisible(FALSE))
}