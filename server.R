## See comments and explanations in global.R
## Rasmus Benestad


# Load the ggplot2 package which provides
# the 'mpg' dataset.

# Define a server for the Shiny app
server <- function(input, output, session) {
  
  ## Functions ---------------------------------------------------------------------------------------------------------
  
  points <- eventReactive(input$recalc, {
    cbind(lon(y),lat(y))
  }, ignoreNULL = FALSE)
  
  
  # Show a popup at the given location
  showMetaPopup <- function(mapid,stid, lat, lng) {
    #3 Make sure that only one station ID is selected and only one latitude/longitude
    if (length(stid)>1) stid <- stid[1]
    if (length(lat)>1) lat <- lat[1]
    if (length(lng)>1) lng <- lng[1]
    
    print(paste('showMetaPopup() ===',stid,round(lat,2),round(lng,2)))
    fnames <- updatefilenames()
    Y <- updatemetadata()
    statistic <- vals()
    #print("Y <- retrieve.stationsummary")
    selLon <- round(Y$longitude[Y$station.id == stid],2)
    selLat <- round(Y$latitude[Y$station.id == stid],2)
    selAlt <- round(Y$altitude[Y$station.id == stid])
    location <- Y$location[Y$station.id == stid]
    value <- paste(input$statistic,names(ci)[as.numeric(input$ci)],'=',round(statistic[Y$station.id == stid],1),collapse = ',')
    #print(c(stid,selLon,selLat,location))
    content <- paste(sep = "<br/>",
                     tags$strong(HTML(toupper(location))),
                     tags$strong(HTML(paste('LON ',selLon,'W',sep=''), 
                                      paste(' LAT ',selLat,'N',sep=''), 
                                      paste(' ALT ',selAlt,'m',sep=''))), 
                     sprintf("Station ID: %s", as.character(stid)),
                     sprintf("%s", value),
                     sprintf("Interval: %s", paste(Y$first.year[Y$station.id == stid],Y$last.year[Y$station.id == stid],sep = '-'))
    )
    
    leafletProxy("mapid") %>% addPopups(lng, lat, content,layerId = stid)
    #print('((()))')
  }
  
  ## Reactive expressions to update information -------------------------------------------------------------- 
  
  # thresh <- reactive({
  #   return(as.numeric(input$thresh))
  # })
  
  ## The following reactive expressions get updated file information and metadata
  updatefilenames <- reactive({
    print('reactive - updatefilenames()')
    fnames <- list.files(path='data',pattern='.nc',full.names = TRUE)
    fnames <- fnames[grep('.nc',fnames,fixed=TRUE)]
    fnames <- fnames[grep(src[match(input$src,src)],fnames)]
    print(fnames) #; print(src); print(input$src)
    return(fnames)
  })
  
  updatevarids <- reactive({
    print('reactive - updatevarids()')
    fnames <- list.files(path='data',pattern='.nc',full.names = TRUE)
    fnames <- fnames[grep('.nc',fnames,fixed=TRUE)]
    #print(fnames); print(src); print(input$src)
    fnames <- fnames[grep(src[match(input$src,src)],fnames)]
    varids <- substr(fnames,6,nchar(fnames))
    varids <- substr(varids,1,regexpr('.',varids,fixed=TRUE)-1)
    names(varids) <- vari2name(varids,names=varnames[as.numeric(input$lingo),])
    return(varids)
  })
  
  getstid <- reactive({
    print('reactive - getstid()')
    #fnames <- updatefilenames()
    #print(paste('vals: Y$',input$statistic,sep='')); print(fnames); print(input$ci)
    ## Get summary data from the netCDF file
    iss <- (1:length(locations()))[is.element(toupper(locations()),'DE BILT')]
    if (length(iss) > 0) is <- iss else
      iss <- (1:length(locations()))[is.element(toupper(locations()),'OSLO BLIND')]
    if (length(iss) > 0) is <- iss else is <- 1
    return(Y$station.id[is])
  })
  
  updatemetadata <- reactive({
    print('reactive - updatemetadata()')
    fnames <- updatefilenames()
    ii <- as.numeric(input$ci)
    if (ii > length(fnames)) ii <- 1
    Y <- retrieve.stationsummary(fnames[ii])
    print(paste('Retrieved from ',fnames[ii])); print(dim(Y))
    return(Y)
  })
  
  newvars <- reactive({
    print('reactive - newvars()')
    fnames <- updatefilenames()
    print(fnames)
    varids <- updatevarids()
    ci <- 1:length(varids); names(ci) <- names(varids)
    print(ci)
    return(ci)
  })
  
  ## update the selected station series 
  updatestation <- reactive({
    print('reactive - updatestation()')
    Y <- updatemetadata()
    fnames <- updatefilenames()
    ii <- as.numeric(input$ci)
    if (ii > length(fnames)) ii <- 1
    Y <- retrieve.stationsummary(fnames[ii])
    il <- is.element(tolower(Y$location),tolower(input$location))
    if (sum(il)>0) selectedStid <- Y$station.id[il][1] else {
      print(input$location);print('Something is wrong!')
      selectedStid <- getstid()
    }
    print(paste('selectedID: ',selectedStid,' = ',input$location,'from',fnames[ii]))
    print(paste("y <- retrieve.station(",names[ii],electedStid,")"))
    y <- retrieve.station(fnames[ii],stid=selectedStid,verbose=verbose)
    return(y)
  })
  
  locations <- reactive({
    Y <- updatemetadata()
    return(Y$location)
  })
  
  ## The following are more general ractive expressions
  zoom <- reactive({
    zoomscale <- switch(input$src,
                        'metnod'=5,'ecad'=4,'ghcnd'=1)
    return(zoomscale)
  })
  
  # Computing indices - values used in the map
  vals <- reactive({
    print('reactive - vals()')
    
    ## Get summary data from the netCDF file
    Y <-updatemetadata()  
    #print(summary(Y)); print(fnames[ii])
    showseason <- switch(input$season,
                         'all'='','DJF'='_DJF','MAM'='_MAM','JJA'='_JJA','SON'='_SON')
    print(paste('Y$',input$statistic,showseason,sep=''))
    if ( (tolower(input$statistic)!='number_of_days') &
         (tolower(input$statistic)!='specific_day') ) {
      #print('Get the summary statistics from the netCDF file'); print(tolower(input$statistic))
      Z <- eval(parse(text=paste('Y$',input$statistic,showseason,sep=''))) 
    } else {
      if (tolower(input$statistic)=='number_of_days') {
        print('Number_of_days')
        x0 <- as.numeric(input$x0)
        print(paste('threshold x0=',x0))
        if (!is.null(Y$wetfreq)) Z <- switch(input$season,
                                             'all'=3.6525*Y$wetfreq*exp(-x0/Y$wetmean),
                                             'DJF'=0.90*Y$wetfreq_DJF*exp(-x0/Y$wetmean_DJF),
                                             'MAM'=0.90*Y$wetfreq_MAM*exp(-x0/Y$wetmean_MAM),
                                             'JJA'=0.90*Y$wetfreq_JJA*exp(-x0/Y$wetmean_JJA),
                                             'SON'=0.90*Y$wetfreq_SON*exp(-x0/Y$wetmean_SON)) else
                                               Z <- switch(input$season,
                                                           'all'=365.25*(1-pnorm(x0,mean=0,sd=Y$sd)),
                                                           'DJF'=90*(1-pnorm(x0,mean=Y$mean_DJF,sd=Y$sd_DJF)),
                                                           'MAM'=90*(1-pnorm(x0,mean=Y$mean_MAM,sd=Y$sd_MAM)),
                                                           'JJA'=90*(1-pnorm(x0,mean=Y$mean_JJA,sd=Y$sd_JJA)),
                                                           'SON'=90*(1-pnorm(x0,mean=Y$mean_SON,sd=Y$sd_SON))) 
        Z <- as.numeric(Z)
      } else {
        ## Get a specific date it
        it <- input$it
        print("Read a specific date from the netCDF file"); print(it)
        x <- retrieve.station(fnames[ii],it=it,verbose=verbose)
        Z <- c(coredata(x))
        dim(Z) <- c(length(Z),1)
        ## The stations are sorted according to alphabetic order
        Z <- Z[match(Y$station.id,stid(x))]
        #print(rbind(stid(x),Y$station.id))
        #print('...')
      }
    } 
    if (input$statistic=='number.valid') Z <- eval(parse(text=paste('Y$',input$statistic,sep='')))/365.25
    if (input$statistic=='records') Z <- 100*Z
    if (input$statistic=='lows') Z <- 100*Z
    Z[Z <= -99] <- NA
    print(paste('Values returned by vals(): n=',length(Z))); print(summary(Z)); print('+++')
    return(Z) 
  })
  
  ## Events ---------------------------------------------------------------------------------------------------------
  ## Used to perform an action in response to an event. 
  
  ## When new data source/region is selected
  observeEvent(input$src, {
    ## Get the file names of the data
    isolate({print(paste("observeEvent(input$src=",input$src,')'))})
    print('Use updated Y')
    Y <- updatemetadata() 
    varids <- updatevarids()
    print(varids)
    ci <- newvars()
    print('input$src - ci')
    prec <- ci[is.element(substr(varids,1,3),'pre')]
    if (is.na(prec)) prec <- 1   ## "Safety option"
    filter <- rep(TRUE,length(vals))
    updateSelectInput(session=session,inputId="ci",choices=ci,selected=prec)
    print(paste("ci=",paste(names(ci),'[',ci,']',sep='',collapse=", "),"prec=",prec))
    print('---src -> ci---')
  # })
  # 
  # ## When new data source/region is selected
  # observeEvent(input$src, {
    ## Get the file names of the data
    #isolate({print(paste("observeEvent(input$src=",input$src,')'))})
    #Y <- updatemetadata() 
    print(table(Y$country)); print(names(Y))
    loc1 <- switch(input$src,'metnod'='Oslo - blind','ecad'='De bilt','ghcnd'=Y$location[1])
    print(paste('New default location:',loc1))
    updateSelectInput(session=session,inputId="location", choices = locations(), selected=loc1)
    print(loc1)
    sel <- is.element(locations(),loc1)
    if (sum(sel)==0) print(locations()) else
                     print(paste(locations()[sel],'from',length(locations()),'sites'))
    print('---src -> location---')
  })
  
  ## Update climate indicator
  observe({
    isolate({print(paste("observe(input$ci=",input$ci,')'))})
    varids <- updatevarids()
    print(varids)
    prec <- ci[is.element(substr(varids,1,3),'pre')]
    if (is.na(prec)) prec <- 1   ## "Safety option"
    updateSelectInput(session=session,inputId="ci", choices = varids, selected=prec)
    print('---ci---')
  })
  
  ## Update location 
  observe({
    isolate({print(paste("observe(input$location=",input$location,')'))})
    Y <- updatemetadata() 
    varids <- updatevarids()
    print(varids)
    prec <- ci[is.element(substr(varids,1,3),'pre')]
    if (is.na(prec)) prec <- 1   ## "Safety option"
    print(table(Y$country)); print(names(Y))
    loc1 <- switch(input$src,'metnod'='Oslo - blind','ecad'='De bilt','ghcnd'=Y$location[1])
    print(paste('New default location:',loc1,'from',length(Y$location),'sites'))
    updateSelectInput(session=session,inputId="location", choices = locations(), selected=loc1)
    print('---location---')
  })
  
  ## Change language
  observeEvent(input$lingo, {
    print(paste("observeEvent(input$lingo=",input$lingo,')'))
    #tscales <- c("day","month","season","year")
    print(varids)
    names(tscales) <- timescales[as.numeric(input$lingo),]
    updateSelectInput(session=session,inputId="tscale",choices=tscales,selected=input$tscale)
    
    ci <- c(1:length(varids)); 
    names(ci) <- vari2name(varids,names=varnames[as.numeric(input$lingo),])
    updateSelectInput(session=session,inputId="ci",choices=ci,selected=input$ci)
    
    names(src) <- regions[as.numeric(input$lingo),]
    #print(src)
    updateSelectInput(session=session,inputId="src",choices=src,selected=input$src)
    
    names(stattype) <- type2name(stattype,input$lingo,types)
    #print(stattype)
    updateSelectInput(session=session,inputId="statistic",choices=stattype,selected=input$statistic)
    
    names(timespace) <- timespacenames[as.numeric(input$lingo),]
    updateSelectInput(session=session,inputId="timespace",choices=timespace,selected=input$timespace)
    print('---lingo---')
  })
  
  # Click on the map marker
  observeEvent(input$map_marker_click,{
    print("observeEvent() - click")
    fnames <- updatefilenames()
    Y <- updatemetadata()
    event <- input$map_marker_click
    #print(paste('Updated ',input$location)); print(event$id)
    selected <- which(Y$station.id == event$id)
    
    #if (input$exclude== 'Selected') filter[selected] <- FALSE
    updateSelectInput(session,inputId = 'location',label=lab.location[as.numeric(input$lingo)],
                      choices=Y$location,selected = Y$location[selected])
    print('---click---')
  })
  
  ## Change the time scale for the time series box
  observeEvent(input$tscale, {
    print(paste("observeEvent(input$tscale=",input$tscale,')'))
    if (input$tscale=='year') newseaTS <- seaTS[1] else
      if (input$tscale=='season') newseaTS <- seaTS[1:5] else newseaTS <- seaTS
      updateSelectInput(session=session,inputId="seasonTS",choices=newseaTS)
      print('---tscale---')
  })
  
  # observeEvent(input$country, {
  #   print("observeEvent(input$country")
  #   statistic <- vals()
  #   if (input$country != 'All') statistic[!is.element(Y$country,input$country)] <- NA
  #   if (max(statistic,na.rm=TRUE)>10) digits <- 0 else digits <- 1
  #   statisticmin <- round(min(statistic,na.rm=TRUE),digits)
  #   statisticmax <- round(max(statistic,na.rm=TRUE),digits)
  #   print('max & min'); print(c(statisticmin,statisticmax))
  #   updateSliderInput(session=session,inputId="statisticrange",
  #                     min=statisticmin,max=statisticmax,value = c(statisticmin,statisticmax))
  # })
  
   # observe({
   #   print('xxx')
   #   loc1 <- switch(input$src,'metnod'='Oslo - blind','ecad'='De bilt','ghcnd'=Y$location[1])
   #   print(paste('New default location:',loc1,'from',length(locations()),'sites'))
   #   updateSelectInput(session=session,inputId="location", choices = locations(), selected=loc1)
   # })
  
  ## Observe ---------------------------------------------------------------------------------------------------------
  ## Reactive expressions that read reactive values and call reactive expressions, and will automatically 
  ## re-execute when those dependencies change.
  
  # When something happens
  observe({
    print('observe - update slider')
    statistic <- vals()
    if (max(statistic,na.rm=TRUE)>10) digits <- 0 else digits <- 1
    statisticmin <- round(min(statistic,na.rm=TRUE),digits)
    statisticmax <- round(max(statistic,na.rm=TRUE),digits)
    print(paste('Slider max & min= [',statisticmin,', ',statisticmax,'] n=',length(statistic),sep=''))
    updateSliderInput(session=session,inputId="statisticrange",
                      min=statisticmin,max=statisticmax,value = c(statisticmin,statisticmax))
  })
  
  
  observe({
    print('observe - Update aspects')
    if (varids[as.numeric(input$ci)]=='precip') {
      aspects <- aspectsP 
      names(aspects) <- aspectnameP[as.numeric(input$lingo),] 
    } else {
      aspects  <- aspectsT
      names(aspects) <- aspectnameT[as.numeric(input$lingo),]
    }                
    print(aspects)
    updateSelectInput(session=session,inputId="aspect",choices=aspects,selected=aspects[1])
  })
  
  
  observe({
    print('observe - Update country list')
    print(table(Y$country)); print(names(Y))
    updateSelectInput(session=session,inputId="country",choices=c('All',rownames(table(Y$country))),
                      selected='All')
  })
  
  
  observe({
    print('observe - Update statistics')
    ii <- as.numeric(input$ci)
    if (ii > length(fnames)) ii <- 1
    updateSelectInput(session=session,inputId="statistic",
                      choices=getstattype(fnames[ii],lingo=input$lingo),selected="mean")
  })
  
  
  observe({
    print('observe - marker click')
    #leafletProxy("map") %>% clearPopups()
    event <- input$map_marker_click
    #print('Data Explorer from map'); print(event$id)
    if (is.null(event))
      return()
    #print('Click --->'); print(event); print('<--- Click')
    isolate({
      showMetaPopup(mapid,stid=event$id,lat=event$lat, lng = event$lng)
    })

    #removeMarker("map",layerId = event$id)
    leafletProxy("mapid",data = event) %>%
      addCircles(lng = event$lng, lat = event$lat,color = 'red',layerId = 'selectID', weight = 12)

    #selectedStid <- event$id
  })
  
  ## Output rendering ------------------------------------------------------------------------------------------------
  
  ## The map panel 
  output$map <- renderLeaflet({
    print('output$map - render')
    Y <- updatemetadata()
    statistic <- vals()
    #print('Stastistic shown on map');print(summary(statistic))
    
    if (input$country=='All') filter <- rep(TRUE,length(statistic)) else {
      filter <- rep(FALSE,length(statistic))
      filter[(Y$country == input$country)] <- TRUE
    }
    
    print('        <<< input$ci is not updated!!! >>>              ')
    isolate({print(paste('Range shown in map',input$statisticrange[1],'-',input$statisticrange[1],' ci=',input$ci))})
    filter[statistic < input$statisticrange[1]] <- FALSE
    filter[statistic > input$statisticrange[2]] <- FALSE
    print(paste('Number of locations shown=',sum(filter)))
    
    highlight <- NULL
    if (tolower(input$highlight) == "top 10") highlight <- order(statistic[filter],decreasing=TRUE)[1:10] else 
      if (tolower(input$highlight) == "low 10") highlight <- order(statistic[filter],decreasing=FALSE)[1:10] else 
        if (tolower(input$highlight) == "New records") {
          if ( (!is-null(Y$last_element_highest)) & (!is-null(Y$last_element_lowest)) ) 
            highlight <- Y$last_element_highest > 0 & Y$last_element_lowest > 0 else
              if (!is-null(Y$last_element_highest)) highlight <- Y$last_element_highest > 0 else
                highlight <- rep(FALSE,length(statistic))
        } 
    
    lon.highlight <- Y$longitude[filter][highlight]
    lat.highlight <- Y$latitude[filter][highlight]
    if (tolower(input$highlight) != "none") {
      print('Highlight');print(statistic[highlight]); print(lon.highlight); print(lat.highlight); print(input$ci); print(input$highlight)
    }
    if (sum(filter)==0) {
      print(paste(input$ci,varid(y),min(statistic),max(statistic),input$statisticrange[1],input$statisticrange[2]))
      filter <- rep(TRUE,length(statistic))  
    }
    if (!is.null(Y$wetfreq)) reverse <- TRUE else reverse <- FALSE
    print(paste('Reverse palette =',reverse)); print(summary(statistic))
    #print(c(sum(filter),length(filter),length(statistic)))
    pal <- colorBin(colscal(col = 't2m',n=100),
                    statistic[filter],bins = 10,pretty = TRUE,reverse=reverse)    
    legendtitle <- input$statistic
    if (legendtitle=='Specific_day') legendtitle=input$it
    is <- which(tolower(Y$location) == tolower(input$location))
    
    print('The map is being rendered')
    leaflet("mapid") %>% 
      addCircleMarkers(lng = Y$longitude[filter], # longitude
                       lat = Y$latitude[filter],fill = TRUE, # latitude
                       label = as.character(round(statistic[filter],digits = 2)),
                       labelOptions = labelOptions(direction = "right",textsize = "12px",opacity=0.6),
                       popup = Y$location[filter],popupOptions(keepInView = TRUE),
                       radius =4,stroke=TRUE,weight = 1, color='black',
                       layerId = Y$station.id[filter],
                       fillOpacity = 0.4,fillColor=pal(statistic[filter])) %>% 
      addCircleMarkers(lng = lon.highlight, lat = lat.highlight,fill=TRUE,
                       label=as.character(1:10),
                       labelOptions = labelOptions(direction = "right",textsize = "12px",opacity=0.6),
                       radius=5,stroke=TRUE, weight=5, color='black',
                       layerId = Y$station.id[filter][highlight],
                       fillOpacity = 0.6,fillColor=rep("black",10)) %>%
      addLegend("bottomleft", pal=pal, values=round(statistic[filter], digits = 2), 
                title=legendtitle,
                layerId="colorLegend",labFormat = labelFormat(big.mark = "")) %>%
      addProviderTiles(providers$Esri.WorldStreetMap,
                       #addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(noWrap = TRUE)
      ) %>% 
      setView(lat=Y$latitude[is],lng = Y$longitude[is], zoom = zoom())
  })
  
  output$plotstation <- renderPlotly({
    print('output$plotstation - render')
    isolate({print(paste('Time series for',input$location,'ci=',input$ci,'season=',input$season,
                         'tscale=',input$tscale,'aspect=',input$aspect)) })
    y <- updatestation()
    
    #if (is.precip(y)) thresholds <- seq(10,50,by=10) else thresholds <- seq(-30,30,by=5)
    
    if (is.precip(y)) {
      if (input$aspect=='wetmean') FUN<-'wetmean' else
        if (input$aspect=='wetfreq') FUN<-'wetfreq' else
          if (input$aspect=="Number_of_days") FUN<-'count' else FUN<-'sum'
    } else if (input$aspect=="Number_of_days") FUN<-'count' else FUN<-'mean'
    #if (is.null(FUN)) FUN='mean'
    
    x0 <- as.numeric(input$x0)
    
    ## Time series
    if (input$tscale != 'day') {
      print(paste('Use',FUN,'to aggregate the time series. input$tscale=',input$tscale))
      print(c(aspects,input$aspect)); print(x0); print(esd::unit(y))
    }
    
    y0 <- y # Original daily data
    if (FUN != 'count')
      y <- switch(input$tscale,
                  'day'=y,'month'=as.monthly(y,FUN=FUN),
                  'season'=as.4seasons(y,FUN=FUN),'year'=as.annual(y,FUN=FUN,nmin=300)) else
                    y <- switch(input$tscale,
                                'day'=y,'month'=as.monthly(y,FUN=FUN,threshold=x0,nmin=25),
                                'season'=as.4seasons(y,FUN=FUN,threshold=x0,nmin=80),
                                'year'=as.annual(y,FUN=FUN,threshold=x0,nmin=300))
    #if (is.T(y)) browser()
    
    if (input$aspect=='anomaly') y <- anomaly(y)
    if (input$seasonTS != 'all') y <- subset(y,it=tolower(input$seasonTS))
    if (input$aspect=='wetfreq') {
      y <- 100*y
      attr(y,'unit') <- '%'
    }
    
    ## Marking the top and low 10 points
    #print('10 highs and lows')
    if (tolower(input$highlightTS)=='top 10') 
      highlight10 <- y[order(coredata(y),decreasing=TRUE)[1:10]] else
        if (tolower(input$highlightTS)=='low 10') 
          highlight10 <- y[order(coredata(y),decreasing=FALSE)[1:10]] else
            if (tolower(input$highlightTS)=='new records') {
              #print('new records')
              dim(y) <- NULL
              recs <- records(y)
              #print(recs)
              highlight10 <- y[attr(recs,'t')]
            } else
              highlight10 <- y[1:10]+NA
    #print(highlight10)
    
    withProgress(message = 'Updating ...',
                 detail = 'This may take a while...', value = 0,
                 { for (i in 1:15) {
                   incProgress(1/15)
                   Sys.sleep(0.05)}
                 })
    
    timeseries <- data.frame(date=index(y),y=coredata(y),trend=coredata(trend(y)))
    print('The timeseries is being rendered')
    TS <- plot_ly(timeseries,x=~date,y=~y,type = 'scatter',mode='lines',name='data')
    TS = TS %>% add_trace(y=~trend,name='trend') %>% 
      add_markers(x=index(highlight10),y=coredata(highlight10),label=input$highlightTS) %>% 
      layout(title=loc(y),yaxis = list(title=esd::unit(y)))
    #TS$elementID <- NULL
    
  })
  
  output$histstation <- renderPlotly({
    print('output$histstation - render')
    isolate({print(paste('Time series for',input$location,'ci=',input$ci,'season=',input$season,
                         'tscale=',input$tscale,'aspect=',input$aspect)) })
    ## Get summary data from the netCDF file
    Y <- updatemetadata()
    statistic <- vals()
    y <- updatestation()
    
    #if (is.precip(y)) thresholds <- seq(10,50,by=10) else thresholds <- seq(-30,30,by=5)
    
    if (is.precip(y)) {
      if (input$aspect=='wetmean') FUN<-'wetmean' else
        if (input$aspect=='wetfreq') FUN<-'wetfreq' else
          if (input$aspect=="Number_of_days") FUN<-'count' else FUN<-'sum'
    } else if (input$aspect=="Number_of_days") FUN<-'count' else FUN<-'mean'
    #if (is.null(FUN)) FUN='mean'
    
    ## Selected site
    print(paste('Selected site=',loc(y),stid(y)))
    x0 <- as.numeric(input$x0)
    y0 <- y # Original daily data
    if (FUN != 'count')
      y <- switch(input$tscale,
                  'day'=y,'month'=as.monthly(y,FUN=FUN),
                  'season'=as.4seasons(y,FUN=FUN),'year'=as.annual(y,FUN=FUN,nmin=300)) else
                    y <- switch(input$tscale,
                                'day'=y,'month'=as.monthly(y,FUN=FUN,threshold=x0,nmin=25),
                                'season'=as.4seasons(y,FUN=FUN,threshold=x0,nmin=80),
                                'year'=as.annual(y,FUN=FUN,threshold=x0,nmin=300))
    #if (is.T(y)) browser()
    #print(c(aspects,input$aspect)); print(input$ci); print(x0); print(FUN); print(esd::unit(y))
    if (input$aspect=='anomaly') y <- anomaly(y)
    if (input$seasonTS != 'all') y <- subset(y,it=tolower(input$seasonTS))
    if (input$aspect=='wetfreq') {
      y <- 100*y
      attr(y,'unit') <- '%'
    }
    if (input$timespace == 'Histogram_location') yH <- coredata(y) else yH <- statistic
    
    withProgress(message = 'Updating ...',
                 detail = 'This may take a while...', value = 0,
                 { for (i in 1:15) {
                   incProgress(1/15)
                   Sys.sleep(0.05)
                 }
                 })
    #mx <- ceiling(1.1*max(abs(y),na.rm=TRUE))
    #print('histstation'); print(summary(yH))
    if (substr(input$timespace,1,12) != 'Annual_cycle') {
      fit <- density(yH[is.finite(yH)])
      #breaks <- seq(floor(min(yH,na.rm=TRUE)),ceiling(max(yH,na.rm=TRUE)),length=100)
      pdf <- dnorm(fit$y,mean=mean(yH,na.rm=TRUE), sd = sd(yH,na.rm=TRUE))
      dist <- data.frame(y=coredata(yH))
      #print(summary(dist))
      #syH <- round(summary(yH)[c(1,4,6)],1)
      syH <- summary(yH)[c(1,4,6)]
      #print(syH); print(class(syH))
      if (input$timespace=='Histogram_map') 
        title <- paste(input$statistic,': ',paste(names(syH),round(syH,1),collapse=', ',sep='='),sep='') else
          title <- paste(loc(y),': ',paste(syH,collapse=', ',sep='='),sep='')
      #print(title)
      H <- plot_ly(dist,x=~y,name='data',type='histogram',histnorm='probability')
      H = H %>% #add_trace(y=fit$x,x=pdf,name='pdf',mode='lines') %>% 
        #add_trace(x = fit$x, y = fit$y, mode = "lines", fill = "tozeroy", yaxis = "y2", name = "Density") %>%
        layout(title=title)
      #H = H %>% layout(title=title)
    } else {
      y <- subset(y0,it=input$dateRange)
      dim(y) <- NULL
      if (is.precip(y)) {
        FUN <- 'sum'
        ylab='mm/month'
      } else {
        FUN <- 'mean'
        ylab <- 'deg C'
      }
      title <- loc(y)
      if (input$timespace=='Annual_cycle_month') {
        mac <- data.frame(y=as.monthly(y,FUN=FUN)) 
        mac$Month <- month(as.monthly(y))
      } else {
        mac <- data.frame(y) 
        mac$Month <- month(y)  
      }
      
      print(summary(mac)); print(input$dateRange); print(title)
      print('The histogram/annual cycle is being rendered')
      AC <- plot_ly(mac,x=~Month,y=~y,name='mean_annual_cycle',type='box')  %>% 
        layout(title=title,yaxis=list(ylab))
    }
    
  })
  
  
  ## Multi-language support for Text, menues, and labels
  
  output$maintitle <- renderText({
    maintitle[as.numeric(input$lingo)]})
  output$maptitle <- renderText({
    maptitle[as.numeric(input$lingo)]})
  output$tstitle <- renderText({
    tstitle[as.numeric(input$lingo)]})
  output$htitle <- renderText({
    htitle[as.numeric(input$lingo)]})
  output$cftitle <- renderText({
    cftitle[as.numeric(input$lingo)]})
  output$timespacelabel <- renderText({
    lab.timespace[as.numeric(input$lingo)]})
  output$timeperiodlabel <- renderText({
    lab.timeperiod[as.numeric(input$lingo)]})
  output$timescalelabel <- renderText({
    lab.timescale[as.numeric(input$lingo)]})
  output$seasonlabel <- renderText({
    lab.season[as.numeric(input$lingo)]})
  output$aspectlabel <- renderText({
    lab.aspect[as.numeric(input$lingo)]})
  output$locationlabel <- renderText({
    lab.location[as.numeric(input$lingo)]})
  output$statisticslabel <- renderText({
    lab.statitics[as.numeric(input$lingo)]})
  output$threshold <- renderText({
    lab.threshold[as.numeric(input$lingo)]})
  output$specificdate <- renderText({
    lab.date[as.numeric(input$lingo)]})
  output$highlightlabel <- renderText({
    lab.highlight[as.numeric(input$lingo)]})
  output$highlightTSlabel <- renderText({
    lab.highlight[as.numeric(input$lingo)]})
  output$daylabel <- renderText({
    lab.speficicday[as.numeric(input$lingo)]})
  output$excludelabel <- renderText({
    lab.exclude[as.numeric(input$lingo)]})
  output$mapdescription <- renderText({
    paste(descrlab[as.numeric(input$lingo)],explainmapstatistic(input$statistic,input$lingo,types))})
  output$datainterval <- renderText({
    paste(sources[is.element(src,input$src),as.numeric(input$lingo)],
          attr(Y,'period')[1],' - ',attr(Y,'period')[2])})
}
