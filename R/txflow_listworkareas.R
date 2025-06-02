#' List work areas
#' 
#' @return Vector of work area references
#' 
#' @export

txflow_listworkareas <- function() {
  
  
  # - configuration
  cfg <- cxapp::.cxappconfig()
  
  try_silent <- ! cfg$option( "mode.debug", unset = FALSE )
  
  
  
  
  # -- work area root
  root <- base::gsub( "\\\\", "/", cfg$option( "txflow.work", unset = base::tempdir() ) )
  
  if ( ! dir.exists(root) )
    return(invisible(character(0)))

  
  # -- list work area
  
  lst_work <- character(0)
  
  
  lst <- base::tolower(list.dirs( path = root, full.names = FALSE, recursive = FALSE ))

    
  for ( xitem in lst ) {
    
    if ( ! base::startsWith( xitem, "txflow-work-" ) )
      next()
    
    
    lst_work <- append( lst_work, 
                        gsub( "^txflow\\-work\\-(.*)", "\\1", xitem, ignore.case = TRUE ) )
  }
  
  
  return(invisible(lst_work))
}

