#' Utility function to commit changes to a snapshot to the repository
#' 
#' @param x Work area
#' @param snapshot Snapshot
#' @param as.actor User or service principal performing the commit
#' 
#' @return Logical `TRUE` if commit succeeded
#' 
#' @description
#' 
#' 
#' The snapshot `snapshot` is referenced as `<repository>/<snapshot>`.
#' 
#' @export

txflow_commit <- function( x, snapshot = NULL, as.actor = NULL ) {


  # -- configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  # -- connect to work area
  wrk <- try( txflow.service::txflow_workarea( work = x ), silent = try_silent )
  
  if ( inherits( wrk, "try-error" ) )
    stop( "Work area for snapshot could not be established" )
  
  wrk_area <- base::unname(attributes(wrk)[["path"]])

  
  
  
  # -- snapshot specification
  
  lst_specs <- list.files( wrk_area, pattern = "^snapshot-.*\\.json$", full.names = FALSE, recursive = FALSE )
  
  if ( length(lst_specs) == 0 ) 
    stop( "A default or staged snapshot specification expected" )
  
  snapshot_spec_file <- utils::head(lst_specs, n = 1)


  # - import snapshot specification
  
  snapshot_spec <- try( jsonlite::fromJSON( file.path( wrk_area, snapshot_spec_file, fsep = "/" )), silent = try_silent )
  
  if ( inherits( snapshot_spec, "try-error" ) )
    stop( "Could not import snapshot specification" )

  # note: needed for future reference
  snapshot_spec_scope <- paste( snapshot_spec[ c( "repository", "snapshot") ], collapse = "/" )

  
  
  # -- commit scope
  
  commit_scope <- NA

  
  if ( is.null(snapshot) ) {

    # - use snapshot spec
    commit_scope <- c( "repository" = snapshot_spec[["repository"]], 
                       "snapshot" = snapshot_spec[["name"]] )

  } else {
    
    commit_scope <- unlist(strsplit( base::tolower(base::trimws(snapshot)), "/"), use.names = FALSE )

    # note: commit re-direct to another snapshot
    if ( length(commit_scope) == 1 ) 
      commit_scope <- c( snapshot_spec[["repository"]], commit_scope )

            
    base::names(commit_scope) <- c( "repository", "snapshot" )

    
    # - validate against snapshot spec
    
    if ( (snapshot_spec[["repository"]] != "unknown") &&
         ( base::unname(commit_scope["repository"]) != base::unname(snapshot_spec[["repository"]]) ) )
      stop( "Specified snapshot is not within the same repository as the snapshot specification" )

  }


  if ( "unknown" %in% commit_scope )
    stop( "Commit snapshot not defined" )

  
    

  # - specified snapshot is commit scope 
  if ( ! txflow.service::txflow_validname( paste(commit_scope, collapse = "/"), context = "snapshot") )
    stop("Specified snapshot is not a valid snapshot reference" )
  
  
  
  # -- snapshot spec not equal to commit scope
  
  if ( snapshot_spec_file != paste0( "snapshot-", commit_scope[["snapshot"]], ".json" ) ) {

    old_spec <- file.path( wrk_area, snapshot_spec_file, fsep = "/" )
    new_spec <- file.path( wrk_area, paste0( "snapshot-", commit_scope[["snapshot"]], ".json" ), fsep = "/" )
    
    if ( ! file.rename( old_spec, new_spec) )
      stop( "Could not stage specification as a new snapshot" )
    
    
    # note: new spec file
    snapshot_spec_file <- base::basename(new_spec)
  }
  
  
  

  # note: at this point ... we know repository and snapshot
  
    
  
  
  
  # -- purge any existing snapshot contents
  snapshot_spec[["members"]] <- list()
  
  
  # -- import prior inventory 
  prior_inventory <- character(0)
  
  lst_inv <- try( base::readLines( file.path( wrk_area, "inventory", fsep = "/"), warn = FALSE ), silent = try_silent )
  
  if ( ! inherits( lst_inv, "try-error" ) ) {
    # - parse inventory
    #   note: expecting format <digest><space><file>
    prior_inventory <- gsub( "^(.*)\\s.*$", "\\1", lst_inv )
    base::names(prior_inventory) <- gsub( "^.*\\s(.*)$", "\\1", lst_inv )
  }

  
  # -- commit inventory of work area
  commit_inventory <- sapply( list.files( wrk_area, pattern = "\\.json$", full.names = FALSE, recursive = FALSE ), function(xfile) {
    digest::digest( file.path( wrk_area, xfile, fsep = "/"), algo = "sha1", file = TRUE )
  }, USE.NAMES = TRUE )    
    
  
  
  
  
  # -- process commit
  
  # - initialize auditing
  
  # note: audit records
  lst_audit_records <- list()
  
  # note: attributes to the snapshot commit record
  lst_audit_spec_attrs <- list()
  

  # - identify source snapshot if different from commit scope
  if ( ( ! "unknown" != snapshot_spec[[ "repository" ]] ) &&
       ( paste(commit_scope, collapse = "/") != paste( snapshot_spec[ c( "repository", "snapshot") ], collapse = "/" ) ) )
    
    #   note: list(list()) to append the entry as a list item
    lst_audit_spec_attrs <- append( lst_audit_spec_attrs, 
                                    list( list( "key" = "snapshot", 
                                                "qualifier" = "source",
                                                "value" = paste( snapshot_spec[ c( "repository", "snapshot") ], collapse = "/" ) ) ) )       
       
  
  
    
  # - force spec file repository and snapshot reference
  snapshot_spec[["repository"]] <- commit_scope[["repository"]]
  snapshot_spec[["name"]] <- commit_scope[["snapshot"]]
  
  
  
  # - initiate commit list
  lst_commit <- character(0)
  
  lst_named_blobs <- character(0)
  
  
  # - process blobs and actions
  lst_files <- list.files( wrk_area, pattern = "\\.json$", full.names = FALSE, recursive = FALSE )
  
  for ( xfile in lst_files ) {
    
    # note: ignore snapshot specification file
    if ( base::startsWith( xfile, "snapshot-" ) )
      next()

    
    # - import blob specification
    blob_spec <- try( jsonlite::fromJSON( file.path( wrk_area, xfile, fsep = "/" )), silent = try_silent )
    
    if ( inherits( blob_spec, "try-error") )
      next()
    
    
    # - process deleted blobs   
    if ( base::startsWith( xfile, "delete-blob-" ) ) {
  
      #   note: list(list()) to append the entry as a list item
      lst_audit_spec_attrs <- append( lst_audit_spec_attrs, 
                                      list( list( "key" = blob_spec[["name"]], 
                                                  "qualifier" = "drop",
                                                  "value" = blob_spec[["sha"]] ) ) )     
      
      next()
    } # end of if-statement for deleted blobs


    # -- conflict ... name should be unique so use first find
    if ( blob_spec[["name"]] %in% lst_named_blobs )
      next()
    
    
    # - add blob to specification
    snapshot_spec[["members"]][[ length(snapshot_spec[["members"]]) + 1 ]] <- blob_spec

    
    # - retain in blob spec
    if ( xfile %in% base::names(prior_inventory) && 
         xfile %in% base::names(commit_inventory) && 
         prior_inventory[ xfile ] == commit_inventory[ xfile ] ) {
    
      #   note: list(list()) to append the entry as a list item
      lst_audit_spec_attrs <- append( lst_audit_spec_attrs, 
                                      list( list( "key" = blob_spec[["name"]], 
                                                  "qualifier" = "include",
                                                  "value" = blob_spec[["sha"]] ) ) )     

      next()
    } 
    
    
    
    # - add blob to commit list

    if ( file.exists( file.path( wrk_area, blob_spec[["blobs"]], fsep = "/" ) ) ) {
      
      # note: since we have a blob .. assuming it is uploaded to the work area
      
      lst_commit <- append( lst_commit, 
                            file.path( wrk_area, blob_spec[["blobs"]], fsep = "/" ) )

      
      # note: audit record information for blob
      
      blob_audit_info <- list( "event" = "commit",
                               "type" = blob_spec[["type"]], 
                               "class" = blob_spec[["class"]],
                               "reference" = blob_spec[["reference"]], 
                               "object" = blob_spec[["sha"]],
                               "label" = paste( "Commit of", blob_spec[["class"]], blob_spec[["reference"]], "as", blob_spec[["name"]], "in snapshot", paste(commit_scope, collapse = "/") ),
                               "actor"  = ifelse( ! is.null(as.actor), as.actor, "unknown" ),
                               "_attributes_" = list() )
      
      
      blob_audit_attrs <- list( list( "key" = "origin", 
                                      "qualifier" = "snapshot", 
                                      "value" = paste(commit_scope, collapse = "/") ) ) 

      
      for ( xkey in c( "sha", "mime", "name") )
        if ( xkey %in% base::names(blob_spec) )
          blob_audit_attrs[[ length(blob_audit_attrs) + 1 ]] <- list( "key" = xkey, 
                                                                      "value" = blob_spec[[ xkey ]] )

      for ( xitem in blob_spec[["blobs"]] )
        blob_audit_attrs[[ length(blob_audit_attrs) + 1 ]] <- list( "key" = "blob", 
                                                                    "value" = xitem )
      
      
      
      blob_audit_info[["_attributes_"]] <- blob_audit_attrs
      
      
      # note: reference is whatever is returned by the commit method 
      lst_audit_records[[ file.path( wrk_area, blob_spec[["blobs"]] ) ]] <- blob_audit_info
      

      # clean up 
      rm( list = c( "blob_audit_info", "blob_audit_attrs") )
      
    }  # end of if-statement on blob
    
    
    
    # - add blob spec to commit list
    lst_commit <- append( lst_commit, 
                          file.path( wrk_area, xfile, fsep = "/" ) )
    

    # - add audit record reference to blob in snapshot audit record
    #   note: list(list()) to append the entry as a list item
    lst_audit_spec_attrs <- append( lst_audit_spec_attrs, 
                                    list( list( "key" = blob_spec[["name"]], 
                                                "qualifier" = "add",
                                                "value" = blob_spec[["sha"]] ) ) )    
    
    
    # - clean up
    base::rm( list = "blob_spec" )
        
  }  #  end of if-statement adding blobs to snapshot spec
  
  
  
  

  # - update snapshot specification 
  
  if ( inherits( try( base::writeLines( jsonlite::toJSON( snapshot_spec, pretty = TRUE, auto_unbox = TRUE ),
                                        con = file.path( wrk_area, snapshot_spec_file, fsep = "/" )), silent = try_silent ), "try-error") )
    stop( "Could not update snapshot specification" )

  
  lst_commit <- append( lst_commit, 
                        file.path( wrk_area, snapshot_spec_file, fsep = "/" ) )
  
  
  
  

  # -- connect with storage
  
  strg <- try( txflow.service::txflow_store(), silent = try_silent )
  
  if ( inherits(strg, "try-error") )
    stop( "Storage not available" )
  
  
  
  

  # -- snapshot commit 

  # - ensure not locked
  if ( strg$is.locked( paste( commit_scope, collapse = "/" ) ) )
    return(invisible(NULL))
  
    
  commit_files <- character(0)


    
  # - add blobs to snapshot commit

  lst_objs <- list.files( wrk_area, full.names = FALSE, recursive = FALSE ) 
  
  lst_blobs <- lst_objs[ base::trimws(tools::file_ext(lst_objs)) == "" ]
  
  
  for ( xblob in snapshot_spec[["members"]] ) {
    

    blob_spec_file <- file.path( wrk_area, paste0( xblob[["blobs"]], ".json"), fsep = "/" )
    
    # - no blob specification ... nothing to do
    if ( ! file.exists( blob_spec_file ) )
      next()
    
    
    # - add blob spec file
    commit_files <- append( commit_files, blob_spec_file )
    
    
    # - add blob
    #   note: blob might be missing if you are adding item by reference
    if ( file.exists( file.path( wrk_area, xblob[["blobs"]], fsep = "/") ) )
      commit_files <- append( commit_files, 
                              file.path( wrk_area, xblob[["blobs"]], fsep = "/") )
    
  }  # end of for-statement for blobs in work area
  
  
  
  # - add spec as last item to commit
  commit_files <- append( commit_files, 
                          file.path( wrk_area, snapshot_spec_file, fsep = "/" ) )
  

    
  lst_audit_records[[ file.path( wrk_area, snapshot_spec_file, fsep = "/" ) ]] <- list( "event" = "commit",
                                                                                        "type" = "datarepository.snapshot", 
                                                                                        "class" = "snapshot",
                                                                                        "reference" = commit_scope[["snapshot"]], 
                                                                                        "object" = digest::digest( paste(commit_scope, collapse = "/"), algo = "sha1", file = FALSE ), 
                                                                                        "label" = paste( "Commit snapshot", commit_scope[["snapshot"]], "to data repository", commit_scope[["repository"]] ),
                                                                                        "actor"  = ifelse( ! is.null(as.actor), as.actor, "unknown" ),
                                                                                        "env" = cfg$option( "service.environment", unset = "txflow" ), 
                                                                                        "_attributes_" = lst_audit_spec_attrs )
  
  
  # - commit 

  commit_rslt <- try( strg$commit( commit_files, repository = commit_scope["repository"], overwrite = TRUE ), silent = try_silent )


  # - auditor

  audit_records <- list()


  for ( xpath in base::names(commit_rslt) ) {

    if ( ! xpath %in% base::names( lst_audit_records) )
      next()

    if ( ! base::tolower(commit_rslt[[ xpath ]]) %in% c( "fail", "replaced", "created" ) )
      next()


    # audit record information
    audit_rec_info <- lst_audit_records[[ xpath ]]

    # update event based on commit result
    audit_rec_info[["event"]] <- ifelse( base::tolower(commit_rslt[[ xpath ]]) %in% c( "replaced", "created"), "commit", "fail" )


    # create main audit record
    audit_rec <- try( cxaudit::cxaudit_record( audit_rec_info[ ! base::startsWith( base::names(audit_rec_info), "_" ) ] ), silent = try_silent )

    if ( inherits( audit_rec, "try-error" ) )
      stop( "Could not create an audit record for blob")

        
    if ( "_attributes_" %in% base::names(audit_rec_info) && ( length(audit_rec_info[["_attributes_"]]) > 0 ) )
      for ( xattr in audit_rec_info[["_attributes_"]] )
        if ( inherits( try( audit_rec$setattribute( xattr[["key"]], 
                                                    value = ifelse( "value" %in% base::names(xattr), xattr[["value"]], ""), 
                                                    label = ifelse( "label" %in% base::names(xattr), xattr[["label"]], xattr[["key"]]),
                                                    qualifier = ifelse( "qualifier" %in% base::names(xattr), xattr[["qualifier"]], "") ), 
                            silent = try_silent ), "try-error" ) )
          stop( "Could not register attributer for audit record")
    
    

    audit_records[[ length(audit_records) + 1 ]] <- audit_rec


    rm( list = c( "audit_rec", "audit_rec_info") )
  }


  audit_commit <- try( cxaudit::cxaudit_commit( audit_records ), silent = try_silent )

  if ( inherits( audit_commit, "try-error") || ! audit_commit )
    stop( "Failed to commit audit records")



  # -- delete commit files
  #    note: crude but for debugging purposes .. for now
  
  commit_fails <- character(0)
  
  for ( xitem in base::names(commit_rslt) ) {
    
    if ( commit_rslt[xitem] %in% c( "replaced", "created" ) ) 
      next()

    # - register as a failed commit
    commit_fails <- append( commit_fails, xitem )
    
  }


  # - check for failed commits
  
  if ( length( commit_fails ) == 0 ) {
    
    unlink( wrk_area, recursive = TRUE, force = TRUE )
    
    if ( ! dir.exists(wrk_area) )
      return(invisible( paste( commit_scope, collapse = "/") ))
  }
  
 
    
  return(invisible(NULL))
}