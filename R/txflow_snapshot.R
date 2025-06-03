#' Utility function to get a snapshot specification
#' 
#' @param x Snapshot
#' @param as.actor User of service requesting snapshot specification
#' @param audited Enable audit trail for snapshot specification request
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

txflow_snapshot <- function( x, as.actor = NULL, audited = FALSE ) {

  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || ( base::trimws(x) == "" ) ||
       ! txflow.service::txflow_validname(x) )
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
  
  # -- snapshot
  tmp_spec <- try( store$snapshot(x, file = NULL ), silent = try_silent )
  
  if ( inherits( tmp_spec, "try-error") ) {
    cxapp::cxapp_logerr(tmp_spec)
    return(invisible(list()))
  }
 
  if ( is.null(tmp_spec) )
    return(invisible(NULL))
  
  
  lst <- try( jsonlite::fromJSON( tmp_spec ), silent = try_silent )
  
  base::unlink( base::dirname(tmp_spec), recursive = TRUE, force = FALSE )
  
  if ( inherits( lst, "try-error" ) ) {
    cxapp::cxapp_logerr( lst )
    return(invisible(list()))
  }
  
  
  if ( ! audited ) 
    return(invisible(lst))

    
  # -- audit record
  

  
  if ( is.null(as.actor) )
    stop( "Actor must be specified for audited actions" )
  
  audit_rec <- try( cxaudit::cxaudit_record( list( "event" = "read", 
                                                   "type" = "datarepository.snapshot", 
                                                   "class" = "snapshot",
                                                   "reference" = base::unname(lst[["name"]]), 
                                                   "object" = digest::digest( paste(lst[ c( "repository", "name") ], collapse = "/"), algo = "sha1", file = FALSE ), 
                                                   "label" = paste( "Get snapshot", lst[["name"]], " specification from data repository", lst[["repository"]] ),
                                                   "actor"  = ifelse( ! is.null(as.actor), as.actor, Sys.info()["user"] ) ) ),
                    silent = try_silent )
  
  if ( inherits( audit_rec, "try-error") ) {
    cxapp::cxapp_logerr(audit_rec)
    stop( "Could not create audit record" )
  }
  
  audit_commit <- try( cxaudit::cxaudit_commit( list( audit_rec ) ), silent = try_silent )
  
  if ( inherits( audit_commit, "try-error") || is.null(audit_commit) || ! audit_commit ) {
    
    if ( inherits( audit_commit, "try-error") )
      cxapp::cxapp_logerr(audit_commit)
    else
      cxapp::cxapp_logerr("Failed to commit audit record")
                          
    stop( "Failed to commit audit record" )
  }

  
  
  return(invisible(lst))
}