#' Utility function remove a file from a snapshot
#' 
#' @param x Reference to resource to remove
#' @param work Work area
#' 
#' @return Invisible `TRUE`
#' 
#' @description
#' 
#' The resource reference `x` can either be the resource name or blob.
#'  
#' 
#' 
#' 
#' 
#' @export

txflow_dropfile <- function( x, work = NULL ) {
  
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || 
       (length(x) != 1) || (base::trimws(x) == "") )
    stop( "File missing or invalid" )
  
  
  if ( missing(work) || is.null(work) || any(is.na(work)) || ! inherits(work, "character") || 
       (length(work) != 1) || (base::trimws(work) == "") )
    stop( "Work area missing or invalid")
  
  
  # -- config
  cfg <- cxapp::.cxappconfig()
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  
  # -- connect work area
  wrk <- txflow.service::txflow_workarea( work = work )
  
  if ( ! "path" %in% base::names(attributes(wrk)) )
    stop( "Work path undefined" )
  
  wrk_path <- attributes(wrk)[["path"]] 
  

  
  # -- import list of entries
  
  entry_blobs <- character(0)
  
  
  entry_lst <- try( base::readLines( file.path( wrk_path, "entries")), silent = try_silent )
  
  if ( inherits( entry_lst, "try-error") ) {
    cxapp::cxapp_logerr(entry_lst)
    
  } else {
    
    # - parse entry list
    entry_blobs <- gsub( "^(.*)\\s.*$", "\\1", entry_lst )
    base::names(entry_blobs) <- gsub( "^.*\\s(.*)$", "\\1", entry_lst )
    
  }
  

  base::rm( list = "entry_lst" )
  
  

  # -- identify blob in work area
  
  resource_blob <- NA

  if ( any( file.exists( file.path( wrk_path, c( base::tolower(base::trimws(x)),
                                                 paste0( base::tolower(base::trimws(x)), ".json" ) ),
                                    fsep = "/" ) ) ) )  {

    # - reference is a blob with 
    resource_blob <- x

  } else {
    
    # - reference may not be blob
    if ( base::tolower(x) %in% base::names(entry_blobs) )
      resource_blob <- entry_blobs[ base::tolower(x) ]
    
  }
  

    
  # - blob cannot be identified .. so obviously nothing to drop
  if ( is.na(resource_blob) )
    return(invisible(TRUE))
  
  

  # - remove blob from entries
  entry_blobs <- entry_blobs[ ! entry_blobs %in% resource_blob ]
  

  # - save list of entries
  
  entry_lst <- sapply( base::names(entry_blobs), function( z ) {
    paste( entry_blobs[z], z )
  })  
  
  
  entry_lst_write <- try( base::writeLines( entry_lst,
                                            con = file.path( wrk_path, "entries", fsep = "/" )), silent = try_silent )
  

  if ( inherits( entry_lst_write, "try-error" ) ) {
    cxapp::cxapp_logerr(entry_lst_write)
    stop( "List of entries could not be amended")
  }  
  
  
  
  # -- remove blob
  
  if ( file.exists( file.path( wrk_path, resource_blob, fsep = "/" ) ) ) {

    # note: if blob exists as a file .. then remove both    
    
    files_to_remove <- file.path( wrk_path,
                                  c( resource_blob,
                                     paste0( resource_blob, ".json") ),
                                  fsep = "/" )
    
    base::unlink( files_to_remove, recursive = FALSE, force = TRUE )

    return(invisible( all(! file.exists(files_to_remove)) ))

  } else {
    
    # note: only as a reference ... mark for deletion for audit purposes
    
    blob_spec_file <- file.path( wrk_path, paste0( resource_blob, ".json"), fsep = "/" )
    mark_del_blob_spec_file <- file.path( wrk_path, paste0( "delete-blob-", resource_blob, ".json"), fsep = "/" )
    
    if ( file.exists( blob_spec_file) &&
         file.rename( blob_spec_file, mark_del_blob_spec_file ) )
      return(TRUE)

  }
    


    
  return(invisible(FALSE))
}


