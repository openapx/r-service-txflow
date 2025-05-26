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
  
  
  
  # -- connect work area
  wrk <- txflow.service::txflow_workarea( work = work )
  
  if ( ! "path" %in% base::names(attributes(wrk)) )
    stop( "Work path undefined" )
  
  wrk_path <- attributes(wrk)[["path"]] 
  
  
  
  # -- import snapshot spec
  lst_files <- list.files( wrk_path, pattern = "^snapshot-.*\\.json$", recursive = FALSE, full.names = FALSE )
  
  if ( length(lst_files) != 1 )
    stop( "Work area requires a snapshot specification" )


  snapshot_spec <- try( jsonlite::fromJSON( file.path( wrk_path, lst_files, fsep = "/" ) ), silent = FALSE )
  
  if ( inherits(snapshot_spec, "try-error") )
    stop( "Work area requires a snapshot specification" )
  
  

  
  
  # -- identify resource
  
  resource <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE)

  resource_naming <- list( c( "resource"), 
                           c( "repository", "resource"),
                           c( "repository", "snapshot", "resource") )
    
  base::names(resource) <- resource_naming[[ length(resource) ]]

  
  if ( "repository" %in% base::names(resource) && ( base::unname(resource[["repository"]]) != base::unname(snapshot_spec[["repository"]]) ) )
    stop( "Respository in work area snapshot specification does not match repository of specified resource")
  
  
  # - force repository
  resource[ "repository" ] <- base::unname(snapshot_spec[["repository"]])
  
  

  
  # -- connect to storage
  strg <- txflow.service::txflow_store()
  

  
  # -- get reference 
  ref_path <- try( strg$getreference( paste( resource, collapse = "/") ), silent = FALSE )
 
  if ( inherits( ref_path, "try-error" ) || is.null(ref_path) )
    return(invisible(NULL))
  
  
  # -- import reference
  resource_spec <- try( jsonlite::fromJSON( ref_path ), silent = FALSE ) 
  
  if ( inherits(resource_spec, "try-error") )
    return(invisible(NULL))
  
  
  # - overwrite name
  if ( ! is.null(name) )
    resource_spec[["name"]] <- base::tolower(base::trimws(name)) 
  
  
  
  
  
  # -- check for existing like named items

  entry_lst <- character(0)

  if ( file.exists( file.path( wrk_path, "entries", fsep = "/" ) ) ) {

    # - get list of current entries
    entry_lst <- try( base::readLines( file.path( wrk_path, "entries", fsep = "/" ), warn = FALSE ), silent = FALSE )


    # - parse entry list
    entry_blobs <- gsub( "^(.*)\\s.*$", "\\1", entry_lst )
    base::names(entry_blobs) <- gsub( "^.*\\s(.*)$", "\\1", entry_lst )


    if ( resource_spec[["name"]] %in% base::names(entry_blobs) ) {

      # - remove any associated work area files
      base::unlink( c( file.path( wrk_path, entry_blobs[ resource_spec[["name"]] ], fsep = "/"),
                       file.path( wrk_path, paste0( entry_blobs[ resource_spec[["name"]] ], ".json"), fsep = "/") ),
                    recursive = FALSE, force = TRUE )


      # - remove from list of entries
      entry_blobs <- entry_blobs[ ! base::names(entry_blobs) %in% resource_spec[["name"]] ]

    }


    # - add file to blob entries
    entry_blobs[[ resource_spec[["name"]] ]] <- resource_spec[["blobs"]]


    # - updated entries
    entry_lst <- sapply( base::names(entry_blobs), function( z ) {
      paste( entry_blobs[z], z )
    })

  } # end of if-statement for list of entries



  # - save list of entries

  if ( ! inherits( entry_lst, "try-error" ) &&
       inherits( try( base::writeLines( entry_lst,
                                        con = file.path( wrk_path, "entries", fsep = "/" )), silent = FALSE ), "try-error" ) )
    stop( "List of entries could not be amended")

  
  
  
  # -- save resource specification
  if ( inherits( try( base::writeLines( jsonlite::toJSON( resource_spec, pretty = TRUE, auto_unbox = TRUE), 
                                        con = file.path( wrk_path, paste0( resource_spec[["blobs"]], ".json"), fsep = "/" ) ),
                      silent = FALSE ),
                 "try-error") )
    stop( "Could not save resource specification")
  

  
  return(invisible(resource_spec))
}