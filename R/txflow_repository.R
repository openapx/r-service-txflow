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
  
  
  
  # - configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
    
  # -- connect storage 
  store <- try( txflow.service::txflow_store(), silent = try_silent )
  
  if ( inherits(store, "try-error") ) {
    cxapp::cxapp_logerr(store)
    return(invisible(list()))
  }

  

  # -- create repository ... if it does not exist
  rslt <- try( store$repository( x, create = TRUE ), silent = try_silent )
  
  if ( inherits( rslt, "try-error") || is.null(rslt) ) {
    
    if ( inherits( rslt, "try-error") ) 
      cxapp::cxapp_logerr(rslt)
      
     
    stop( "Could not create repository" )
  
  }
  
  # -- audit details
  
  
  if ( cfg$option( "auditor", unset = FALSE ) ) {
    
    audit_details <- list( "event" = "create", 
                           "type" = "data.repository", 
                           "reference" = x, 
                           "label" = paste( "Created repository", x), 
                           "actor"  = ifelse( ! is.null(as.actor), as.actor, "unknown" ) )
    
    audit_commit <- try( cxaudit::cxaudit_commit( list( cxaudit::cxaudit_record( audit_details ) ) ), silent = try_silent )
    
    if ( inherits( audit_commit, "try-error") )
      cxapp::cxapp_logerr(audit_commit)
    
  }
  
  
  
  return(invisible(base::tolower(base::trimws(x))))
}


