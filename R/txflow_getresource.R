#' Utility function to retrieve a file associated with a repository snapshot
#' 
#' @param x Snapshot file or resource
#' @param as.actor User or service retrieving resource
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


txflow_getresource <- function( x, as.actor = NULL ) {
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") ||
       (length(x) != 1) || (base::trimws(x) == "") )
    return(invisible(NULL))
  

  
  # - configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  
  # -- connect to storage
  store <- txflow.service::txflow_store()
  
  
  # -- resource
  obj <- try( store$getresource(x), silent = try_silent )
  
  if ( inherits( obj, "try-error") || is.null(obj) ) {
    
    if ( inherits( obj, "try-error") )
      cxapp::cxapp_logerr(obj)
    
    return(invisible(NULL))
  }


  # -- auditing

  
  # - get blob reference
  spec_file <- try( store$getreference(x), silent = try_silent )

  if ( inherits( spec_file, "try-error") || is.null(spec_file) ) {
    cxapp::cxapp_logerr(spec_file)
    return(invisible(NULL))
  }

    
  # - import blob reference
  
  blob_spec <- try( jsonlite::fromJSON( spec_file ), silent = try_silent )
  
  if ( inherits( blob_spec, "try-error") ) {
    cxapp::cxapp_logerr(blob_spec)
    return(invisible(NULL))
  }
  
  
  audit_rec <- try( cxaudit::cxaudit_record( list( "event" = "read",
                                                   "type" = blob_spec[["type"]], 
                                                   "class" = blob_spec[["class"]],
                                                   "reference" = blob_spec[["reference"]], 
                                                   "object" = blob_spec[["sha"]],
                                                   "label" = paste( "Get resource of", 
                                                                    blob_spec[["class"]], blob_spec[["reference"]], "as", blob_spec[["name"]], 
                                                                    "from repository", utils::head( unlist(strsplit(x, "/", fixed = TRUE)), n = 1 ) ),
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
  
  
  
  return(invisible(obj)) 
}