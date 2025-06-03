#' A reference class representing txflow store using the local file system
#' 
#' @field .attr Internal storage of configuration attributes
#' 
#' @method initialize initialize
#' @method repositories repositories
#' @method repository repository
#' @method snapshots snapshots
#' @method snapshot snapshot
#' @method getresource getresource
#' @method getreference getreference
#' @method show show
#' 
#' @description
#' A collection of internal methods to manage data file and blobs stored using
#' the local file system.
#' 
#' The storage relies on the local file sysmte with each data repository 
#' represented as a directory and data files and blobs stored in the 
#' root of the repository directory. The directory is named as the repository 
#' name without a prefix making using the repository parent directory a 
#' shared storage area not practical.
#' 
#' The storage uses the following configuration options.
#' 
#' \itemize{
#'   \item `TXFLOW.STORE` equal to `LOCAL`, case insensitive
#'   \item `TXFLOW.DATA` specifying the parent directory for repositories
#' }
#' 
#' 
#' 




.txflow_fsstore <- methods::setRefClass( ".txflow_fsstore", 
                                        fields = list( ".attr" = "list" ) )



.txflow_fsstore$methods( "initialize" = function() {
  "Initialize"
  
  # -- initialize
  .self$.attr <- list()
  
  
  # -- configuration 
  cfg <- cxapp::.cxappconfig()
  
  .self$.attr[["mode.try.silent"]] <- ! cfg$option( "mode.debug", unset = FALSE )

  
  if ( base::tolower(base::trimws(cfg$option("txflow.store", unset = "not-defined"))) != "local" )
    stop( "Invalid storage configuration")

  
  
  # -- repository root path
  
  .self$.attr[["repository.root"]] <- gsub( "\\\\", "/", cfg$option( "txflow.data", unset = base::tempdir() ) )

  if ( ! dir.exists(.self$.attr[["repository.root"]]) )
    stop( "Storge directory does not exist" )
  
  
  
  # -- repository work area
  
  # wrk <- cfg$option( "txflow.work", unset = NA )
  # 
  # if ( is.na(wrk) ) {
  #   
  #   wrk <- base::tempfile( pattern = "txflow-work-", tmpdir = base::tempdir(), fileext = "" )
  #   
  #   if ( ! dir.exists(wrk) && ! dir.create(wrk, recursive = TRUE) )
  #     stop( "Could not create temporary work area" )
  # }
  #   
  # .self$.attr[["repository.work"]] <- gsub( "\\\\", "/", wrk )
  
})




.txflow_fsstore$methods( "repositories" = function() {
  "List repositories"
  
  if ( ! dir.exists( .self$.attr[["repository.root"]] ) )
    return(invisible(character(0)))
  
  # -- list directories in repo root
  lst <- list.dirs( .self$.attr[["repository.root"]], recursive = FALSE, full.names = FALSE )

  # -- process directories
  lst_repos <- character(0)
  
  for ( xitem in lst ) 
    if ( txflow.service::txflow_validname( xitem ) )
      lst_repos <- append( lst_repos, xitem )

    
  return(invisible(lst_repos))
})


.txflow_fsstore$methods( "repository" = function( x, create = FALSE ) {
  "Get a reference to a repository"
  
  if ( ! txflow.service::txflow_validname(x, context = "repository") )
    return(invisible(NULL))

  
  # -- repository path
  xpath <- file.path( .self$.attr[["repository.root"]], base::tolower(base::trimws(x)), fsep = "/" )
  
  if ( ! dir.exists(xpath) && create && ! dir.create( xpath, recursive = TRUE ) )
    return(invisible(NULL))

  
  if ( ! dir.exists( xpath ) )
    return(invisible(NULL))
  
  
  
  return(invisible(xpath))
})



.txflow_fsstore$methods( "snapshots" = function( repository ) {
  "List snapshots of a repository"
  
  # -- repository path
  xpath <- .self$repository( repository, create = FALSE )

  if ( is.null(xpath))
    return(invisible(list()))
  

  # -- list snapshot files
  lst <- base::tolower( list.files( xpath, 
                                    pattern = "^snapshot-.*\\.json$", 
                                    recursive = FALSE,
                                    full.names = FALSE, include.dirs = FALSE ) )
    

  lst_snapshots <- gsub( "^snapshot\\-(.*)\\.json$", "\\1", lst, ignore.case = TRUE )

  
  return(invisible(lst_snapshots))
})



.txflow_fsstore$methods( "snapshot" = function( x, file = NULL ) {
  "Get repository snapshot"

  if ( ! txflow.service::txflow_validname( x, context = "snapshot" ) )
    return(invisible(NULL))
  
  
  # -- reference
  ref <- base::tolower(base::unlist(base::strsplit( x, "/", fixed = TRUE ), use.names = FALSE ))
  base::names(ref) <- c( "repository", "snapshot" )
  

  # -- repository path
  xpath_repo <- .self$repository( ref["repository"], create = FALSE )
  
  if ( is.null(xpath_repo))
    return(invisible(NULL))
  
  
  # -- snapshot file
  xpath_snapshot <- file.path( xpath_repo, 
                               paste0( "snapshot-", ref["snapshot"], ".json" ),
                               fsep = "/" )
  

  # -- update snapshot

  if ( ! is.null(file) ) {
    
    if ( ! file.exists(file) )
      return(invisible(NULL))

    
    # - staging area
    tmp_dir <- base::tempfile( pattern = "tmp-work-", tmpdir = base::tempdir(), fileext = "" )
    
    if ( ! dir.exists(tmp_dir) && ! dir.create(tmp_dir, recursive = TRUE) )
      return(invisible(NULL))
    
        
    if ( ! file.copy( file, tmp_dir, copy.mode = FALSE, copy.date = FALSE )  )
      return(invisible(NULL))
    
    if ( ( base::tolower(base::basename(file)) != base::tolower(base::basename(xpath_snapshot)) ) &&
         ! file.rename( file.path( tmp_dir, base::tolower(base::basename(file)), fsep = "/" ), 
                        file.path( tmp_dir, base::tolower(base::basename(xpath_snapshot)), fsep = "/" ) ) )
      return(invisible(NULL))

    
    # - add file repository
    
    if ( ! file.copy( file.path( tmp_dir, base::tolower(base::basename(xpath_snapshot)), fsep = "/" ), 
                      xpath_repo, 
                      overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE ) )
      return(invisible(NULL))
    
        
    # - clean temporary directory
    base::unlink( tmp_dir, recursive = TRUE, force = TRUE )
    
  }  # end of if-statement for file not null
  

  
  # -- stage snapshot 
  
  if ( ! file.exists( xpath_snapshot ) )
    return(invisible(NULL))
  
  
  # - stage directory to transfer control of snapshot file
  tmp_tx <- gsub( "\\\\", "/", base::tempfile( pattern = ".txflow-tmp-", tmpdir = base::tempdir(), fileext = "" ) )
  
  if ( ! dir.exists(tmp_tx) && ! dir.create(tmp_tx, recursive = TRUE) )
    return(invisible(NULL))

  if ( ! file.copy( xpath_snapshot, tmp_tx, overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE ) )
    return(invisible(NULL))
  
  
  return(invisible(file.path( tmp_tx, base::basename(xpath_snapshot), fsep = "/")))
})




.txflow_fsstore$methods( "getresource" = function( x ) {
  "Get resource"

    
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") ||
       (length(x) != 1) || (base::trimws(x) == "") )
    return(invisible(NULL))
  
  
  # -- parse resource
  #    note: repository resource ... format <repository>/<blob>
  #    note: via snapshot ... format <repository>/<snapshot>/<file or resource>
  resource_spec <- base::tolower(base::trimws(unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE)))
  
  if ( ! length(resource_spec) %in% c( 2, 3 ) )
    return(invisible(NULL))
  

  if ( length(resource_spec) == 2 )
    base::names(resource_spec) <- c( "repository", "resource" )   
  else
    base::names(resource_spec) <- c( "repository", "snapshot", "resource" ) 
  

  
  # -- repository root
  repo_path <- .self$.attr[["repository.root"]]

  
  # -- application cache
  appcache <- cxapp::.cxappcache()


  
  
  # -- as a resource blob
  
  if ( ! "snapshot" %in% base::names(resource_spec) ) {

    # - blob reference in the cache
    obj_cacheref <- paste0( "resource:", paste( resource_spec[ c( "repository", "resource") ], collapse = ":") )
    
    
    # - blob already in the cache  
    if ( appcache$exists( obj_cacheref ) )
      return(invisible( appcache$get( obj_cacheref) ))
    
    
    # - repository blob path
    # note: we are only expecting repository and resource in resource_spec
    xpath_obj <- file.path( repo_path, paste( resource_spec, collapse = "/"), fsep = "/" )


    # - resource blob does not exist in repository
    if ( ! file.exists( xpath_obj) )
      return(invisible(NULL))


    # - add blob to application cache  
    lst <- xpath_obj
    names(lst) <- obj_cacheref

    appcache$add( lst )
    
    # - return path to cached blob
    return(invisible( appcache$get( obj_cacheref) ))
  } 
  

   
  
  # -- as a snapshot named item 
  snapshot_file <- try( .self$snapshot( paste( resource_spec[ c( "repository", "snapshot") ], collapse = "/" ) ), silent = .self$.attr[["mode.try.silent"]] )
  
  # - snapshot specification does not exist ... so cannot contain reference
  if ( inherits(snapshot_file, "try-error") ) {
    cxapp::cxapp_logerr(snapshot_file)
    return(invisible(NULL))
  }
  
  # - snapshot specification
  snapshot_spec <- try( jsonlite::fromJSON(snapshot_file), silent = .self$.attr[["mode.try.silent"]] )

  if ( inherits(snapshot_spec, "try-error") ) {
    cxapp::cxapp_logerr( snapshot_spec )
    return(invisible(NULL))
  }
  
  
  
  if ( ! "members" %in% base::names(snapshot_spec) )
    return(invisible(NULL))
       
  
  # - look for blob reference in contents

  for ( xentry in snapshot_spec[["members"]] ) {
    
    # note: cannot resolve blob 
    if ( ! "blobs" %in% base::names(xentry) )
      next()

             
    # note: object reference is <repository>/<blob>
    for ( srch in c( "name", "blobs") )
      if ( srch %in% base::names(xentry) && ( resource_spec["resource"] == xentry[[srch]] ) ) 
        return(invisible( .self$getresource( paste( resource_spec[ "repository" ], xentry[["blobs"]], sep = "/" ) ) ))        

  }  # end for-statement for entries in contents
         
  

  # -- if we get here .. the resource does not exist
  return(invisible(NULL))
})





.txflow_fsstore$methods( "getreference" = function( x ) {
  "Get resource reference"
  
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") ||
       (length(x) != 1) || (base::trimws(x) == "") )
    return(invisible(NULL))
  
  
  # -- parse resource
  #    note: repository resource ... format <repository>/<blob>
  #    note: via snapshot ... format <repository>/<snapshot>/<file or resource>
  resource_spec <- base::tolower(base::trimws(unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE)))
  
  if ( ! length(resource_spec) %in% c( 2, 3 ) )
    return(invisible(NULL))
  
  
  if ( length(resource_spec) == 2 )
    base::names(resource_spec) <- c( "repository", "resource" )   
  else
    base::names(resource_spec) <- c( "repository", "snapshot", "resource" ) 
  
  
  
  # -- repository root
  repo_path <- .self$.attr[["repository.root"]]
  
  
  # -- application cache
  appcache <- cxapp::.cxappcache()
  
  
  
  
  # -- as a resource blob
  
  if ( ! "snapshot" %in% base::names(resource_spec) ) {
    
    # - blob reference in the cache
    obj_cacheref <- paste0( "reference:", paste( resource_spec[ c( "repository", "resource") ], collapse = ":") )
    
    
    # - blob already in the cache  
    if ( appcache$exists( obj_cacheref ) )
      return(invisible( appcache$get( obj_cacheref) ))
    
    
    # - repository blob path
    # note: we are only expecting repository and resource in resource_spec
    xpath_obj <- file.path( repo_path, paste0( paste( resource_spec, collapse = "/"), ".json"), fsep = "/" )
    
    
    # - resource blob does not exist in repository
    if ( ! file.exists( xpath_obj) )
      return(invisible(NULL))
    
    
    # - add blob to application cache  
    lst <- xpath_obj
    names(lst) <- obj_cacheref
    
    appcache$add( lst )
    
    # - return path to cached blob
    return(invisible( appcache$get( obj_cacheref) ))
  } 
  
  
  
  
  # -- as a snapshot named item 
  snapshot_file <- try( .self$snapshot( paste( resource_spec[ c( "repository", "snapshot") ], collapse = "/" ) ), silent = .self$.attr[["mode.try.silent"]] )
  
  # - snapshot specification does not exist ... so cannot contain reference
  if ( inherits(snapshot_file, "try-error") )
    return(invisible(NULL))
  
  # - snapshot specification
  snapshot_spec <- try( jsonlite::fromJSON(snapshot_file), silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits(snapshot_spec, "try-error") ) {
    cxapp::cxapp_logerr(snapshot_spec)
    return(invisible(NULL))
  }
  
  
  
  if ( ! "members" %in% base::names(snapshot_spec) )
    return(invisible(NULL))
  
  
  # - look for blob reference in contents
  
  for ( xentry in snapshot_spec[["members"]] ) {
    
    # note: cannot resolve blob 
    if ( ! "blobs" %in% base::names(xentry) )
      next()
    
    
    # note: object reference is <repository>/<blob>
    for ( srch in c( "name", "blobs") )
      if ( srch %in% base::names(xentry) && ( resource_spec["resource"] == xentry[[srch]] ) ) 
        return(invisible( .self$getreference( paste( resource_spec[ "repository" ], xentry[["blobs"]], sep = "/" ) ) ))        
    
  }  # end for-statement for entries in contents
  
  
  
  # -- if we get here .. the resource does not exist
  return(invisible(NULL))
})







.txflow_fsstore$methods( "exists" = function( x ) {
  "Resource exists"

  if ( ! txflow.service::txflow_validname(x) )
    return(invisible(FALSE))

  # -- repository level
  if ( ! grepl( "/", x ) )
    return(invisible( dir.exists( file.path( .self$.attr[["repository.root"]], base::tolower(base::trimws(x)), fsep = "/" ) )  ))
  
    
  # -- snapshot level
  ref <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE )
  base::names(ref) <- c( "repository", "snapshot" )
  
  return(invisible( file.exists( file.path( .self$.attr[["repository.root"]], 
                                            ref[["repository"]], 
                                            paste0( "snapshot-", ref[["snapshot"]], ",json"), fsep = "/") ) ))
})
  


.txflow_fsstore$methods( "is.locked" = function( x ) {
  "Assert if snapshot is locked"
  
  if ( ! txflow.service::txflow_validname(x, context = "snapshot" ) )
    stop( "Invalid snapshot reference" )
  
  
  # -- lock file
  
  ref <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE )
  base::names(ref) <- c( "repository", "snapshot" )
  
  return(invisible( file.exists( file.path( .self$.attr[["repository.root"]], 
                                            ref[["repository"]], 
                                            paste0( "snapshot-", ref[["snapshot"]], ",lck"), fsep = "/") ) ))
  
})


.txflow_fsstore$methods( "lock" = function( x ) {
  "Lock snapshot"

  if ( ! txflow.service::txflow_validname(x, context = "snapshot" ) )
    stop( "Invalid snapshot reference" )
  
  if ( .self$is.locked(x) )
    return(invisible(TRUE))
  

  # -- snapshot reference 
  
  ref <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE )
  base::names(ref) <- c( "repository", "snapshot" )
  

  # -- spec file
  
  spec_file <- file.path( .self$.attr[["repository.root"]], 
                          ref[["repository"]], 
                          paste0( "snapshot-", ref[["snapshot"]], ".json"), fsep = "/")
  
  
  spec_hash <- digest::digest( spec_file, algo = "sha1", file = TRUE )



  # -- lock file

  lck_file <- paste8( tools::file_path_sans_ext(spec_file), ".lck" )
  
  if ( ! inherits( try( writeLines( spec_hash, con = lck_file ), silent = .self$.attr[["mode.try.silent"]] ), "try-error" ) && file.exists(lck_file) )
    return(invisible(TRUE))
  
  

  # -- if nothing else happens .. no lock   
  return(invisible(FALSE))
})




.txflow_fsstore$methods( "unlock" = function( x ) {
  "Unlock snapshot"
  
  
  if ( ! txflow.service::txflow_validname(x, context = "snapshot" ) )
    stop( "Invalid snapshot reference" )
  
  if ( ! .self$is.locked(x) )
    return(invisible(TRUE))
  
  
  # -- snapshot reference 
  
  ref <- unlist(strsplit( x, "/", fixed = TRUE), use.names = FALSE )
  base::names(ref) <- c( "repository", "snapshot" )
  
  
  # -- lock file
  
  lck_file <- file.path( .self$.attr[["repository.root"]], 
                          ref[["repository"]], 
                          paste0( "snapshot-", ref[["snapshot"]], ".lck"), fsep = "/")
  
  
  # -- unlock 
  
  base::unlink( lck_file, recursive = FALSE, force = TRUE )

  if ( ! file.exists(lck_file) )
    return(invisible(TRUE))
  

  
  # -- if nothing else happens .. no lock   
  return(invisible(FALSE))  
  
})



.txflow_fsstore$methods( "commit" = function( x, repository = NULL, overwrite = FALSE ) {
  "Commit files to repository"
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character" ) ||
       (length(x) == 0) || any(base::trimws(x) == "") || ! all(file.exists(x)) )
    return(invisible(NULL))
  
  
  # -- repository path
  
  repo_path <- try( .self$repository( repository ), silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( repo_path, "try-error" ) ) {
    cxapp::cxapp_logerr(repo_path)
    return(invisible(NULL))
  }

  
  rslt <- base::rep_len( "not done", length(x) )
  base::names(rslt) <- x
  
  for ( xpath in x ) {

    trgt_path <- file.path( repo_path, base::basename(xpath), fsep = "/" )
    trgt_exists <- file.exists(trgt_path)    
    
    if ( ! overwrite && trgt_exists )
      next()

    
    if ( ! file.copy( xpath, repo_path, overwrite = overwrite, copy.mode = FALSE, copy.date = FALSE ) ) {
      rslt[ xpath ] <- "failed"
      next()
    }


    rslt[ xpath ] <- ifelse( trgt_exists, "replaced", "created" )
        
    base::rm( list = c( "trgt_path", "trgt_exists") )

  }  # end of for-statement for each file to commit

  
    
  return(invisible(rslt))
})






.txflow_fsstore$methods( "show" = function( x ) {
  "Display storage information"
  
  cat( c( "Flow data repository local storage service", 
          paste0( "(", .self$.attr[["repository.root"]] , ")" ) ),
       sep = "\n" )
  
})