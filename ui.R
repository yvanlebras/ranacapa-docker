library(plotly)
library(shiny)
library(shinythemes)
shinyUI(bootstrapPage(theme = shinytheme("sandstone"),

  headerPanel("eDNA Data exploration"),
  sidebarPanel(

    ## conditionalPanel() functions for selected tab
    conditionalPanel(condition = "input.tabselected == -999"),
    # For Panel 1, have an input option
    conditionalPanel(condition = "input.tabselected == 1",
                     h3("Run with demo data or custom local or Galaxy dataset?"),

                     radioButtons("mode", label = "",
                                 choices = c("Demo", "Custom", "Galaxy"), selected = "Demo"),
                     uiOutput("biomSelect"),
                     uiOutput("metaSelect"),
                     h3("Press the button below to run the app!"),
                     actionButton("go", "Run the app!"),
                     textOutput("fileStatus")
    ),

    # For panels 3, 4, 5, 6, ask user which variable they would like to visualize on
    conditionalPanel(condition = "input.tabselected == 3 | input.tabselected == 5 |
                     input.tabselected == 6 | input.tabselected == 2",
                     uiOutput("which_variable_r")),

    # On panel 3 (rarefaction), ask what depth they want to rarefy to
    conditionalPanel(condition = "input.tabselected == 2",
                     radioButtons("rare_method", "Choose whether you would like to pick a custom rarefaction depth,
                                  or whether samples should be rarefied to the minimum number of sequences in any single sample",
                                  choices = c("custom", "minimum", "none")),
                     uiOutput("rare_depth")),
     # On panel 3, also ask how many replicate rarefactions should be done
    conditionalPanel(condition = "input.tabselected == 2", uiOutput("rare_reps")),

    # On panel 4 (alpha diversity), ask whether users want observed or Shannon div stats
    conditionalPanel(condition = "input.tabselected == 3 | input.tabselected == 4", uiOutput("which_divtype")),

    # On panel 5 (beta diersity),  ask whether users want to use NMDS or Bray disslimilarity
    conditionalPanel(condition = "input.tabselected == 5 | input.tabselected == 6", uiOutput("which_dissim")),

    # On panels 7 and 8 (barplot and heatmap), ask which taxonomic level they want to visualize to
    conditionalPanel(condition = "input.tabselected == 7 | input.tabselected == 8",
                     uiOutput("which_taxon_level")),
    conditionalPanel(condition = "input.tabselected == 7 | input.tabselected == 8",
                     radioButtons("rared_taxplots",
                                  "Choose whether you would like to view the taxonomy barplot and heatmap for the rarefied or unrarefied datasets",
                                  choices = c("unrarefied", "rarefied"))),
    conditionalPanel(condition = "input.tabselected == 8",
                     uiOutput("select_species_heat")),
    conditionalPanel(condition = "input.tabselected == 4",
                     uiOutput("which_variable_alphaDiv"))


  ),

  mainPanel(
    tabsetPanel(
      tabPanel("Welcome!", value = -999,
               includeMarkdown("docs/welcome-page.md")#,
              # img(src="assembly2.png", align = "center")
              ),
      tabPanel("Data Import", value = 1,

               h2("Please verify that the files below look as expected, and click on 'Run the app!' to get started!"),

               h4("Input taxonomy file"),
               DT::dataTableOutput("print_taxon_table"),
               h4("Input metadata file"),
               DT::dataTableOutput("print_metadata_table")


               # h3("Press the button below to run the app!"),
               # actionButton("go", "(re)Run the app!"),

               # textOutput("fileStatus")

    ),
    tabPanel("Sequencing depth", value = 2,
             includeMarkdown("docs/rarefaction-overview.md"),
             h3("Unrarefied samples - taxon accumulation"),
             plotlyOutput("rarefaction_ur"),
             h3("Rarefied samples"),
             plotlyOutput("rarefaction_r"), height = "1000px"),

    tabPanel("Taxonomy Barplot", value = 7,
             plotlyOutput("tax_bar")),
    tabPanel("Taxonomy Heatmap", value = 8,
             plotlyOutput("tax_heat", height = "750px", width = "1000px")),

    # alpha Diversity panels - first, just plots
    tabPanel("Alpha Diversity plots", value = 3,
             includeMarkdown("docs/alpha-div-overview.md"),
             plotlyOutput("alpharichness")),
    # alpha Diversity panels- second, just stats
    tabPanel("Alpha Diversity Stats", value = 4,
             includeMarkdown("docs/alpha-div-anova.md"),
             tableOutput("alphaDivAOV"),
             includeMarkdown("docs/alpha-div-tukey.md"),
             h4("Alpha Diversity Tukey Tests"),
             tableOutput("alphaDivTukey")),

    # beta Diversity panels - first, just plots
    tabPanel("Beta Diversity plots", value = 5,
             includeMarkdown("docs/beta-div-overview.md"),
             h4("PCoA plot"),
             plotlyOutput("betanmdsplotly"),
             includeMarkdown("docs/beta-div-clustering.md"),
             plotOutput("dissimMap")),

    # beta Diversity panels- second, just stats
    tabPanel("Beta Diversity stats", value = 6,
             includeMarkdown("docs/beta-div-adonis.md"),
             h3("Multivariate ANOVA table"),
             tableOutput("adonisTable"),
             h4("Multivariate ANOVA - Pairwise comparisons"),
             verbatimTextOutput("pairwiseAdonis"),
             includeMarkdown("docs/beta-div-disper.md"),
             h3("Multivariate homogeneity of groups dispersions"),
             verbatimTextOutput("permTestTable"),
             h4("Multivariate homogeneity of groups dispersions - Post-hoc Tukey"),
             tableOutput("betaTukey")),
    tabPanel("Data export", value = 10,
             includeMarkdown("docs/download-text-BIOM.md"),
             downloadButton("downloadTableForBiom", "Download BIOM-formatted taxonomy table"),
             includeMarkdown("docs/download-text-phyloseq.md"),
             downloadButton("downloadPhyloseqObject", "Download phyloseq object")),

    id = "tabselected"
    )

  )
))
