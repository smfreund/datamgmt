#' Return the formatId of each data object in a package
#'
#' @param node (MNode/CNode) The Node to query for Object sizes
#' @param resource_map_pid (character) The identifier of the Data Package's Resource Map
#' @param formatType (character) Optional. Filter to just Objects of the given
#' formatType. One of METADATA, RESOURCE, or DATA or * for all types
#'
#' @return (character) The formatId, fileName, and identifier of each data object in a package.
solr_package_copy <- function(node, package_identifier, formatType = "DATA") {
    #' TODO better name for this function?
    query <- dataone::query(node,
                            paste0("q=resourceMap:\"",
                                   package_identifier,
                                   "\"+AND+formatType:",
                                   formatType,
                                   "&fl=formatId+AND+fileName+AND+identifier"),
                            as = "data.frame")

    # Replace NA fields
    query$formatId[which(is.na(query$formatId))] <- "application/octet-stream"
    query$fileName[which(is.na(query$fileName))] <- query$identifier

    if (nrow(query) == 0) {
        return(0)
    }

    return(query)
}


#' Copy a Data Package without its child packages.
#'
#' The wrapper function 'package_copy' should be used instead.
#' This function copies a data package from one DataOne member node to another,
#' excluding any child data packages.
#'
#' @param mn_pull (MNode) The Member Node to download from.
#' @param mn_push (MNode) The Member Node to upload to.
#' @param resource_map_pid (chraracter) The identifier of the Resource Map for the package to download.
#'
#' @return (list) List of all the identifiers in the new Data Package.
one_package_copy <- function(mn_pull, mn_push, resource_map_pid) {
    #' TODO - better name for this function?
    stopifnot(is.character(resource_map_pid))
    stopifnot(is(mn_pull, "MNode"))
    stopifnot(is(mn_push, "MNode"))

    package <- arcticdatautils::get_package(mn_pull, resource_map_pid)

    response <- list()
    response[["child_packages"]] <- package$child_packages

    # Download and write EML to new node
    message(paste0("Downloading metadata from package: ", package$metadata))
    eml_path <- file.path(tempdir(), "science_metadata.xml")
    writeBin(dataone::getObject(mn_pull, package$metadata), eml_path)
    new_eml_pid <- arcticdatautils::publish_object(mn_push,
                                                  eml_path,
                                                  arcticdatautils::format_eml())
    response["metadata"] <- new_eml_pid

    # Initialize data pids vector
    data_pids <- vector("character")
    if (length(package$data) != 0) {
        data_pids <- package$data
    }

    # Solr query data formatId, fileName, and identifier
    solr_query <- solr_package_copy(mn_pull, resource_map_pids)
    file_names <- solr_query$fileName
    format_ids <- solr_query$formatId

    # Create temporary file paths
    n_data_pids <- length(data_pids)
    temp_dir <- tempdir()
    data_paths <- unlist(lapply(seq_len(n_data_pids), function(i) {
        file.path(temp_dir, file_names[i])}))

    # Download pids, save in tempfiles, and publish to new node
    if (n_data_pids) {

        message(paste0("Uploading data objects from package: ", package$metadata))

        # Get Data object from member node
        new_data_pids <- unlist(lapply(seq_len(n_data_pids), function(i) {
            dataObj <- tryCatch(dataone::getObject(mn_pull, data_pids[i]),
                                error = function(e) {return("error")})

            # Write object to temporary file
            tryCatch(writeBin(dataObj, data_paths[i]), error = function(e) {
                message(paste0("\n Unable to write ", data_pids[i]))
            })

            arcticdatautils::publish_object(mn_push, data_paths[i], format_ids[i])

        }))

        response[["data"]] <- new_data_pids
        new_resource_map_pid <- create_resource_map(mn_push, new_eml_pid, new_data_pids)

    } else {

        response[["data"]] <- character(0)
        new_resource_map_pid <- create_resource_map(mn_push, new_eml_pid)
    }

    response[["resource_map"]] <- new_resource_map_pid

    return(response)
}


#' Copy a Data Package
#'
#' This function copies a data package from one DataOne member node to another.
#'
#' @param mn_pull (MNode) The Member Node to download from.
#' @param mn_push (MNode) The Member Node to upload to.
#' @param resource_map_pid (chraracter) The identifier of the Resource Map for the package to download.
#'
#' @example
#' \dontrun{
#' cn <- CNode("PROD")
#' mn_pull <- getMNode(cn, "urn:node:ARCTIC")
#' cn <- CNode('STAGING')
#' mn_push <- getMNode(cnTest,'urn:node:mnTestARCTIC')
#' package_copy(mn_pull, mn_push, "resource_map_doi:10.18739/A2RZ6X")
#' }
#'
#' @export
package_copy <- function(mn_pull, mn_push, resource_map_pid) {
    #' TODO - create dynamic structure that allows for more than one level of children (3+ nesting levels)
    #' TODO - add messages per child package?

    # Copy initial package without children
    package <- one_package_copy(resource_map_pid, mn_pull, mn_push)

    if (length(package$child_packages) != 0) {

        n_child_packages <- length(package$child_packages)

        # Copy child packages
        child_packages <- unlist(lapply(seq_len(n_child_packages), function(i) {
            one_package_copy(package$child_packages[i], mn_pull, mn_push)
        }))

        # Select resource_map_pid(s) of child packages
        indices <- which(names(child_packages) == "resource_map")
        child_resource_map_pids <- child_packages[indices]

        # Nest child packages
        updated_resource_map_pid <- update_resource_map(mn_push,
                                                        package$resource_map,
                                                        package$metadata,
                                                        package$data,
                                                        child_resource_map_pids)

        package[["resource_map"]] = updated_resource_map_pid
    }

    return(package)
}