# # LIBRARIES -----------------------------------------------------------------
suppressMessages(require(shiny))
suppressMessages(require(shinyTree))
suppressMessages(require(tibble))
suppressMessages(require(plotly))
# suppressMessages(require(shinythemes))
suppressMessages(require(ggplot2))
suppressMessages(require(DT))
suppressMessages(require(pheatmap))
# suppressMessages(require(threejs))
suppressMessages(require(RColorBrewer))
# suppressMessages(require(mclust))
suppressMessages(require(reshape2))
suppressMessages(require(ggplot2))
suppressMessages(require(knitr))
suppressMessages(require(shinyWidgets))
suppressMessages(require(scater))
suppressMessages(require(kohonen))
# suppressMessages(require(Rsomoclu))
suppressMessages(require(SingleCellExperiment))
suppressMessages(require(Matrix))
suppressMessages(require(colourpicker))
# suppressMessages(require(shinytest))
suppressMessages(require(scran))
suppressMessages(require(ggalluvial))
suppressMessages(require(BiocSingular))
suppressMessages(require(dplyr))

if ("debugme" %in% rownames(installed.packages())) {
  suppressMessages(require(debugme))
}
if ("gtools" %in% rownames(installed.packages())) {
  suppressMessages(require(gtools))
}
if ("kableExtra" %in% rownames(installed.packages())) {
  suppressMessages(require(kableExtra))
}
if ("reactlog" %in% rownames(installed.packages())) {
  suppressMessages(require(reactlog))
}

if (!exists(".schnappsEnv")) {
  .schnappsEnv <- new.env(parent = emptyenv())
}

if (exists("devscShinyApp")) {
  if (devscShinyApp) {
    packagePath <- "~/Rstudio/UTechSCB-SCHNAPPs/inst/app/"
    # setwd("~/Rstudio/UTechSCB-SCHNAPPs/")
  }
} else {
  packagePath <- find.package("SCHNAPPs", lib.loc = NULL, quiet = TRUE) %>% paste0("/app/")
}
if (exists(".SCHNAPPs_locContributionDir", envir = .schnappsEnv)) {
  localContributionDir <- get(".SCHNAPPs_locContributionDir", envir = .schnappsEnv)
} else {
  localContributionDir <- NULL
}
if (exists(".SCHNAPPs_defaultValueSingleGene", envir = .schnappsEnv)) {
  defaultValueSingleGene <- get(".SCHNAPPs_defaultValueSingleGene", envir = .schnappsEnv)
} else {
  defaultValueSingleGene <- "cd3g"
}
if (exists(".SCHNAPPs_defaultValueMultiGenes", envir = .schnappsEnv)) {
  defaultValueMultiGenes <- get(".SCHNAPPs_defaultValueMultiGenes", envir = .schnappsEnv)
} else {
  defaultValueMultiGenes <- "cd3g, cd4, cd8b, ighm, TCF4, LILRA2, LYZ, cd74, bcl11b, IL32,hbb"
}
if (exists(".SCHNAPPs_defaultValueRegExGene", envir = .schnappsEnv)) {
  defaultValueRegExGene <- get(".SCHNAPPs_defaultValueRegExGene", envir = .schnappsEnv)
} else {
  defaultValueRegExGene <- "^MT-|^RP|^MRP"
}
if (exists(".SCHNAPPs_DEBUG", envir = .schnappsEnv)) {
  DEBUG <- get(".SCHNAPPs_DEBUG", envir = .schnappsEnv)
} else {
  DEBUG <- FALSE
}
if (exists(".SCHNAPPs_DEBUGSAVE", envir = .schnappsEnv)) {
  DEBUGSAVE <- get(".SCHNAPPs_DEBUGSAVE", envir = .schnappsEnv)
} else {
  DEBUGSAVE <- FALSE
}

# list available colors for samples and clusters, other colors are defined independantly.
# Sys.setenv(DEBUGME = ".")
base::source(paste0(packagePath, "/defaultValues.R"), local = TRUE)
if (!exists("allowedColors")) {
  allowedColors <- unique(c(
    "#8c510a", "#d8b365", "#f6e8c3", "#c7eae5", "#5ab4ac", "#01665e", "#c51b7d", "#e9a3c9",
    "#fde0ef", "#e6f5d0", "#a1d76a", "#4d9221", "#762a83", "#af8dc3", "#e7d4e8", "#d9f0d3",
    "#7fbf7b", "#1b7837", "#b35806", "#f1a340", "#fee0b6", "#d8daeb", "#998ec3", "#542788",
    "#b2182b", "#ef8a62", "#fddbc7", "#d1e5f0", "#67a9cf", "#2166ac", "#b2182b", "#ef8a62",
    "#fddbc7", "#e0e0e0", "#999999", "#4d4d4d"
  ))
}


if (all(c("future", "parallel") %in% rownames(installed.packages()))) {
  library(parallel)
  library(future)
  # options(future.globals.maxSize = 4000 * 1024^2)
  # maxCores <- parallel::detectCores() - 1
  # maxCores <- 1 # 32GB memory
  # plan("multiprocess", workers = maxCores)
}

# Sys.setenv(DEBUGME = ".")
base::source(paste0(packagePath, "/serverFunctions.R"), local = TRUE)


# enableBookmarking(store = "server")

# global variable with directory where to store files to be included in reports
.schnappsEnv$reportTempDir <- base::tempdir()

scShinyServer <- function(input, output, session) {
  if (DEBUG) base::cat(file = stderr(), "ShinyServer running\n")
  session$onSessionEnded(stopApp)
  base::options(shiny.maxRequestSize = 2000 * 1024^2)
  # seed ----
  # TODO needs to be an option
  seed <- 2
  # localContributionDir <- .SCHNAPPs_locContributionDir
  base::set.seed(seed)
  
  # debug directory ----
  # check that directory is availabl, otherwise create it
  if (DEBUG) {
    if (!dir.exists("~/SCHNAPPsDebug")) {
      base::dir.create("~/SCHNAPPsDebug")
    }
    # TODO ??? clean directory??
  }
  
  # in development mode, called not from package? ----
  if (exists("devscShinyApp")) {
    if (devscShinyApp) {
      packagePath <- "~/Rstudio/UTechSCB-SCHNAPPs/inst/app/"
      # setwd("~/Rstudio/UTechSCB-SCHNAPPs/")
    }
  } else {
    packagePath <- find.package("SCHNAPPs", lib.loc = NULL, quiet = TRUE) %>% paste0("/app/")
  }
  
  
  # files to be included in report ----
  # developers can add in outputs.R a variable called "myZippedReportFiles"
  zippedReportFiles <- c(
    "Readme.txt", "report.html", "sessionData.RData",
    "normalizedCounts.csv", "variables.used.txt"
  )
  
  
  
  # gene list for gene selection tree ----
  # TODO check if file exists
  # TODO as parameter to load user specified information
  # TODO have this as an option to load other files
  if (file.exists(paste0(packagePath, "/geneLists.RData"))) {
    base::load(file = paste0(packagePath, "/geneLists.RData"))
  } else {
    if (!exists("geneLists")) {
      geneLists <- list(emtpy = list())
    }
  }
  
  
  # initialize projection functions ----
  # base projections
  # display name, reactive to calculate projections
  projectionFunctions <- list(
    # c("sampleNames", "sample"),
    c("Gene count", "geneCount"),
    c("UMI count", "umiCount"),
    c("Feature count", "featureCount"),
    c("before filter", "beforeFilterPrj")
  )
  .schnappsEnv$projectionFunctions <- projectionFunctions
  
  # differential expression functions ----
  # used in subcluster analysis
  .schnappsEnv$diffExpFunctions <- list()
  diffExpFunctions <- list()
  
  # load global reactives, modules, etc ----
  base::source(paste0(packagePath, "/reactives.R"), local = TRUE)
  base::source(paste0(packagePath, "/outputs.R"), local = TRUE)
  base::source(paste0(packagePath, "/modulesUI.R"), local = TRUE)
  base::source(paste0(packagePath, "/moduleServer.R"), local = TRUE)
  # # bookmarking ----
  # ### too complicated to debug.
  # setBookmarkExclude(c("bookmark1"))
  # observeEvent(input$bookmark1, {
  #   if (DEBUG) cat(file = stderr(), paste("bookmarking: \n"))
  #   if (DEBUG) cat(file = stderr(), paste(names(input), collapse = "\n"))
  # 
  #   session$doBookmark()
  #   if (DEBUG) cat(file = stderr(), paste("bookmarking: DONE\n"))
  # })
  # # Need to exclude the buttons from themselves being bookmarked
  # # Save extra values in state$values when we bookmark
  # onBookmark(function(state) {
  #   # TODO need to include here the color values and other reactive values
  #   # message
  #   # deepDebug()
  #   if (DEBUG) base::cat(file = stderr(), paste("onBookmark\n"))
  #   # if (DEBUG) base::cat(file = stderr(), paste("token5", str(environment()),  "\n"))
  #   # if (DEBUG) base::cat(file = stderr(), paste("token2", str(parent.env(environment())),  "\n"))
  #   state$values$schnappsEnv <- .schnappsEnv
  # })
  # 
  # # after bookmarking
  # onBookmarked(fun = function(url) {
  #   # deepDebug()
  #   if (DEBUG) base::cat(file = stderr(), paste("onBookmarked\n"))
  #   # if (DEBUG) base::cat(file = stderr(), paste("token2", str(parent.env(environment())),  "\n"))
  #   showBookmarkUrlModal(url)
  # }
  # )
  # setBookmarkExclude("bookmark1")
  # # Read values from state$values when we restore
  # onRestore(session = session, fun = function(state) {
  #   # TODO need to include here the color values and other reactive values
  #   deepDebug()
  #   if (DEBUG) base::cat(file = stderr(), paste("onRestore\n"))
  #   .schnappsEnv <<-  state$values$schnappsEnv
  # })
  # #   
  # onRestored(session = session, fun = function(state) {
  #   if (DEBUG) base::cat(file = stderr(), paste("onRestored\n"))
  #   deepDebug()
  #   .schnappsEnv <<-  state$values$schnappsEnv
  # })
  # 
  # load contribution reactives ----
  # parse all reactives.R files under contributions to include in application
  uiFiles <- base::dir(
    path = c(paste0(packagePath, "/contributions"), localContributionDir), pattern = "reactives.R",
    full.names = TRUE, recursive = TRUE
  )
  for (fp in uiFiles) {
    if (DEBUG) base::cat(file = stderr(), paste("loading: ", fp, "\n"))
    # myHeavyCalculations <- NULL
    myProjections <- NULL
    myDiffExpFunctions <- NULL
    base::source(fp, local = TRUE)
    
    # heavyCalculations <- append2list(myHeavyCalculations, heavyCalculations)
    projectionFunctions <- append2list(myProjections, projectionFunctions)
    diffExpFunctions <- append2list(myDiffExpFunctions, diffExpFunctions)
  }
  
  # update diffExpression radiobutton
  dgeChoices <- c()
  if (length(diffExpFunctions) > 0) {
    for (li in 1:length(diffExpFunctions)) {
      liVal <- diffExpFunctions[[li]]
      if (length(liVal) == 2) {
        dgeChoices <- c(dgeChoices, liVal[1])
      } else {
        # shouldn't happen
        stop("number of values for normalization function is not 2\n")
      }
    }
  }
  updateSelectizeInput(
    session = session, inputId = "sCA_dgeRadioButton",
    choices = dgeChoices, selected = defaultValue("sCA_dgeRadioButton", "none")
  )
  .schnappsEnv$diffExpFunctions <- diffExpFunctions
  
  # load contribution outputs ----
  # parse all outputs.R files under contributions to include in application
  uiFiles <- base::dir(
    path = c(paste0(packagePath, "/contributions"), localContributionDir), pattern = "outputs.R",
    full.names = TRUE, recursive = TRUE
  )
  for (fp in uiFiles) {
    if (DEBUG) cat(file = stderr(), paste("loading: ", fp, "\n"))
    # myHeavyCalculations <- NULL
    myProjections <- NULL
    myZippedReportFiles <- c()
    base::source(fp, local = TRUE)
    # heavyCalculations <- append2list(myHeavyCalculations, heavyCalculations)
    projectionFunctions <- append2list(myProjections, projectionFunctions)
    zippedReportFiles <- c(zippedReportFiles, myZippedReportFiles)
  }
  .schnappsEnv$projectionFunctions <- projectionFunctions
  
  ### history setup ----
  # TODO put in function
  # can this be done just with bookmarking?
  if (exists("historyPath", envir = .schnappsEnv)) {
    
    .schnappsEnv$restoreHistory = FALSE
    if (!is.null(x = .schnappsEnv$historyPath)) {
      # check that at least some of the files that can be created have been
      rmdFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "history.*.Rmd")
      projFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "projections.*.RData")
      sxFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "scEx\\..*.RData")
      sxLogFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "scEx_log.*.RData")
      scolFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "scol.*.RData")
      ccolFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "ccol.*.RData")
      plotFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = "plotData.*.RData")
      allDataFiles = dir(path = .schnappsEnv$historyPath, full.names = T, pattern = ".RData")
      # if there is already a history
      if(length(rmdFiles)>0 & length(projFiles)>0 & 
         length(sxFiles)>0 & length(sxLogFiles)>0 & 
         length(scolFiles)>0){
        deepDebug()
        # browser()
        # this will be overwritten but should be session specific
        oldTmpFolder = .schnappsEnv$reportTempDir
        # load input variables
        fileInfo = c(sxLogFiles, plotFiles, ccolFiles, scolFiles, sxLogFiles, projFiles) %>% fs::file_info()
        latestFile = fileInfo %>% pull("birth_time") %>% order()  %>% last()
        # this should load inp, i.e. the old input variable with all parameters
        tempEnv =  new.env(parent=emptyenv())
        cp = load(fileInfo[latestFile, "path"] %>% as.character(), envir = tempEnv)
        
        if(!"schnappsEnv" %in% cp){
          cat(file = stderr(), paste("There is no 'inp' in ", rownames(fileInfo)[latestFile], "\n\n\n"))
        }
        # RData file now contain the .schnappsEnv
        # add anything that is not set
        for(na in ls(tempEnv$schnappsEnv)[!ls(tempEnv$schnappsEnv) %in% ls(.schnappsEnv)]){
          .schnappsEnv[[na]] = tempEnv$schnappsEnv[[na]]
        }
        # input is handled by .schnappsEnv$defaultValues in the UI
        if (!is.null(tempEnv$inp)){
          # loadInput(inp, session, input)
          .schnappsEnv$restoreHistory = TRUE
          filesxInfo =  sxFiles %>% file.info()
          latestsxFile = filesxInfo %>% pull("ctime") %>% order()  %>% last()
          inp = tempEnv$inp
          if(!"file1" %in% names(inp) | is.null(inp$file1)) {
            inp$file1 = data.frame(name="dummy name",  size = 0, type = "", datapath = "")
          }
          inp$file1$datapath = rownames(filesxInfo)[latestsxFile]
          .schnappsEnv$inputFile = inp$file1
          
          fileRmdInfo =  rmdFiles %>% file.info()
          latestRmdFile = fileRmdInfo %>% pull("ctime") %>% order()  %>% last()
          .schnappsEnv$historyFile = rownames(filesxInfo)[latestRmdFile]
        }else{
          cat(file = stderr(), "input is null from history file please update SCHNAPPs and start over.")
        }
        rm("tempEnv")
        #scol
        fileInfo = scolFiles %>% file.info()
        latestFile = fileInfo %>% pull("ctime") %>% order()  %>% last()
        tempEnv =  new.env(parent=emptyenv())
        cp = load(rownames(fileInfo)[latestFile], envir = tempEnv)
        if("scol" %in% cp) {
          sampleCols$colPal <- unlist(tempEnv$scol$scol)
        }
        rm("tempEnv")
        fileInfo = ccolFiles %>% file.info()
        latestFile = fileInfo %>% pull("ctime") %>% order()  %>% last()
        tempEnv =  new.env(parent=emptyenv())
        cp = load(rownames(fileInfo)[latestFile], envir = tempEnv)
        if("ccol" %in% cp) {
          clusterCols$colPal <- unlist(tempEnv$ccol$ccol)
        }
        rm("tempEnv")
        
        cat(file = stderr(), paste(rownames(fileInfo)[latestFile], paste(cp, collapse = " "), sep  = "\n"))
        cat(file = stderr(),  "\n")
        tfile <- paste0(.schnappsEnv$historyPath, "/userProjections.RData")
        cp = load(file = tfile)
        if(all(c("prjs", "newPrjs") %in% cp)){
          sessionProjections$prjs = prjs
          projectionsTable$newProjections = newPrjs
        }
       
        # derived/modified projections from projections tab
        deepDebug()
        .schnappsEnv$reportTempDir = oldTmpFolder
        

      } else { 
        # create directory with name and Rmd file
        createHistory(.schnappsEnv)
      }
      
    } else {
      rm("historyPath", envir = .schnappsEnv)
    }
  }
  
  
  
} # END SERVER

# shiny::showReactLog()

# enableBookmarking(store = "server")
