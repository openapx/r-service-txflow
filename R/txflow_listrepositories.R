#' List data repositories
#' 
#' @return Vector of repositories
#' 
#' @export

txflow_listrepositories <- function() {

  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = FALSE )
    
  if ( inherits(store, "try-error") )
    return(invisible(list()))
  
  # -- repositories
  lst <- try( store$repositories(), silent = FALSE )
  
  if ( inherits(lst, "try-error") )
    return(invisible(list()))
  

  return(invisible(lst))
}


