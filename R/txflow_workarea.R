#' Utility function to create or get references to a temporary work area 
#' 
#' @param work Work area reference
#' @param snapshot Snapshot to clone
#' 
#' @return Invisible work area path
#' 
#' 
#' @description
#' A work area is a temporary directory that is used as a \emph{working copy}.
#' 
#' If `work` is not specified or `NULL`, a new work area is created
#' 
#' If `snapshot` is specified and it exists, the snapshot definition file 
#' is staged in the work area. 
#' 
#' @export

txflow_workarea <- function( work = NULL, snapshot = NULL ) {


  if ( ! missing(work) &&
       (is.null(work) || any(is.na(work)) || ! inherits(work, "character") || ( base::trimws(work) == "" ) ) )
    stop( "Work area reference invalid")


  if ( ! is.null(snapshot) && ! txflow.service::txflow_validname( snapshot, context = "snapshot") ) 
    stop( "Snapshot reference mising or invalid" )
  
  

  # -- config
  cfg <- cxapp::.cxappconfig()

  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  # -- work area root
  root <- base::gsub( "\\\\", "/", cfg$option( "txflow.work", unset = base::tempdir() ) )
  
  if ( ! dir.exists(root) )
    stop( "Work area root directory does not exist" )
  
  
  
  # -- work area
  
  wrk_area <- character(0)
  
  if ( is.null(work) ) { 
    
    wrk_area <- base::gsub( "\\\\", "/", base::tempfile( "txflow-work-", tmpdir = root, fileext = "") )
    
    if ( ! dir.exists(wrk_area) && ! dir.create(wrk_area, recursive = TRUE) )
      stop( "Could not create work area" )
    
  } else {
    
    wrk_area <- file.path( root, paste0("txflow-work-", base::tolower(base::trimws(work)) ), fsep = "/" )
    
  }
  
  if ( ! dir.exists(wrk_area) )
    stop( "Work area ", base::tolower(base::trimws(work)), " does not exists" )
  
  
  # - derive work reference
  wrk_ref <- gsub( "^txflow-work-(.*)$", "\\1", base::basename(wrk_area) ) 
  attributes(wrk_ref) <- list( "path" = wrk_area )
  

  # -- existing working area, return reference
  if ( ! is.null(work) )
    return(invisible(wrk_ref))
  


  # -- create work area snapshot for reference 
  #    note: using an empty default snapshot for simplicity ... for now

  if ( ! txflow.service::txflow_validname( snapshot, context = "snapshot") ) 
    stop( "Snapshot reference required to create a new work area" )

  
  default_spec <- txflow.service:::.txflow_defaultsnapshot( snapshot )
  
  
  wrk_snapshot_spec_file <- file.path( wrk_area, paste0( "snapshot-", default_spec[["name"]],".json" ), fsep = "/" )

  if ( inherits( try( base::writeLines( jsonlite::toJSON( default_spec, pretty = TRUE, auto_unbox = TRUE ),
                                        con = wrk_snapshot_spec_file ), silent = try_silent ), "try-error" ) )
    stop( "Work area snapshot specification could not be initiated")


  # - initialize with default work area inventory
  
  inv_write <- try( base::writeLines( paste( digest::digest( wrk_snapshot_spec_file, algo = "sha1", file = TRUE ),
                                             base::basename(wrk_snapshot_spec_file), sep = " " ),
                                      con = file.path( wrk_area, "inventory", fsep = "/" )), silent = try_silent )
  
  if ( inherits( inv_write, "try-error" ) ) {
    cxapp::cxapp_logerr( inv_write )
    stop( "Work area could not be initiated")
  }
  
      

  # -- snapshot not specified
  
  if ( is.null(snapshot) ) 
    return(invisible(wrk_ref))

  
  
  # --  snapshot specified

  # - get snapshot from storage  
  strg <- txflow.service::txflow_store()
  
  path_spec <- try( strg$snapshot( snapshot ), silent = try_silent )
  
  if ( inherits( path_spec, "try-error" ) ) {
    cxapp::cxapp_logerr(path_spec)
    stop( "Failed to retrieve snapshot specification from repository" )
  }

  
  # - snapshot does not exist in repository
  if ( is.null(path_spec) )
    return(invisible(wrk_ref))
  
    
  # - import snapshot specification
  
  snapshot_spec <- try( jsonlite::fromJSON( path_spec ), silent = try_silent )
  
  if ( inherits( snapshot_spec, "try-error") ) {
    cxapp::cxapp_logerr(snapshot_spec)
    stop( "Could not import existing snapshot specification" )
  }
  
  
  
  # - process content
  
  if ( ! "members" %in% base::names(snapshot_spec) )
    return(invisible(wrk_ref))

  
  entry_lst <- character(0)
  
  for ( xentry in snapshot_spec[["members"]] ) {
    
    xentry_file <- file.path( wrk_area, paste0( xentry[["blobs"]], ".json"), fsep = "/" )
    
    if ( file.exists(xentry_file) )
      next()
    
    xentry_write <- try( base::writeLines( jsonlite::toJSON( xentry, pretty = TRUE, auto_unbox = TRUE),
                                           con = xentry_file ), silent = try_silent ) 
    
    if ( inherits( xentry_write, "try-error" ) ) {
      cxapp::cxapp_logerr(xentry_write)
      stop( "Could not stage entry in Work area")
    }
  
    entry_lst <- append( entry_lst, 
                         paste( xentry[["blobs"]], xentry[["name"]] ) )  
  
    base::rm( list = "xentry_write" )  
  }
  
  
  
  entry_lst_write <- try( base::writeLines( entry_lst, con = file.path( wrk_area, "entries", fsep = "/" )), silent = try_silent )
  
  if ( inherits( entry_lst_write, "try-error" ) ) {
    cxapp::cxapp_logerr( entry_lst_write )
    stop( "List of entries could not be initiated")
  }
  
  
  
  # - inventory work area
  lst <- sapply( list.files( wrk_area, pattern = "\\.json$", full.names = TRUE, recursive = FALSE ), function(xfile) {
    paste( digest::digest( xfile, algo = "sha1", file = TRUE ), base::basename( xfile ), sep = " " )
  }, USE.NAMES = FALSE)

  
  inv_write <- try( base::writeLines( lst, con = file.path( wrk_area, "inventory", fsep = "/" )), silent = try_silent )
  
  if ( inherits( inv_write, "try-error" ) ) {
    cxapp::cxapp_logerr(inv_write)
    stop( "Populated work area could not be initiated")
  }
  

  # -- all done 
  
  return(invisible(wrk_ref))
}