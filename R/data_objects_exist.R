#' Check if data objects exist in a list of Data Packages.
#'
#' This function is primarily intended to assist Mark Schildhauer in preparation
#' for the Carbon synthesis working group.
#'
#' @param mn (MNode/CNode) The Node to query for Object sizes
#' @param pids (character) The identifier of the Data Packages' Metadata
#' @param write_to_csv (logical) Optional. Write the query results to a csv
#' @param folder_path (character) Optional. Folder to write results to
#' @param file_name (character) Optional. Name of results file in csv format
#'
#' @return (data.frame) Data frame containing query results.
#'
#' @examples
#' \dontrun{
#' cn <- CNode("PROD")
#' mn <- getMNode(cn, "urn:node:ARCTIC")
#' data_objects_exist(mn,
#' c("doi:10.5065/D60P0X4S", "urn:uuid:3ea5629f-a10e-47eb-b5ce-de10f8ef325b"))
#' }
#'
#' @export
data_objects_exist <- function(mn,
                               pids,
                               write_to_csv = FALSE,
                               folder_path = NULL,
                               file_name = NULL) {
    #' TODO check if formatting of pid is url then format
    stopifnot(is(mn, "MNode"))
    stopifnot(is.character(pids))
    stopifnot(length(pids) > 0)
    stopifnot(arcticdatautils::object_exists(mn, pids))
    if (write_to_csv) {
        stopifnot(file.exists(folder_path))
    }

    # Initialize results data frame
    n <- length(pids)
    results <- data.frame("identifier" = pids,
                          "data_objects_present" = rep("NA", n),
                          "url" = paste0("https://arcticdata.io/catalog/#view/",
                                         pids),
                          stringsAsFactors = F)

    # Get resource map associated with input metadata
    for (i in seq_len(n)) {
        resource_map <- unlist(query(mn,
                                     paste0("q=identifier:\"",
                                            pids[i],
                                            "\"&fl=resourceMap")))

        # Query data objects
        if (!is.null(resource_map)) {
            data_objects <- unlist(query(mn,
                                         paste0("q=resourceMap:\"",
                                                resource_map,
                                                "\"+AND+formatType:DATA",
                                                "&fl=identifier"),
                                         as = "list"))

            if (!is.null(data_objects)) {
                results$data_objects_present[i] = "yes"
            } else {
                results$data_objects_present[i] = "no"
            }

        } else {
            results$data_objects_present[i] = "no"
        }
    }

    if (write_to_csv) {
        if (!grepl(".csv", file_name)) {
            file_name <- paste0(file_name, ".csv")
        }

        path = file.path(folder_path, file_name)
        write.csv(results, path, row.names = FALSE)
        message(paste0("Results downloaded to: ", path))
    }

    return(results)
}