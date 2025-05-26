#' Utility function to connect the txflow storage configuration
#' 
#' @return A tx flow storage object
#' 
#' @export

txflow_store <- function() {
  
  # -- configuration
  cfg <- cxapp::.cxappconfig()
  

  # -- local file system  
  if ( base::tolower(base::trimws(cfg$option("txflow.store", unset = "not-defined"))) == "local" )
    return(invisible( txflow.service:::.txflow_fsstore() ))
    
    
    
  stop( "Invalid storage configuration")
}


