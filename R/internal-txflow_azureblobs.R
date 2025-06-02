#' An internal reference class representing txflow store using Azure block blob store
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
#' @method exists exists
#' @method is.locked is.locked
#' @method lock lock
#' @method unlock unlock
#' @method commit commit
#' @method show show
#' 
#' @description
#' A collection of internal methods to manage data file and blobs stored using
#' Azure Block Blob storage.
#' 
#' The storage relies on a Microsoft Azure Storage Account with each data 
#' repository represented as a container and data files and blobs stored in the 
#' root of the container. The container is named as the repository name without
#' a prefix making a shared storage account not practical.
#' 
#' The storage uses the following configuration options.
#' 
#' \itemize{
#'   \item `TXFLOW.STORE` equal to `AZUREBLOBS`, case insensitive
#'   \item `AZUREBLOBS.URL` specifying the URL to the blob storage
#' }
#' 
#' Access tokens for storage integration uses Microsoft Azure OAuth 
#' authentication. The Azure REST API calls rely on authorization bearer token.
#' 
#' \itemize{
#'   \item `AZURE.OAUTH.URL` is the Microsoft Azure OAuth URL including the full 
#'         URL path that should include the tenant ID
#'   \item `AZURE.OAUTH.CLIENTID` the client ID associated with the storage account
#'   \item `AZURE.OAUTH.CLIENTSECRET` the client secret associated with the storage 
#'         account
#' }
#' 
#' The scope of the requested access token is `https://storage.azure.com`.
#' 
#' Note that the configuration relies on \link[cxapp]{cxapp_config} that supports
#' environmental variables and secret vaults.
#' 
#' 
#' 

.txflow_azureblobs <- methods::setRefClass( ".txflow_azureblobs", 
                                            fields = list( ".attr" = "list" ) )


.txflow_azureblobs$methods( "initialize" = function() {
  "Initialize"
  
  
  .self$.attr <- list()
  
  
  # -- configuration
  cfg <- cxapp::.cxappconfig()
  
  .self$.attr[["mode.try.silent"]] <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  # -- Azure block blob storage configuration
  if ( base::tolower(cfg$option( "txflow.store", unset = "", as.type = FALSE )) != "azureblobs" )
    stop( "Invalid storage configuration" )
  
  
  for ( xopt in c( "azure.oauth.url", "azure.oauth.clientid", "azure.oauth.clientsecret", "azureblobs.url") )
    if ( is.na( cfg$option( xopt, unset = NA ) ) )
      stop( "Missing configuration options for Azure Block Blob store" )
  
  
  # -- request access token
  
  # - access token
  
  rslt <- try( httr2::request( cfg$option( "azure.oauth.url", unset = NA ) ) |>
                 httr2::req_method("POST") |>
                 httr2::req_body_form( "grant_type" = "client_credentials",
                                       "client_id" = cfg$option( "azure.oauth.clientid", unset = NA ), 
                                       "client_secret" = cfg$option( "azure.oauth.clientsecret", unset = NA ), 
                                       "resource" = "https://storage.azure.com" ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]]  )
  
  
  if ( inherits( rslt, "try-error") || (httr2::resp_status( rslt ) != 200) )
    stop( "Authentication with Azure failed" )
  
  
  lst_token <- try ( httr2::resp_body_json( rslt ), silent = .self$.attr[["mode.try.silent"]] )
  
  .self$.attr[["azure.access.token"]] <- lst_token[["access_token"]]  
  
  
  # -- azure block blob store URL  
  .self$.attr[["azure.blob.url"]] <- cfg$option( "azureblobs.url", unset = NA )
  
  
  # -- internals ... for now
  .self$.attr[["azure.blob.apiversion"]] <- "2023-11-03"
  
  # -- enable cache 
  .self$.attr[["cache"]] <- list()
  
  
})



.txflow_azureblobs$methods( "repositories" = function() {
  "List repositories"
  
  
  # -- query azure for containers ... i.e. repositories
  
  rslt <- try( httr2::request( paste0( .self$.attr[["azure.blob.url"]], "/?comp=list" )) |>
                 httr2::req_method("GET") |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( rslt, "try-error") || (httr2::resp_status(rslt) != 200) )
    return(invisible( character(0) ))
  
  
  xmlobj_containers <- try( httr2::resp_body_xml(rslt), silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( xmlobj_containers, "try-error") )
    return(invisible( character(0) ))
  
  
  # -- extract list of containers
  
  lst_repos <- character(0)
  
  
  lst <- xml2::as_list( xmlobj_containers )
  
  if ( ! "EnumerationResults" %in% base::names(lst) ||
       ! "Containers" %in% base::names(lst[["EnumerationResults"]]) ||
       ( length(lst[["EnumerationResults"]][["Containers"]]) == 0 ) )
    return(invisible( character(0) ))
  
  
  for ( xitem in lst[["EnumerationResults"]][["Containers"]] ) 
    if ( "Name" %in% base::names(xitem) )
      lst_repos <- append( lst_repos, base::unname(xitem[["Name"]][[1]]) )
  
  
  return(invisible( base::sort(lst_repos) ))
})


.txflow_azureblobs$methods( "repository" = function( x, create = FALSE ) {
  "Get a reference to a repository"
  
  if ( ! txflow.service::txflow_validname(x, context = "repository") )
    return(invisible(NULL))
  
  
  # -- list of repositories
  repo_lst <- .self$repositories()
  
  # - return URL to repo container
  if ( base::tolower(base::trimws(x)) %in% repo_lst ) 
    return(invisible( paste0( .self$.attr[["azure.blob.url"]], "/", base::tolower(base::trimws(x)) ) ))
  
  # - repository not exist and create disabled
  if ( ! create )
    return(invisible(NULL))
  
  
  # -- create repository 
  
  rslt <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                 httr2::req_method("PUT") |>
                 httr2::req_url_path( base::tolower(base::trimws(x)) ) |>
                 httr2::req_url_query( "restype" = "container" ) |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT"), 
                                     "Content-length" = "0" ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  
  if ( inherits( rslt, "try-error") || ( httr2::resp_status(rslt) != 201 ) )
    return(invisible(NULL))
  
  
  # -- verify container is visible
  
  # - refresh list of repositories
  repo_lst <- .self$repositories()
  
  # - return URL to created repo container
  if ( base::tolower(base::trimws(x)) %in% repo_lst ) 
    return(invisible( paste0( .self$.attr[["azure.blob.url"]], "/", base::tolower(base::trimws(x)) ) ))
  
  
  # -- fail 
  return(invisible(NULL))  
})


.txflow_azureblobs$methods( "snapshots" = function( x ) {
  "List snapshots of a repository"
  
  if ( ! txflow.service::txflow_validname(x, context = "repository") )
    return(invisible(NULL))
  
  
  # -- list blobs in container 
  
  rslt <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                 httr2::req_method("GET") |>
                 httr2::req_url_path( base::tolower(base::trimws(x)) ) |>
                 httr2::req_url_query( "restype" = "container", 
                                       "comp" = "list", 
                                       "prefix" = "snapshot-") |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  
  if ( inherits( rslt, "try-error") || ( httr2::resp_status(rslt) != 200 ) )
    return(invisible(NULL))
  
  xmlobj_blobs <- httr2::resp_body_xml( rslt )
  
  
  # -- extract list of snapshots
  
  lst_snapshots <- character(0)
  
  
  lst <- xml2::as_list( xmlobj_blobs )
  
  if ( ! "EnumerationResults" %in% base::names(lst) ||
       ! "Blobs" %in% base::names(lst[["EnumerationResults"]]) ||
       ( length(lst[["EnumerationResults"]][["Blobs"]]) == 0 ) )
    return(invisible( character(0) ))
  
  
  for ( xitem in lst[["EnumerationResults"]][["Blobs"]] ) 
    if ( "Name" %in% base::names(xitem) )
      lst_snapshots <- append( lst_snapshots, paste0( base::trimws(x), "/", gsub( "^snapshot-(.*)\\.json$", "\\1", xitem[["Name"]][[1]] ) ) )
  
  
  
  return(invisible(lst_snapshots))
})



.txflow_azureblobs$methods( "snapshot" = function( x, file = NULL ) {
  "Get repository snapshot"
  
  
  if ( ! txflow.service::txflow_validname( x, context = "snapshot" ) )
    return(invisible(NULL))
  
  
  # -- reference
  ref <- base::tolower(base::unlist(base::strsplit( base::tolower(x), "/", fixed = TRUE ), use.names = FALSE ))
  base::names(ref) <- c( "repository", "snapshot" )
  
  # - object ceche reference
  obj_cacheref <- paste0( "snapshot:specification:", paste( ref[ c( "repository", "snapshot") ], collapse = ":") )
  
  
  
  # -- retrieve snapshot file
  
  snapshot_blob <- paste0( "snapshot-", ref["snapshot"] , ".json" )
  
  rslt <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                 httr2::req_method("GET") |>
                 httr2::req_url_path( ref["repository"] ) |>
                 httr2::req_url_path_append( snapshot_blob ) |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( rslt, "try-error") || ( httr2::resp_status(rslt) != 200 ) )
    return(invisible(NULL))
  
  
  # - temporary file
  
  tmp_file <- gsub( "\\\\", "/", base::tempfile( pattern = "temp-work-", tmpdir = base::tempdir(), fileext = "" ) )
  
  if ( inherits( try( base::writeBin( httr2::resp_body_raw(rslt), tmp_file), silent = .self$.attr[["mode.try.silent"]]), "try-error" ) ||
       ! file.exists( tmp_file ) )
    return(invisible(NULL))
  
  base::names(tmp_file) <- obj_cacheref
  
  
  # - register spec with application cache
  
  appcache <- cxapp::.cxappcache()
  
  if ( appcache$exists( obj_cacheref ) )
    appcache$drop( obj_cacheref )
  
  appcache$add(tmp_file)
  
  
  # - remove temp file
  base::unlink( tmp_file, recursive = FALSE, force = TRUE )
  
  
  return(invisible( appcache$get( obj_cacheref ) ))
})



.txflow_azureblobs$methods( "getresource" = function( x ) {
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
  
  
  
  # -- as a snapshot resource
  
  if ( "snapshot" %in% base::names(resource_spec) ) {
    
    resource_blob <- NA
    
    snapshot_spec <- try( jsonlite::fromJSON( .self$snapshot( paste( resource_spec[ c( "repository", "snapshot") ], collapse = "/" ) ), 
                                              simplifyVector = FALSE ),
                          silent = .self$.attr[["mode.try.silent"]] )
    
    if ( inherits( snapshot_spec, "try-error") ||
         ! "members" %in% base::names(snapshot_spec) ||
         ( length(snapshot_spec[["members"]]) == 0  ) )
      return(invisible(NULL))
    
    for ( xentry in snapshot_spec[["members"]] ) 
      if ( resource_spec[["resource"]] %in% xentry[ c( "blobs", "name" ) ] ) {
        resource_blob <- xentry[["blobs"]]
        break()
      }
    
    
    # - resource as member of snapshot not identified
    if ( is.na(resource_blob) )
      return(invisible(NULL))
    
    
    resource_spec["resource"] <- resource_blob
    
  }  #  end of if-statement when snapshot resource
  
  
  # -- at this point .. should have repository and resource resolved
  
  # -- cache object
  #    note: format resource:<repository>:<resource>
  obj_cacheref <- paste0( "resource:", paste( resource_spec[ c( "repository", "resource" ) ], collapse = ":" ) )
  
  
  # -- retrieve resource at repository level
  rslt <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                 httr2::req_method("GET") |>
                 httr2::req_url_path( resource_spec["repository"] ) |>
                 httr2::req_url_path_append( resource_spec["resource"] ) |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( rslt, "try-error") || ( httr2::resp_status(rslt) != 200 ) )
    return(invisible(NULL))
  
  
  # - temporary file
  
  tmp_file <- gsub( "\\\\", "/", base::tempfile( pattern = "temp-work-", tmpdir = base::tempdir(), fileext = "" ) )
  
  if ( inherits( try( base::writeBin( httr2::resp_body_raw(rslt), tmp_file), silent = .self$.attr[["mode.try.silent"]]), "try-error" ) ||
       ! file.exists( tmp_file ) )
    return(invisible(NULL))
  
  base::names(tmp_file) <- obj_cacheref
  
  
  
  # - register resource with application cache
  
  appcache <- cxapp::.cxappcache()
  
  if ( appcache$exists( obj_cacheref ) )
    appcache$drop( obj_cacheref )
  
  appcache$add(tmp_file)
  
  
  # - remove temp file
  base::unlink( tmp_file, recursive = FALSE, force = TRUE )
  
  
  return(invisible( appcache$get( obj_cacheref ) ))
})



.txflow_azureblobs$methods( "getreference" = function( x ) {
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
  
  
  
  # -- as a snapshot resource
  
  if ( "snapshot" %in% base::names(resource_spec) ) {
    
    resource_blob <- NA
    
    snapshot_spec <- try( jsonlite::fromJSON( .self$snapshot( paste( resource_spec[ c( "repository", "snapshot") ], collapse = "/" ) ), 
                                              simplifyVector = FALSE ), 
                          silent = .self$.attr[["mode.try.silent"]] )
    
    if ( inherits( snapshot_spec, "try-error") ||
         ! "members" %in% base::names(snapshot_spec) ||
         ( length(snapshot_spec[["members"]]) == 0  ) )
      return(invisible(NULL))
    

    for ( xentry in snapshot_spec[["members"]] ) {
      
      #  print(xentry)
      
      if ( resource_spec[["resource"]] %in% xentry[ c( "blobs", "name" ) ] ) {
        resource_blob <- xentry[["blobs"]]
        break()
      }
    }
    
    # - resource as member of snapshot not identified
    if ( is.na(resource_blob) )
      return(invisible(NULL))
    
    
    resource_spec["resource"] <- resource_blob
    
  }  #  end of if-statement when snapshot resource
  
  
  # -- at this point .. should have repository and resource resolved
  
  # -- cache object
  #    note: format resource:<repository>:<resource>
  obj_cacheref <- paste0( "reference:", paste( resource_spec[ c( "repository", "resource" ) ], collapse = ":" ) )
  
  
  # -- retrieve resource at repository level
  rslt <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                 httr2::req_method("GET") |>
                 httr2::req_url_path( resource_spec["repository"] ) |>
                 httr2::req_url_path_append( paste0( resource_spec["resource"], ".json" ) ) |>
                 httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                 httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                     "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                 httr2::req_perform(), 
               silent = .self$.attr[["mode.try.silent"]] )
  
  if ( inherits( rslt, "try-error") || ( httr2::resp_status(rslt) != 200 ) )
    return(invisible(NULL))
  
  
  # - temporary file
  
  tmp_file <- gsub( "\\\\", "/", base::tempfile( pattern = "temp-work-", tmpdir = base::tempdir(), fileext = "" ) )
  
  if ( inherits( try( base::writeBin( httr2::resp_body_raw(rslt), tmp_file), silent = .self$.attr[["mode.try.silent"]]), "try-error" ) ||
       ! file.exists( tmp_file ) )
    return(invisible(NULL))
  
  base::names(tmp_file) <- obj_cacheref
  
  
  
  # - register resource with application cache
  
  appcache <- cxapp::.cxappcache()
  
  if ( appcache$exists( obj_cacheref ) )
    appcache$drop( obj_cacheref )
  
  appcache$add(tmp_file)
  
  
  # - remove temp file
  base::unlink( tmp_file, recursive = FALSE, force = TRUE )
  
  
  return(invisible( appcache$get( obj_cacheref ) ))  
  
  
})



.txflow_azureblobs$methods( "exists" = function( x ) {
  "Resource exists"
  
  if ( ! txflow.service::txflow_validname(x) )
    return(invisible(FALSE))
  
  
  # -- repository level
  if ( ! grepl( "/", x ) )
    return(invisible( ! is.null(.self$repository(x)) ))
  
  
  # -- snapshot level
  
  lst_snapshots <- .self$snapshots( gsub( "^(.*)/.*", "\\1", x) )
  
  return(invisible( all( base::tolower(base::trimws(x)) %in% lst_snapshots ) ))
})



.txflow_azureblobs$methods( "is.locked" = function( x ) {
  "Assert if snapshot is locked"
  return(invisible(FALSE))
})


.txflow_azureblobs$methods( "lock" = function( x ) {
  "Lock snapshot"
  stop("Not implemented")
})


.txflow_azureblobs$methods( "unlock" = function( x ) {
  "Unlock snapshot"
  stop("Not implemented")
})



.txflow_azureblobs$methods( "commit" = function( x, repository = NULL, overwrite = FALSE ) {
  "Commit files to repository"
  
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character" ) ||
       (length(x) == 0) || any(base::trimws(x) == "") || ! all(file.exists(x)) )
    return(invisible(NULL))
  
  
  # -- repo url
  repo_url <- .self$repository( repository )
  
  if ( is.null(repo_url) )
    return(invisible(NULL))
  
  
  # -- results
  rslt <- base::rep_len( "not done", length(x) )
  base::names(rslt) <- x
  
  
  
  # -- repository contents
  lst_blobs <- character(0)
  
  
  rslt_blobs <- try( httr2::request( .self$.attr[["azure.blob.url"]] ) |>
                       httr2::req_method("GET") |>
                       httr2::req_url_path( base::tolower(base::trimws(repository)) ) |>
                       httr2::req_url_query( "restype" = "container", 
                                             "comp" = "list" ) |>
                       httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                       httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]], 
                                           "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT") ) |>
                       httr2::req_perform(), 
                     silent = .self$.attr[["mode.try.silent"]] )
  
  
  if ( ! inherits( rslt_blobs, "try-error") || ( httr2::resp_status(rslt_blobs) == 200 ) ) {
    
    # - extract list of blobs
    
    lst_xmlobj <- xml2::as_list( httr2::resp_body_xml( rslt_blobs ) )
    
    if ( "EnumerationResults" %in% base::names(lst_xmlobj) ||
         "Blobs" %in% base::names(lst_xmlobj[["EnumerationResults"]]) ||
         ( length(lst_xmlobj[["EnumerationResults"]][["Blobs"]]) > 0 ) ) 
      for ( xitem in lst_xmlobj[["EnumerationResults"]][["Blobs"]] ) 
        if ( "Name" %in% base::names(xitem) )
          lst_blobs <- append( lst_blobs, xitem[["Name"]][[1]] )
    
    
    base::rm( list = c( "rslt_blobs", "lst_xmlobj" ) )
    
  }
  
  
  
  # -- check conflicts 
  
  if ( ! overwrite && (length(lst_blobs) > 0) ) 
    for ( xpath in x ) 
      if ( base::tolower(base::basename(xpath)) %in% lst_blobs )
        rslt[[ xpath ]] <- "conflict"
  
  
  if ( any( rslt == "conflict") )
    return(invisible(rslt))
  
  
  
  
  # -- commit blobs
  
  for ( xpath in x ) {
    
    if ( ! file.exists( xpath ) )
      next()
    
    # - commit file
    
    rslt_xpath <- try( httr2::request( abc$.attr[["azure.blob.url"]] ) |>
                         httr2::req_method("PUT") |>
                         httr2::req_url_path( base::tolower(base::trimws(repository)) ) |>
                         httr2::req_url_path_append( base::basename(xpath) ) |>
                         httr2::req_auth_bearer_token( .self$.attr[["azure.access.token"]] ) |>
                         httr2::req_headers( "x-ms-version" = .self$.attr[["azure.blob.apiversion"]],
                                             "x-ms-date" = format( as.POSIXct(Sys.time(), tz = "UTC"), format = "%a, %d %b %Y %H:%M:%S GMT"), 
                                             "x-ms-blob-type" = "BlockBlob",
                                             "Content-type" = "application/octet-stream",
                                             "Content-length" = file.size(xpath),
                                             "Content-MD5" = base64enc::base64encode(digest::digest( xpath, algo = "md5", file = TRUE, raw = TRUE )) ) |>
                         httr2::req_body_file( xpath ) |>
                         httr2::req_perform(),
                       silent = .self$.attr[["mode.try.silent"]] )
    
    
    
    if ( inherits( rslt_xpath, "try-error") || ( httr2::resp_status(rslt_xpath) != 201 ) ) {
      rslt[ xpath ] <- "fail"
      rm( list = "rslt_xpath" )
      next()
    } 
    
    
    rslt[ xpath ] <- ifelse( base::basename(xpath) %in% lst_blobs, "replaced", "created" )
    
    rm( list = "rslt_xpath" )
    
  }  # end of for-statement for each file   
  
  
  return(invisible(rslt))
  
})



.txflow_azureblobs$methods( "show" = function( x ) {
  "Display storage information"
  
  cat( c( "Azure Block Blob store", 
          paste0( "(", .self$.attr[["azure.blob.url"]], ")" ) ), sep = "\n" )
})

