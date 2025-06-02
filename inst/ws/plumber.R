#
#  REST API for txflow
#
#
#




#* List repositories
#* 
#* @get /api/repositories
#* 
#* @response 200 OK
#* @response 500 Internal Error
#* 

function( req, res ) {

  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  
  # -- list repositories
  
  lst <- try( as.list( txflow.service::txflow_listrepositories() ), silent = FALSE )
  
  if ( inherits( lst, "try-error" ) ) {
    cxapp::cxapp_log("Failed to get list of repositories", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = "Failed to get list of repositories") )    
  }
  
  


  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( lst, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log("List repositories", attr = log_attributes )
  
  
  return(res)
}





#* Create repository
#* 
#* @put /api/repositories/<repo>
#* 
#* @param repo
#* 
#* @response 201 Created
#* @response 400 Bad Request
#* @response 409 Conflict
#* @response 500 Internal Error
#* 

function( repo, req, res ) {
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  
  # -- only API admins can create data repositories

  api_admins <- base::trimws(base::tolower(unlist(strsplit( gsub( "\\s{2,}", " ", cfg$option( "api.admins", unset = "*", as.type = FALSE) ), " ", fixed = TRUE), use.names = FALSE)))
  
  if ( ( api_admins != "*" ) && ! service_principal %in% api_admins ) {
    cxapp::cxapp_log("Not permitted", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Not permitted")
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  
  # -- list snapshots
  
  lst <- try( as.list( txflow.service::txflow_repository( repo, as.actor = service_principal ) ), silent = FALSE )
  
  if ( inherits( lst, "try-error" ) ) {
    cxapp::cxapp_log("Failed to create repository", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = "Failed to create repository") )    
  }
  
  
  
  
  res$status <- 201  # Created
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( lst, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( paste( "Created repository", lst), attr = log_attributes )

  
  return(res)
}



#* List repository snapshots
#* 
#* @get /api/repositories/<repo>/snapshots
#* 
#* @param repo
#* 
#* @response 200 OK
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#* 

function( repo, req, res ) {
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  
  
  # -- list snapshots
  
  lst <- try( as.list( txflow.service::txflow_listsnapshots( repo ) ), silent = FALSE )
  
  if ( inherits( lst, "try-error" ) ) {
    cxapp::cxapp_log("Failed to get list of snapshots", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = "Failed to get list of snapshots") )    
  }
  
  
  
  
  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( lst, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log("List snapshots", attr = log_attributes )
  
  
  return(res)
}










#* Get repository snapshot
#* 
#* @get /api/repositories/<repo>/snapshots/<snapshot>
#* 
#* @param repo
#* @param snapshot
#* 
#* @response 200 OK
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#* 

function( repo, snapshot, req, res ) {
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  # -- get snapshot
  
  lst <- try( txflow.service::txflow_snapshot( paste0(repo, "/", snapshot), as.actor = attr(auth_result, "principal"), audited = TRUE), silent = FALSE )
  
  if ( inherits( lst, "try-error" ) ) {
    cxapp::cxapp_log("Failed to get snapshot specification", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = "Failed to get snapshot specification") )    
  }
  

  if ( is.null(lst) ) {
    cxapp::cxapp_log("Snapshot not found", attr = log_attributes )
    res$status <- 404  # Not Found
    return( list( "error" = "Snapshot specification not found") )    
  }
  
  
  # - temporary: remove list names for snapshot content
  if ( "contents" %in% base::names(lst) && (length(lst[["contents"]]) > 0) )
    lst[["contents"]] <- base::unname(lst[["contents"]])
  
  
  
  
  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(lst), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log("Get repository snapshot", attr = log_attributes )
  

  return(res)
}



#* Get content by repository resource
#*
#* @get /api/repositories/<repo>/<reference>
#*
#* @param repo
#* @param reference
#*
#* @response 200 OK
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#*

function( repo, reference, req, res ) {

  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  # -- get resource
    
  repo_obj <- try( txflow.service::txflow_getresource( base::tolower(paste( repo, reference, sep = "/" )), as.actor = attr(auth_result, "principal") ), silent = FALSE )
  
  if ( inherits( repo_obj, "try-error") ) {
    cxapp::cxapp_log("Failed to get repository resource", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = "Failed to get repository resource") )    
  }
  

  if ( is.null(repo_obj) ) {
    cxapp::cxapp_log("Repository resource not found", attr = log_attributes )
    res$status <- 404  # Not Found
    return( list( "error" = "Repository resource not found") )    
  }
  
  
  

  # -- return resource
  
  cxapp::cxapp_log( paste( "Download resource", reference, "from repository", repo ), attr = log_attributes )

  res$status <- 200  # OK
  res$setHeader( "content-type", "application/octet-stream" )
  res$body <- base::readBin( repo_obj, "raw", n = base::file.info(repo_obj)$size ) 

  return( res )
}





#* Get content by repository snapshot
#*
#* @get /api/repositories/<repo>/snapshots/<snapshot>/<reference>
#*
#* @param repo
#* @param snapshot
#* @param reference
#*
#* @response 200 OK
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#*

function( repo, snapshot, reference, req, res ) {

  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  # -- get resource
  
  repo_obj <- try( txflow.service::txflow_getresource( base::tolower(paste( repo, snapshot, reference, sep = "/" )), as.actor = attr(auth_result, "principal") ), silent = FALSE )
  
  if ( inherits( repo_obj, "try-error") ) {
    cxapp::cxapp_log( "Failed to get repository snapshot resource from snapshot", attr = log_attributes )
    res$status <- 500  # Internal Error
    return( list( "error" = paste( "Failed to get resource from snapshot", snapshot, "in repository", repo ) ) )    
  }
  
  
  if ( is.null(repo_obj) ) {
    cxapp::cxapp_log("Repository snapshot resource not found", attr = log_attributes )
    res$status <- 404  # Not Found
    return( list( "error" = paste( "Resource", reference, "not found in snapshot", snapshot, "of repository", repo ) ) )    
  }
  
  
  
  
  # -- return resource
  
  cxapp::cxapp_log( "Download repository snapshot resource", attr = log_attributes )
  
  res$status <- 200  # OK
  res$setHeader( "content-type", "application/octet-stream" )
  res$body <- base::readBin( repo_obj, "raw", n = base::file.info(repo_obj)$size ) 
  
  return( res )
}





#* Create a working copy
#*
#* @post /api/work
#* 
#* @response 201 Created
#* @response 400 Bad Request
#* @response 500 Internal Error

function( req, res ) {
  
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  

  # -- get work area reference

  attrs <- character(0)
  
  attrs <- append( attrs, 
                   unlist( req$argsBody, use.names = TRUE ) )
  
  # - standardize on lower case 
  base::names(attrs) <- base::tolower(base::names(attrs))
  
  
  snapshot_ref <- NA
  
  
  if ( all( c( "repository", "snapshot" ) %in% base::names(attrs) ) )
    snapshot_ref <- paste( attrs[ c( "repository", "snapshot") ], collapse = "/" )
  
  if ( ! "repository" %in% base::names(attrs) && "snapshot" %in% base::names(attrs) )
    snapshot_ref <- base::unname(attrs["snapshot"])
    

  if ( "repository" %in% base::names(attrs) && ! "snapshot" %in% base::names(attrs) )
    snapshot_ref <- paste( attrs[ "repository" ], "undefined", sep = "/" )
  

  if ( is.na(snapshot_ref) || ! txflow.service::txflow_validname( snapshot_ref, context = "snapshot") ) {
    cxapp::cxapp_log( "Work area request incomplete", attr = log_attributes)
    res$status <- 400  # Bad request
    return(list( "error" = "Missing repository and/or snapshot reference" ))
  }
    
    
  
  # -- create work area
  
  wrk <- try( txflow.service::txflow_workarea( snapshot = snapshot_ref ), silent = FALSE )

  if ( inherits( wrk, "try-error" ) || is.null(wrk) ) {

    msg <- ifelse( is.na(snapshot_ref),
                   "Failed to create empty work area",
                   paste("Failed to create work area associated with snapshot", snapshot_ref ) )

    cxapp::cxapp_log( msg, attr = log_attributes )
    res$status <- 500  # Internal error
    return( list( "error" = msg ) )
  }


  
  res$status <- 201  # Created

  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(wrk), auto_unbox = TRUE, pretty = TRUE )

  cxapp::cxapp_log( ifelse( is.null(snapshot_ref),
                            paste( "Created empty work area", wrk),
                            paste( "Created work area", wrk, "associated with snapshot", snapshot_ref ) ),
                    attr = log_attributes )

  
  return(res)
}




#* List working copies
#*
#* @get /api/work
#* 
#* @response 200 OK
#* @response 500 Internal Error

function( work, req, res ) {
  
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  
  
  # -- list work areas
  
  wrk <- try( txflow.service::txflow_listworkareas(), silent = FALSE )
  
  if ( inherits( wrk, "try-error" ) ) {
    
    msg <- "Failed to list work areas"
    
    cxapp::cxapp_log( msg, attr = log_attributes )
    res$status <- 500  # Internal error
    return( list( "error" = msg ) )
  }
  
  
  
  res$status <- 200  # OK
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(wrk), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "List work areas", attr = log_attributes )
  
  
  return(res)
}



#* Drop a working copy
#*
#* @delete /api/work/<work>
#* 
#* @response 200 OK
#* @response 500 Internal Error

function( work, req, res ) {
  
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  

  # -- drop work area
  
  wrk <- try( txflow.service::txflow_dropworkarea( work ), silent = FALSE )
  
  if ( inherits( wrk, "try-error" ) || ! inherits(wrk, "logical") || ! wrk ) {
    
    msg <- "Failed to drop work area"
    
    cxapp::cxapp_log( msg, attr = log_attributes )
    res$status <- 500  # Internal error
    return( list( "error" = msg ) )
  }
  
  
  
  res$status <- 200  # OK
  
  cxapp::cxapp_log( "Work area dropped", attr = log_attributes )
  
  
  return(list("message" = "Work area dropped"))
}





#* Add content to a working copy
#*
#* @put /api/work/<work>/<reference>
#*
#* @param work
#* @param reference
#* @param f:file
#*
#* @response 201 Created
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#*

function( work, reference, req, res ) {
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  

  if ( ! "HTTP_CONTENT_TYPE" %in% base::names(req) ||
       ( base::tolower(base::trimws(req$HTTP_CONTENT_TYPE)) != "application/octet-stream" ) ) {
    cxapp::cxapp_log("Invalid content type", attr = log_attributes )
    res$status <- 400  # Bad Request
    return( list( "error" = "Content-Type header is not supported" ) )
  }




  # -- process upload

  tmp_file <- base::tempfile( pattern = "txflow-upload-", tmpdir = base::tempdir(), fileext = "" )

  if ( inherits( try( base::writeBin( req$body, tmp_file ), silent = FALSE ), "try-error" ) ||
       ! file.exists( tmp_file ) ) {
    cxapp::cxapp_log( "Unable to save submitted content", attr = log_attributes)
    res$status <- 500  # Internal Error
    return(list("error" = "Unable to process submitted content"))
  }

  
  # -- get query attributes
  
  attrs <- character(0)
  
  attrs <- append( attrs, 
                   unlist( req$argsQuery, use.names = TRUE ) )

  # - force argument names to lower case
  if (  (length(attrs) > 0) && ! is.null(attrs) && ! is.null(base::names(attrs)) )
    base::names(attrs) <- base::tolower(base::names(attrs))
  

  # - url decode bespoke types
  if ( "type" %in% base::names(attrs) )
    attrs["type"] <- base::tolower(base::trimws(utils::URLdecode(attrs["type"])))
  
  
  # - ensure name, reference and mime is associated with upload reference
  
  if ( ! "name" %in% base::names(attrs) )
    attrs["name"] <- base::tolower(base::trimws(reference))

  if ( ! "reference" %in% base::names(attrs) )
    attrs["reference"] <- tools::file_path_sans_ext( base::tolower(base::trimws(reference)) )

  if ( ! "mime" %in% base::names(attrs) )
    attrs["mime"] <- tools::file_ext( base::tolower(base::trimws(reference)) )
  

  # -- add content to work area
  
  rslt <- try( txflow.service::txflow_addfile( tmp_file, work = work, attrs = attrs ), silent = FALSE )
  
  if ( inherits( rslt, "try-error") ) {
    cxapp::cxapp_log( "Failed to save submitted content to work area", attr = log_attributes)
    res$status <- 500  # Internal Error
    return(list("error" = "Failed to save submitted content to work area"))
  }
  
  
  
  
  
  res$status <- 201  # Created
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(rslt), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Content added to work area" , attr = log_attributes )
  
  
  return(res)
}




#* Delete content from a working copy
#*
#* @delete /api/work/<work>/<reference>
#*
#* @param work
#* @param reference
#*
#* @response 200 OK
#* @response 400 Bad Request
#* @response 404 Not Found
#* @response 500 Internal Error
#*

function( work, reference, req, res ) {

  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  # -- drop content in work area
  
  rslt <- try( txflow.service::txflow_dropfile( reference, work = work ), silent = FALSE )
  
  if ( inherits( rslt, "try-error") ) {
    cxapp::cxapp_log( "Failed to drop content from work area", attr = log_attributes)
    res$status <- 500  # Internal Error
    return(list("error" = "Failed to drop content from work area"))
  }
  
  

  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(rslt), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Content droped from work area" , attr = log_attributes )
  
  
  return(res)
}




# PATCH /api/work/<work>/<reference>                                   # adds a blob as it is
# PATCH /api/work/<work>/<reference>?name=<name>                       # adds a blob as named entry
# PATCH /api/work/<work>/<reference>?snapshot=<snapshot>               # adds from reference in snapshot
# PATCH /api/work/<work>/<reference>?snapshot=<snapshot>&name=<name>   # adds as named from reference in snapshot 


#* Add existing content to working copy from another snapshot
#* 
#* @patch /api/work/<work>/<reference>
#* 
#* @param work Working area
#* @param reference Resource reference
#* 
#* @response 201 Created
#* @response 400 Bad Request
#* @response 500 Internal Error

function( work, reference, req, res ) {
  
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  
  # -- get query attributes
  
  qry_lst <- unlist( req$argsQuery, use.names = TRUE ) 
  
  # - force argument names to lower case
  if ( ! is.null(qry_lst) && ! is.null(base::names(qry_lst)) )
    base::names(qry_lst) <- base::tolower(base::names(qry_lst))

  # - map attributes
  attrs <- list( "snapshot" = NULL, 
                 "name" = NULL )

  for ( xattr in base::names(attrs) )
    if ( xattr %in% base::names(qry_lst) )
      attrs[[ xattr ]] <- base::unname(qry_lst[ xattr ])
  
  
  # -- add reference
  
  obj_reference <- reference
  
  if ( "snapshot" %in% base::names(attrs) )
    obj_reference <- paste0( attrs[["snapshot"]], "/", reference )
  
  obj_ref <- try( txflow.service::txflow_addreference( obj_reference, work = work, name = attrs[["name"]] ))
  
  
  if ( inherits( obj_ref, "try-error") ) {
    cxapp::cxapp_log( "Failed to add reference to work area", attr = log_attributes)
    res$status <- 500  # Internal Error
    return(list("error" = "Failed to add reference to work area"))
  }
  
  
  if ( is.null(obj_ref) ) {
    cxapp::cxapp_log( "Requested resource not found", attr = log_attributes)
    res$status <- 404  # Internal Error
    return(list("error" = "Requested resource not found"))
  }
  
    
  
  res$status <- 201  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( as.list(obj_ref), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Resource added to work area" , attr = log_attributes )
  
  
  return(res)
}





# PUT /api/commit/<work>                           # commit as snapshot specification
# PUT /api/commit/<work>?snapshot=<snapshot>       # commit as snapshot


#* Commit a working copy
#*
#* @put /api/commit/<work>
#* 
#* @param work Working area reference
#*
#* @response 201 Created
#* @response 409 Conflict
#* @response 500 Internal Error

function( work, req, res ) {

  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # -- identify authorized service or user 
  service_principal <- ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" )
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", service_principal ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  

  # -- get query attributes
  
  qry_lst <- unlist( req$argsQuery, use.names = TRUE ) 
  
  # - force argument names to lower case
  if ( ! is.null(qry_lst) && ! is.null(base::names(qry_lst)) )
    base::names(qry_lst) <- base::tolower(base::names(qry_lst))
  
  # - map attributes
  attrs <- list( "snapshot" = NULL )

  if ( "snapshot" %in% base::names(qry_lst) )
    attrs[["snapshot"]] <- base::unname(qry_lst["snapshot"])
    


  # -- commit
  
  rslt <- try( txflow.service::txflow_commit( work, snapshot = attrs[["snapshot"]], as.actor = attr(auth_result, "principal") ), silent = FALSE )

  if ( inherits( rslt, "try-error" ) || is.null(rslt) ) {
    cxapp::cxapp_log( "Commit of work area failed", attr = log_attributes)
    res$status <- 409  # Conflict
    return(list("error" = "Commit of work area failed"))
  }
    
  
  
  
  res$status <- 201  # Created
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( list(rslt), auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( paste( "Commit to", rslt, "successful") , attr = log_attributes )
  
  
  return(res)  
}





#* Service information
#* 
#* @get /api/info
#* 
#* @response 200 OK
#* @response 401 Unauthorized
#* @response 403 Forbidden
#* @response 500 Internal Error
#* 

function( req, res ) {
  
  
  cfg <- cxapp::.cxappconfig()
  
  
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  # -- assemble information
  lst <- list( "service" = "txflow", 
               "version" = as.character(utils::packageVersion("txflow.service")), 
               "repositories"  = list() )
  
  
  
  
  # - add txflow configuration details
  
  lst_cfg <- list()
  
  for( xopt in c( "txflow.store", "txflow.data", "txflow.work" ) )
    if ( ! is.na( cfg$option( xopt, unset = NA ) ) )
      lst_cfg[[ xopt ]] <- cfg$option( xopt, unset = "<not set>" )

  lst[["repositories"]][["configuration"]] <- lst_cfg
    
  

  # - add auditor configuration details 
  
  lst[["auditor"]] <- list( "service" = cfg$option( "auditor", unset = "disabled", as.type = FALSE ) )  
  
  if ( cfg$option( "auditor", unset = FALSE ) ) 
    lst[["auditor"]][["configuration"]] <- list( "auditor.environment"= cfg$option( "auditor.environment", unset = as.character(Sys.info()["nodename"]), as.type = FALSE ),
                                                 "auditor.url"= cfg$option( "auditor.url", unset = "<not set>" ), 
                                                 "auditor.token" =  ifelse( is.na(cfg$option( "auditor.token", unset = NA )), "<not set>", "<set>" ), 
                                                 "auditor.failcache"= cfg$option( "auditor.failcache", unset = "<not set>" )
                                                 )

  
  
  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( lst, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "txflow service information", attr = log_attributes )
  
  
  return(res)  
  
}





#* Ping service
#* 
#* @get /api/ping
#* @head /api/ping
#* 
#* @response 200 OK
#* @response 500 Internal Error
#* 

function( req, res ) {
  
  # -- truly OK
  res$status <- 200
  
}


