#' Create or get reference to an existing repository
#' 
#' @param x Repository name
#' @param as.actor Principal creating the repository
#' 
#' @return Repository name
#' 
#' @export

txflow_repository <- function( x, as.actor = NULL ) {

  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || (length(x) != 1) || ( base::trimws(x) == "" ) ||
       ! txflow.service::txflow_validname(x, context = "repository") )
    stop( "Repository name missing or invalid")
  
    
  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = FALSE )
  
  if ( inherits(store, "try-error") )
    return(invisible(list()))

  

  # -- create repository ... if it does not exist
  rslt <- try( store$repository( x, create = TRUE ), silent = FALSE )
  
  if ( is.null(rslt) )
    stop( "Could not create repository" )
  
  
  # -- audit details
  cfg <- cxapp::.cxappconfig()
  
  if ( cfg$option( "auditor", unset = FALSE ) ) {
    
    audit_details <- list( "event" = "create", 
                           "type" = "data.repository", 
                           "reference" = x, 
                           "label" = paste( "Created repository", x), 
                           "actor"  = ifelse( ! is.null(as.actor), as.actor, "unknown" ) )
    
    cxaudit::cxaudit_commit( list( cxaudit::cxaudit_record( audit_details ) ) )
    
  }
  
  
  
  return(invisible(base::tolower(base::trimws(x))))
}


