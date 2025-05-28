#' Utility function to assert if a snapshot is locked
#' 
#' @param x Resource
#' 
#' @return Invisible logical 
#' 
#' @description
#' Asserts if resource `x` is locked
#' 
#' Returns `TRUE` is if the resource is locked. `FALSE` otherwise.
#' 
#' 
#' @export

txflow_islocked <- function(x) {
  
  if ( ! txflow.service::txflow_validname( x, context = "snapshot") )
    return(invisible(FALSE))
  
  
  # -- storage
  strg <- txflow.service::txflow_store()
  

  return(invisible(strg$is.locked(x)))  
}