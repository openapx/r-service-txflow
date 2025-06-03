#' Utility function to add reference to an existing repository file to a work area
#' 
#' @param x Resource
#' @param work Work area
#' @param name Name for resource
#' 
#' @return Resource specification
#' 
#' @description
#' 
#' A reference can only be added to a work area that contains a snapshot 
#' specification. All added references must be from the same repository as
#' the snapshot.
#' 
#' The resource can be specified simply as `<resource>` as the repository is 
#' known. If the resource is specified as either a repository resource 
#' `<repository>/<resource>` or explicitly as a snapshot reference
#' `<repository>/<snapshot>/<resource>`, the repository must match the 
#' repository in the snapshot specification.  
#' 
#' 
#' @export

txflow_addreference <- function( x, work = NULL, name = NULL ) {
  
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || 
       (length(x) != 1) || (base::trimws(x) == "") )
    stop( "Resource missing or invalid" )
  
  
  if ( missing(work) || is.null(work) || any(is.na(work)) || ! inherits(work, "character") || 
       (length(work) != 1) || (base::trimws(work) == "") )
    stop( "Work area missing or invalid")
  
  
  if ( ! is.null(name) &&
       ( any(is.na(name)) || ! inherits(name, "character") || (length(name) != 1) || (base::trimws(name) == "") ) )
    stop( "Name is missing or invalid")
  
  
  # -- config
  cfg <- cxapp::.cxappconfig()
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  
  # -- connect work area
  wrk <- txflow.service::txflow_workarea( work = work )
  
  if ( ! "path" %in% base::names(attributes(wrk)) )
    stop( "Work path undefined" )
  
  wrk_path <- attributes(wrk)[["path"]] 
  
  
  
  # -- import snapshot spec
  lst_files <- list.files( wrk_path, pattern = "^snapshot-.*\\.json$", recursive = FALSE, full.names = FALSE )
  
  if ( length(lst_files) != 1 )
    stop( "Work area requires a snapshot specification" )


  snapshot_spec <- try( jsonlite::fromJSON( file.path( wrk_path, lst_files, fsep = "/" ) ), silent = try_silent )
  
  if ( inherits(snapshot_spec, "try-error") ) {
    cxapp::cxapp_logerr( snapshot_spec )
    stop( "Work area requires a snapshot specification" )
  }
  
  

  
  
  # -- identify resource
  
  resource <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE)
  
  # - just the resource
  if ( length(resource) == 1 )
    base::names(resource) <- "resource"
    
  # - resource reference starts with repository
  if ( ( length(resource) == 2 ) && ( resource[[1]] == snapshot_spec[["repository"]] ) )
    base::names(resource) <- c( "repository", "resource" )
  
  # - resource reference does not start with repository ... so starts with snapshot
  if ( ( length(resource) == 2 ) && ( resource[[1]] != snapshot_spec[["repository"]] ) )
    base::names(resource) <- c( "snapshot", "resource" )
  
  # - full qualified resource
  if ( length(resource) == 3 )
    base::names(resource) <- c( "repository", "snapshot", "resource")
  

  # - if missing repository details .. amend
  if ( ! "repository" %in% base::names(resource) )
    resource["repository"] <- base::unname(snapshot_spec[["repository"]])
  
  
  # - ensure resource is from within work area snapshot specification repository  
  if ( "repository" %in% base::names(resource) && ( base::unname(resource[["repository"]]) != base::unname(snapshot_spec[["repository"]]) ) )
    stop( "Repository in work area snapshot specification does not match repository of specified resource")
  

  # - reorder entries to sequence repository - snapshot - resource
  resource_names <- c( "repository", "snapshot", "resource" )
  resource <- resource[ resource_names[ resource_names %in% base::names(resource) ] ]
  
  
  # -- connect to storage
  strg <- txflow.service::txflow_store()
  

  
  # -- get reference 
  ref_path <- try( strg$getreference( paste( resource, collapse = "/") ), silent = try_silent )

  if ( inherits( ref_path, "try-error" ) || is.null(ref_path) ) {
    
    if (inherits( ref_path, "try-error" ))
      cxapp::cxapp_logerr(ref_path)

    return(invisible(NULL))
  }
  
  
  # -- import reference
  resource_spec <- try( jsonlite::fromJSON( ref_path ), silent = try_silent ) 
   
  if ( inherits(resource_spec, "try-error") ) {
    cxapp::cxapp_logerr( resource_spec )
    return(invisible(NULL))
  }
  
  
  # - overwrite name
  if ( ! is.null(name) )
    resource_spec[["name"]] <- base::tolower(base::trimws(name)) 
  
  
  
  
  
  # -- check for existing like named items

  # - list of entry blobs
  entry_blobs <- list()


  if ( file.exists( file.path( wrk_path, "entries", fsep = "/" ) ) ) {

    # - get list of current entries
    lst_entries <- try( base::readLines( file.path( wrk_path, "entries", fsep = "/" ), warn = FALSE ), silent = try_silent )

    if ( inherits(lst_entries, "try-error") ) {
      cxapp::cxapp_logerr( lst_entries )
    } else {

      # - parse entry list
      entry_blobs <- gsub( "^(.*)\\s.*$", "\\1", lst_entries )
      base::names(entry_blobs) <- gsub( "^.*\\s(.*)$", "\\1", lst_entries )
  
  
      if ( resource_spec[["name"]] %in% base::names(entry_blobs) ) {
  
        # - remove any associated work area files
        base::unlink( c( file.path( wrk_path, entry_blobs[ resource_spec[["name"]] ], fsep = "/"),
                         file.path( wrk_path, paste0( entry_blobs[ resource_spec[["name"]] ], ".json"), fsep = "/") ),
                      recursive = FALSE, force = TRUE )
  
  
        # - remove from list of entries
        entry_blobs[[ resource_spec[["name"]] ]] <- NA
  
      }
    
    }

  } # end of if-statement for list of entries


  # - add file to blob entries
  entry_blobs[[ resource_spec[["name"]] ]] <- resource_spec[["blobs"]]
  
  
  # - updated entries
  entry_lst <- sapply( base::names(entry_blobs[ ! is.na(entry_blobs) ]), function( z ) {
    paste( entry_blobs[z], z )
  })
  
  
  # - save list of entries

  lst_entries_write <- try( base::writeLines( entry_lst,
                                              con = file.path( wrk_path, "entries", fsep = "/" )), silent = try_silent )
  
  if ( inherits( lst_entries_write, "try-error" ) ) {
    cxapp::cxapp_logerr( lst_entries_write )
    stop( "List of entries could not be amended")
  }
  
  
  
  # -- save resource specification
  
  resource_spec_write <- try( base::writeLines( jsonlite::toJSON( resource_spec, pretty = TRUE, auto_unbox = TRUE), 
                                                con = file.path( wrk_path, paste0( resource_spec[["blobs"]], ".json"), fsep = "/" ) ),
                              silent = try_silent )
  
  if ( inherits( resource_spec_write, "try-error") ) {
    cxapp::cxapp_logerr( resource_spec_write )
    stop( "Could not save resource specification")
  }
  

  
  return(invisible(resource_spec))
}