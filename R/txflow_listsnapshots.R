#' List snapshots in a repository
#' 
#' @param x Repository
#' 
#' @return A vector of snapshot names
#' 
#' @export

txflow_listsnapshots <- function( x ) {

  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || (length(x) != 1) || ( base::trimws(x) == "" ) ||
       ! txflow.service::txflow_validname(x, context = "repository") )
    stop( "Repository name missing or invalid")
  
  
  
  # - configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  

  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = try_silent )
  
  if ( inherits(store, "try-error") )
    return(invisible(list()))
  
  # -- snapshots
  lst <- try( store$snapshots(x), silent = try_silent )
  
  if ( inherits(lst, "try-error") || (length(lst) == 0) )
    return(invisible(list()))
  

  
  
  # -- standardize snapshot reference  
  lst_snapshots <- paste0( base::tolower(base::trimws(x)), "/", lst )
  
  
  return(invisible(lst_snapshots))
}