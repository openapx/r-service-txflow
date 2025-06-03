#' List data repositories
#' 
#' @return Vector of repositories
#' 
#' @export

txflow_listrepositories <- function() {

  
  # - configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  
  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = try_silent )
    
  if ( inherits(store, "try-error") ) {
    cxapp::cxapp_logerr(store)
    return(invisible(list()))
  }
  
  # -- repositories
  lst <- try( store$repositories(), silent = try_silent )
  
  if ( inherits(lst, "try-error") ) {
    cxapp::cxapp_logerr(lst)
    return(invisible(list()))
  }
  

  return(invisible(lst))
}


