#' Internal function to return a default snapshot specification
#' 
#' @param x Snapshot
#' 
#' @return A named list representing a defualt specification
#' 
#' @keywords internal

.txflow_defaultsnapshot <- function(x) {
  
  if ( ! txflow.service::txflow_validname(x, context = "snapshot" ) )
    stop( "Snapshot reference missing or invalid" )
  
  
  spec <- unlist( strsplit( x, "/", fixed = TRUE ), use.names = FALSE )
  base::names(spec) <- c( "repository", "snapshot" )
  
  
  def <- list( "version" = "1.0.0", 
               "name" = spec[["snapshot"]], 
               "repository" = spec[["repository"]], 
               "members" = list() )
  
  return(invisible(def))
}

