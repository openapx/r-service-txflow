#' Start txflow service
#' 
#' @param port Service port
#' 
#' 
#' @description
#' A standard configurable start for plumber.
#' 
#' The function searches for `plumber.R` in the following directories
#' \itemize{
#'   \item current working directory
#'   \item directory `inst/ws` in the current working directory (development mode)
#'   \item directory `ws` in the current working directory (installed)
#'   \item directory `ws` in the first occurrence of `txflow.service` in the library tree
#' }
#' 
#' 
#' Note that the above configuration uses \link[cxapp]{cxapp_config} and supports
#' both environmental variables and key vaults.
#' 
#' 
#' 
#' @export 

start <- function( port = 12345 ) {
  
  
  # -- default log attributes

  cxapp::cxapp_log( paste0("Starting API session (listen port ", as.character(port), ")" ) )

    
  # -- set up search locations for the plumber
  # note: start looking in ws under working directory and then go looking in .libPaths()
  xpaths <- c( file.path(getwd(), "plumber.R"),
               file.path(getwd(), "inst", "ws", "plumber.R"),
               file.path(getwd(), "ws", "plumber.R"),
               file.path( .libPaths(), "txflow.service", "ws", "plumber.R" ) )
  
  # -- first one will do nicely  
  xplumb <- utils::head( xpaths[ file.exists(xpaths) ], n = 1 )
  
  if ( length( xplumb ) == 0 )
    stop( "Could not find plumber.R file " )
  
  # -- start ... defaults for now
  api <- plumber::pr( xplumb )
  
  plumber::pr_run( api, 
                   port = Sys.getenv("API_PORT", unset = port ), 
                   quiet = TRUE )
  

  
}