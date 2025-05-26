#' Utility function to get a snapshot specification
#' 
#' @param x Snapshot
#' 
#' @return Snapshot specification as a list
#' 
#' @description
#' Returns a snapshot definition 
#' 
#' The snapshot `x` is referenced as `<repository>/<snapshot>`.
#' 
#' 
#' 
#' @export

txflow_snapshot <- function( x ) {

  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || ( base::trimws(x) == "" ) ||
       ! txflow.service::txflow_validname(x) )
    stop( "Repository name missing or invalid")
  
  
  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = FALSE )
  
  if ( inherits(store, "try-error") )
    return(invisible(list()))
  
  # -- snapshot
  tmp_spec <- try( store$snapshot(x, file = NULL ), silent = FALSE )
  
  if ( inherits( tmp_spec, "try-error") )
    return(invisible(list()))
 
  if ( is.null(tmp_spec) )
    return(invisible(NULL))
  
  
  lst <- try( jsonlite::fromJSON( tmp_spec ), silent = FALSE )
  
  base::unlink( base::dirname(tmp_spec), recursive = TRUE, force = FALSE )
  
  if ( inherits( tmp_spec, "try-error" ) ) 
    return(invisible(list()))
  
  return(invisible(lst))
}