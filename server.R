library(shiny)
library(ggplot2)
library(reshape2)
library(vegan)
library(dplyr)
library(phyloseq)
library(broom)
library(plotly)
library(tibble)
library(ranacapa)
library(scales)
library(heatmaply)
library(markdown)

options(digits = 5, shiny.maxRequestSize = 10 * 1024 ^ 2)

server <- function(input, output)({

  # Setup and RenderUIs ---------------
  # RenderUI for which_variable_r, gets used in Panels 1, 3, 4, 5, 6
  output$which_variable_r <- renderUI({
    selectInput("var", "Select the variable", choices = heads())
  })
  output$which_variable_alphaDiv <- renderUI({
    selectInput("var_alpha", "Select the variable", choices = heads_alpha_Anova())
  })
  # RenderUIs for Panel 1
  output$biomSelect <- renderUI({
    req(input$mode)
    if (input$mode == "Custom") {
      fileInput("in_taxon_table", "Please select your taxonomy table.
                Note: this should be saved either as *.biom or *.txt",
                accept = c(".biom", ".txt", ".tsv"))
    }
    if (input$mode == "Galaxy") {
      fileInput("in_taxon_table", "Please select your taxonomy table.
                Note: this should be saved either as *.biom or *.txt",
                accept = c(".biom", ".txt", ".tsv"))
    }
  })
  output$metaSelect <- renderUI({
    req(input$mode)
    if (input$mode == "Custom") {
      fileInput("in_metadata", "Please select the metadata file.
                Note: this should be saved as *.txt",
                accept = c(".txt", ".tsv"))
    }
    if (input$mode == "Galaxy") {
      fileInput("in_taxon_table", "Please select your taxonomy table.
                Note: this should be saved as *.txt",
                accept = c(".txt", ".tsv"))
    }
  })


  # RenderUI for which_divtype, for Alpha Diversity Panel 4
  output$which_divtype <- renderUI({
    radioButtons("divtype",
                 label = "Observed or Shannon diversity?",
                 choices = c("Observed", "Shannon"))
  })

  # RenderUI for which_dissim, used for Beta Diversity Panel 5,6
  output$which_dissim <- renderUI({
    radioButtons("dissimMethod",
                 "Which type of distance metric would you like?",
                 choices = c("Jaccard Dissimilarity", "Bray-Curtis Dissimilarity"))
  })

  # RenderUI for which_taxon_level, used for barplot and heatmap in Panels 7,8
  output$which_taxon_level <- renderUI({
    radioButtons("taxon_level",
                 "Pick the taxonomic level for making the plot",
                 choices = c("Phylum", "Class", "Order", "Family", "Genus", "Species"))

  })


  choices <- reactive({
    c("Select All", rownames(for_hm()))
  })
  output$select_species_heat <- renderUI({
    selectInput('which_taxa_heat', 'Select taxa to visualize', choices(),
                multiple=TRUE, selectize=FALSE, selected = "Select All")
  })
  # Render UIs for Panel 3 (Rarefaction)
  output$rare_depth <- renderUI({
    if (input$rare_method == "custom") {
      sliderInput("rarefaction_depth",
                  label = "Select a depth of rarefaction",
                  min = taxonomy_table() %>%
                    select_if(is.numeric) %>%
                    colSums() %>%
                    min(),
                  max = taxonomy_table() %>%
                    select_if(is.numeric) %>%
                    colSums() %>%
                    max(),
                  step = 1000,
                  value = 2000)
      } else if (input$rare_method == "minimum") {
                    radioButtons("rarefaction_depth",
                                 label = "The minimum number of reads in any single plot will be selected:",
                                 choices = taxonomy_table() %>%
                                   select_if(is.numeric) %>%
                                   colSums() %>%
                                   min())
                  } else { # no rarefaction requested
                  }
  })
  output$rare_reps <- renderUI({
    if (!(input$rare_method == "none")) {
        sliderInput("rarefaction_reps",
                    label = "Select the number of times to rarefy",
                    min = 2,
                    max = 20,
                    value = 2)
    } else {}
  })

  # Read in data files, validate and make the physeq object -----

  taxonomy_table <- reactive({
    if (input$mode == "Custom") {
      if (grepl(input$in_taxon_table$datapath, pattern = ".txt") |
          grepl(input$in_taxon_table$datapath, pattern = ".tsv")) {
        read.table(input$in_taxon_table$datapath, header = 1,
                   sep = "\t", stringsAsFactors = F,
                   quote = "", comment.char = "") %>%
          scrub_seqNum_column() %>%
          scrub_taxon_paths () %>%
          group_anacapa_by_taxonomy()
      } else if (grepl(input$in_taxon_table$datapath, pattern = ".biom")) {
        phyloseq::import_biom(input$in_taxon_table$datapath) %>%
          convert_biom_to_taxon_table() %>%
          scrub_seqNum_column() %>%
          group_anacapa_by_taxonomy()
      }
    if (input$mode == "Galaxy") {
      if (grepl(input$in_taxon_table$datapath, pattern = ".txt") |
          grepl(input$in_taxon_table$datapath, pattern = ".tsv")) {
        read.table(input$in_taxon_table$datapath, header = 1,
                   sep = "\t", stringsAsFactors = F,
                   quote = "", comment.char = "") %>%
          scrub_seqNum_column() %>%
          scrub_taxon_paths () %>%
          group_anacapa_by_taxonomy()
      } else if (grepl(input$in_taxon_table$datapath, pattern = ".biom")) {
        phyloseq::import_biom(input$in_taxon_table$datapath) %>%
          convert_biom_to_taxon_table() %>%
          scrub_seqNum_column() %>%
          group_anacapa_by_taxonomy()
      }
    } else {
      readRDS("data/demo_taxonTable.Rds") %>%
        scrub_seqNum_column() %>%
        scrub_taxon_paths () %>%
        group_anacapa_by_taxonomy()
    }
  })

  mapping_file <- reactive({
    if (input$mode == "Custom") {
      if (grepl(readLines(input$in_metadata$datapath, n = 1), pattern = "^#")) {
        phyloseq::import_qiime_sample_data(input$in_metadata$datapath) %>%
          as.matrix() %>%
          as.data.frame()
      } else {
        read.table(input$in_metadata$datapath,
                   header = 1, sep = "\t", stringsAsFactors = F,
                   quote = "", comment.char = "")
      }
    if (input$mode == "Galaxy") {
      if (grepl(readLines(input$in_metadata$datapath, n = 1), pattern = "^#")) {
        phyloseq::import_qiime_sample_data(input$in_metadata$datapath) %>%
          as.matrix() %>%
          as.data.frame()
      } else {
        read.table(input$in_metadata$datapath,
                   header = 1, sep = "\t", stringsAsFactors = F,
                   quote = "", comment.char = "")
      }
    } else {
      readRDS("data/demo_metadata.Rds")
    }
  })


  output$fileStatus <- eventReactive(input$go, {
  if (is.null(validate_input_files(taxonomy_table(), mapping_file()))) {
    paste("Congrats, no errors detected!")
  } else {
    validate_input_files(taxonomy_table(), mapping_file())
  }
  })
  # Make physeq object ----

  physeq <- eventReactive(input$go, {
    convert_anacapa_to_phyloseq(taxon_table = taxonomy_table(),
                                metadata_file = mapping_file())
  })

  # Make the object heads, that has the column names in the metadata file
  heads <- reactive({
    base::colnames(mapping_file())
  })

  heads_numeric <- reactive({
    mapping_file() %>%
      dplyr::select_if(is.numeric) %>%
      base::colnames()
  })

  heads_alpha_Anova <- reactive({
    num_factors <- sapply(mapping_file(), function(col) length(unique(col)))
    heads()[num_factors > 2]
  })

  # Panel 2:  Print taxon table ---------

  output$print_taxon_table <- DT::renderDataTable({
    table <- taxonomy_table() %>% select(sum.taxonomy, everything())

    DT::datatable(table, options = list(scrollX = TRUE))
  })
  output$print_metadata_table <- DT::renderDataTable({
    DT::datatable(mapping_file(), options = list(scrollX = TRUE))
  }, options = list(pageLength = 5))



  # Panel 3: Rarefaction and associated plots ----------
  # Check if all samples have a non-NA value for the selected variable to plot by
  # If a sample has an NA for the selected variable, get rid of it from the
  # sample data and from the metadata and from the taxon table (the subset function does both)
  data_subset_unrare <- reactive({
    p2 <- physeq()
    sample_data(p2) <- physeq() %>%
      sample_data %>%
      subset(., !is.na(get(input$var)))
    p2
  })

  # Rarefy the subsetted dataset
  data_subset <- reactive({
    if (!(input$rare_method == "none")) {

    custom_rarefaction(data_subset_unrare(),
                       sample_size = input$rarefaction_depth,
                       replicates = input$rarefaction_reps)
    } else {
      data_subset_unrare()
    }
  })

  # Rarefaction curve before and after rarefaction
  output$rarefaction_ur <- renderPlotly({

    withProgress(message = 'Rendering unrarefied accumulation curve', value = 0, {
      incProgress(0.5)
      p <- ggrare(data_subset_unrare(), step = 1000, se=FALSE, color = input$var)
      q <- p + theme_ranacapa() + theme(axis.title = element_blank())
      gp <- ggplotly(tooltip = c("Sample", input$var)) %>%
        layout(yaxis = list(title = "Species Richness", titlefont = list(size = 16)),
               xaxis = list(title = "Sequence Sample Size", titlefont = list(size = 16)),
               margin = list(l = 100, b = 60))
      gp
    })

  })

  output$rarefaction_r <- renderPlotly({
    withProgress(message = 'Rendering rarified accumulation curve', value = 0, {
      incProgress(0.5)

      p <- ggrare(data_subset(), step = 1000, se=FALSE, color = input$var)
      q <- p +
        facet_wrap(as.formula(paste("~", input$var))) +
        theme_ranacapa() +
        theme(axis.text.x = element_text(angle = 45))
      gp <- ggplotly(tooltip = c("Sample", input$var))
      gp[['x']][['layout']][['annotations']][[2]][['x']] <- -0.07  # adjust y axis title (actually an annotation)
      gp[['x']][['layout']][['annotations']][[1]][['y']] <- -0.15  # adjust x axis title (actually an annotation)
      gp %>% layout(margin = list(l = 80, b = 100, r = 20)) })
  })



  # Panel 4: Alpha diversity ------------
  # Alpha diversity boxplots
  output$alpharichness <- renderPlotly({

    withProgress(message = 'Rendering alpha diversity plot', value = 0, {
      incProgress(0.5)
      p <- plot_richness(data_subset(),
                         x = input$var,
                         measures= input$divtype,
                         color = input$var,
                         shape = input$var)

      q <- p +
        geom_boxplot(aes_string(fill = input$var, alpha=0.2)) +
        theme_ranacapa() +
        theme(legend.position = "none") +
        theme(axis.title = element_blank()) +
        theme(axis.text.x = element_text(angle = 45))
      gp <- ggplotly(tooltip = c("x", "value")) %>%
        layout(yaxis = list(title = paste(input$divtype, "Diversity"), titlefont = list(size = 16)),
               xaxis = list(title = input$var, titlefont = list(size = 16)),
               margin = list(l = 60, b = 70)) })
  })


  # Alpha diversity aov generation
  alpha_anova <- reactive({
    alpha.diversity <- estimate_richness(data_subset(), measures = c("Observed", "Shannon"))
    data <- cbind(sample_data(data_subset()), alpha.diversity)
    aov(as.formula(paste(input$divtype, "~" , input$var_alpha)), data)
  })

  # Alpha diversity AOV print
  output$alphaDivAOV <- renderTable({
    broom::tidy(alpha_anova())
  }, digits = 4)

  # Alpha Diversity tukey
  output$alphaDivTukey <- renderTable({
    broom::tidy(TukeyHSD(alpha_anova()))
  }, digits = 4)

  # Panel 5: Beta Diversity exploration plots ------------
  # PCoA plotly
  dissimMethod <- reactive({
    ifelse(input$dissimMethod == "Jaccard Dissimilarity", "jaccard", "bray")
  })

  output$betanmdsplotly <- renderPlotly({
    withProgress(message = 'Rendering beta diversity plot', value = 0, {
      incProgress(0.5)

      d <- distance(data_subset(), method= dissimMethod())
      ord <- ordinate(data_subset(), method = "PCoA", distance = d)
      nmdsplot <- plot_ordination(data_subset(), ord, input$var,
                                  color = input$var, shape = input$var) +
        ggtitle(paste(input$var, "PCoA; dissimilarity method:",
                      tools::toTitleCase(input$dissimMethod))) +
        theme(plot.title = element_text(hjust = 0.5)) +
        theme_ranacapa()
      ggplotly(tooltip = c(input$var, "x", "y")) %>%
        layout(hovermode = 'closest')
    })
  })



  # Other beta diversity plot
  output$dissimMap <- renderPlot({
    d <- distance(data_subset(), method = dissimMethod())

    # Ward linkage map
    wcluster <- as.dendrogram(hclust(d, method = "ward.D2"))
    ggdendro::ggdendrogram(wcluster, theme_dendro = FALSE, color = "red")  +
      theme_bw(base_size = 18)  +
      theme_ranacapa() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 15))


  }, height = 500, width = 750 )

  # Panel 6: Beta diversity statistics ----------
  output$adonisTable <- renderTable ({
    sampledf <- data.frame(sample_data(data_subset()))
    dist_obj <- phyloseq::distance(data_subset(), method = dissimMethod())
    broom::tidy(adonis(as.formula(paste("dist_obj~", input$var)), data = sampledf)$aov.tab)

  }, digits = 5)

  output$permTestTable <- renderPrint({
    sdf <- as(sample_data(data_subset()), "data.frame")
    dist_obj <- phyloseq::distance(data_subset(), method = dissimMethod())
    betadisper(dist_obj, getElement(sdf, input$var))
  })

  output$betaTukey <- renderTable({
    sdf <- as(sample_data(data_subset()), "data.frame")
    dist_obj <- phyloseq::distance(data_subset(), method = dissimMethod())
    broom::tidy(TukeyHSD(betadisper(dist_obj, getElement(sdf, input$var))))
  }, digits = 5)

  output$pairwiseAdonis <- renderPrint({
    sdf <- as(sample_data(data_subset()), "data.frame")
    veganComm <- vegan_otu(data_subset())
    pairwise_adonis(veganComm, getElement(sdf, input$var),
                    sim_method = dissimMethod())
  })



  # Panel 7: Taxonomy-by-site interactive barplot -------
  output$tax_bar <- renderPlotly({

    withProgress(message = 'Rendering taxonomy barplot', value = 0, {
      incProgress(0.5)

      if (input$rared_taxplots == "unrarefied") {
        physeqGlommed = tax_glom(data_subset_unrare(), input$taxon_level)
      } else {
        physeqGlommed = tax_glom(data_subset(), input$taxon_level)
      }
      plot_bar(physeqGlommed, fill = input$taxon_level) + theme_ranacapa() +
        theme(axis.text.x = element_text(angle = 45)) +
        theme(axis.title = element_blank())
      gp <- ggplotly() %>%
        layout(yaxis = list(title = "Abundance", titlefont = list(size = 16)),
               xaxis = list(title = "Sample", titlefont = list(size = 16)),
               margin = list(l = 70, b = 100))
      gp
    })
  })


  ## Panel 8: Heatmap of taxonomy by site ---------
  for_hm <- reactive({
    if (input$rared_taxplots == "unrarefied") {
      tt <-  data.frame(otu_table(data_subset_unrare()))

    } else {
      tt <- data.frame(otu_table(data_subset()))

    }
    for_hm <- cbind(tt, colsplit(rownames(tt), ";",
                                 names = c("Phylum", "Class", "Order", "Family", "Genus", "Species")))

    for_hm <- for_hm %>%
      mutate(Phylum = ifelse(is.na(Phylum) | Phylum == "", "unknown", Phylum)) %>%
      mutate(Class = ifelse(is.na(Class) | Class == "", "unknown", Class)) %>%
      mutate(Order = ifelse(is.na(Order) | Order == "", "unknown", Order)) %>%
      mutate(Family = ifelse(is.na(Family) | Family == "", "unknown", Family)) %>%
      mutate(Genus = ifelse(is.na(Genus) | Genus == "", "unknown", Genus)) %>%
      mutate(Species = ifelse(is.na(Species)| Species == "", "unknown", Species))

    for_hm <- for_hm %>%
      group_by(get(input$taxon_level)) %>%
      # group_by(Species) %>%
      summarize_if(is.numeric, sum) %>%
      data.frame %>%
      column_to_rownames("get.input.taxon_level.")
        # column_to_rownames("Species")
    for_hm <- for_hm[which(rowSums(for_hm) > 0),]
    for_hm[for_hm == 0] <- NA
    for_hm
  })
  output$tax_heat <- renderPlotly({

    withProgress(message = 'Rendering taxonomy heatmap', value = 0, {
      incProgress(0.5)
      if("Select All" %in% input$which_taxa_heat){
        selected_taxa <- rownames(for_hm())
      } else{
        selected_taxa <- input$which_taxa_heat
      }
      for_hm <- for_hm()[selected_taxa,]
      heatmaply(for_hm, Rowv = F, Colv = F, hide_colorbar = F,
                grid_gap = 1, na.value = "white", key.title = "Number of \nSequences in \nSample")
    })

  })

  table_for_download <- reactive({
    taxcol <- reshape2::colsplit(taxonomy_table()$sum.taxonomy, ";", paste0("V", 1:6))%>%
      mutate(V1 = paste0("p__", V1),
             V2 = paste0("c__", V2),
             V3 = paste0("o__", V3),
             V4 = paste0("f__", V4),
             V5 = paste0("g__", V5),
             V6 = paste0("s__", V6))  %>%
      mutate(taxonomy =  paste(V1, V2, V3, V4, V5, V6, sep = ";")) %>%
      select(-c(V1, V2, V3, V4, V5, V6))
    cbind(taxonomy_table() %>% rename(taxID = sum.taxonomy), taxcol)

  })
  output$downloadTableForBiom <- downloadHandler(


    filename = function() {
      paste("taxonomy-for-biom.txt", sep = "")
    },
    content = function(file) {
      write.csv(table_for_download(), file, row.names = FALSE, quote = F)
    }
  )

  output$downloadPhyloseqObject <- downloadHandler(


    filename = function() {
      paste("phyloseq-object.Rds", sep = "")
    },
    content = function(file) {
      saveRDS(data_subset_unrare(), file)
    }
  )



})
