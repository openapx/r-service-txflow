#' Utility function to retrieve a file associated with a repository snapshot
#' 
#' @param x Snapshot file or resource
#' 
#' @return Path to the cached file or resource
#' 
#' @description
#' A file or resource is an item that is stored in a data repository and 
#' associated with a snapshot. 
#'  
#' The file or resource `x` is specified in the format 
#' `<repository>/<snapshot>/<file or resource>`.
#' 
#' The utility uses the cxapp application cache \link[cxapp]{cxapp_applicationcache}
#' as a temporary storage location for the resource or file retrieved from the
#' back end storage solution.
#' 
#' @export


txflow_getresource <- function( x ) {
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") ||
       (length(x) != 1) || (base::trimws(x) == "") )
    return(invisible(NULL))
  
  
  # -- connect to storage
  store <- txflow.service::txflow_store()
  
  
  # -- resource
  obj <- try( store$getresource(x), silent = FALSE )
  
  if ( inherits( obj, "try-error") || is.null(obj) )
    return(invisible(NULL))

  return(invisible(obj)) 
}