#' Add a file to a draft snapshot
#' 
#' @param x File
#' @param work Work area 
#' @param attrs File attributes
#' 
#' @returns File details
#' 
#' 
#' @export

txflow_addfile <- function( x, work = NULL, attrs = NULL ) {

  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits(x, "character") || 
       (length(x) != 1) || (base::trimws(x) == "") || ! file.exists(x) )
    stop( "File missing, invalid or does not exist" )
  

  if ( missing(work) || is.null(work) || any(is.na(work)) || ! inherits(work, "character") || 
       (length(work) != 1) || (base::trimws(work) == "") )
    stop( "Work area missing or invalid")

  
  if ( ! is.null(attrs) && (length(attrs) > 0) && 
       ( is.null(base::names(attrs)) || any( base::names(attrs) == "" ) ) )
    stop( "One or more named attributes invalid" )
       
  
  
  # -- connect work area
  wrk <- txflow.service::txflow_workarea( work = work )
  
  if ( ! "path" %in% base::names(attributes(wrk)) )
    stop( "Work path undefined" )
  
  wrk_path <- attributes(wrk)[["path"]] 
  
   
  
  blob_meta <- list( "type" = "datafile", 
                     "class" = "datafile", 
                     "reference" = base::tolower(tools::file_path_sans_ext(base::basename(x))),
                     "sha" = digest::digest( x, algo = "sha1", file = TRUE ), 
                     "blobs" = digest::digest( x, algo = "sha1", file = TRUE ),
                     "mime" = base::tolower(tools::file_ext(x)), 
                     "name" = base::tolower(base::basename(x)) )
  
  
  if ( ! is.null(attrs) || (length(attrs) > 0) ) {
    
    base::names(attrs) <- base::tolower(base::names(attrs))
    
    for ( xitem in base::names(blob_meta) )
      if ( ! xitem %in% c( "sha", "blobs") && xitem %in% base::names(attrs) )
        blob_meta[[xitem]] <- base::unname(base::tolower(base::trimws(attrs[[xitem]])))

    # - if reference is not specified  and name is ... derive from specified name
    if ( "name" %in% base::names(attrs) && ! "reference" %in% base::names(attrs) )
      blob_meta[["reference"]] <- tools::file_path_sans_ext( blob_meta[["name"]] )

    # - if mime is not specified  and name is ... derive from specified name
    if ( "name" %in% base::names(attrs) && ! "mime" %in% base::names(attrs) )
      blob_meta[["mime"]] <- tools::file_ext( blob_meta[["name"]] )

  }

  
  
  # -- check for existing like named items

  # - list of entry blobs
  entry_blobs <- list()
    
  
  if ( file.exists( file.path( wrk_path, "entries", fsep = "/" ) ) ) {

    # - get list of current entries    
    lst_entries <- try( base::readLines( file.path( wrk_path, "entries", fsep = "/" ), warn = FALSE ), silent = FALSE )

    # - parse entry list
    entry_blobs <- gsub( "^(.*)\\s.*$", "\\1", lst_entries )
    base::names(entry_blobs) <- gsub( "^.*\\s(.*)$", "\\1", lst_entries )

    
    if ( blob_meta[["name"]] %in% base::names(entry_blobs) ) {

      # - remove any associated work area files      
      base::unlink( c( file.path( wrk_path, entry_blobs[ blob_meta[["name"]] ], fsep = "/"),
                       file.path( wrk_path, paste0( entry_blobs[ blob_meta[["name"]] ], ".json"), fsep = "/") ),
                    recursive = FALSE, force = TRUE )
      

      # - remove from list of entries
      entry_blobs[[ blob_meta[["name"]] ]] <- NA
      
    }

  } # end of if-statement for list of entries
    

  # - add file to blob entries
  entry_blobs[[ blob_meta[["name"]] ]] <- blob_meta[["blobs"]]
  
  
    
  # - updated entries
  entry_lst <- sapply( base::names(entry_blobs[ ! is.na(entry_blobs) ]), function( z ) {
    paste( entry_blobs[z], z )
  })
  
  
  # - save list of entries
  
  if ( ! inherits( entry_lst, "try-error" ) && 
       inherits( try( base::writeLines( entry_lst,
                                        con = file.path( wrk_path, "entries", fsep = "/" )), silent = FALSE ), "try-error" ) ) 
    stop( "List of entries could not be amended")
      

  
  # -- staging area
  tmp_dir <- gsub( "\\\\", "/", base::tempfile( pattern = "tmp-work-", tmpdir = base::tempdir(), fileext = "" ))
  
  if ( ! dir.exists(tmp_dir) && ! dir.create(tmp_dir, recursive = TRUE) )
    return(invisible(NULL))
  
  
  # -- stage file
  
  if ( ! file.copy( x, tmp_dir, overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE ) ||
       ! file.rename( file.path( tmp_dir, base::basename(x), fsep = "/" ), 
                      file.path( tmp_dir, blob_meta[["blobs"]], fsep = "/" ) ) ||
       ! file.copy( file.path( tmp_dir, blob_meta[["blobs"]], fsep = "/" ),
                    wrk_path, 
                    overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE ) )
    stop( "Failed to add file to work area" )
    
  base::unlink( tmp_dir, recursive = TRUE, force = TRUE )
  

  # -- write metadata
  
  if ( inherits( try( base::writeLines( jsonlite::toJSON( blob_meta, pretty = TRUE, auto_unbox = TRUE ),
                                        con = file.path( wrk_path, paste0( blob_meta[["blobs"]], ".json" ), fsep = "/" )), silent = FALSE ), "try-error" ) )
    stop( "File details could not be added to work area")
  

  return(invisible( blob_meta ))
}