#' Utility function to drop a temporary work area 
#' 
#' @param x Work area reference
#' 
#' @return Invisible logical
#' 
#' 
#' @description
#' A work area is a temporary directory that is used as a \emph{working copy}.
#' 
#' 
#' @export

txflow_dropworkarea <- function( x ) {
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, c( "character", "numeric") ) ||
       (base::trimws(as.character(x)) == "" ) )
    return(invisible(TRUE))
  
  
  
  # -- config
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  # -- work area root
  root <- base::gsub( "\\\\", "/", cfg$option( "txflow.work", unset = base::tempdir() ) )
  
  if ( ! dir.exists(root) )
    stop( "Work area root directory does not exist" )
  
  
  # -- work area
  
  wrk_path <- file.path( root, paste0( "txflow-work-", base::tolower(base::trimws(x)) ), fsep = "/" )
  
  base::unlink( wrk_path, recursive = TRUE, force = TRUE )
  
  
  if ( ! dir.exists( wrk_path) )
    return(invisible(TRUE))
  
  
  return(invisible(FALSE))
}