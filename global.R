## This R-shiny app searches the data directory for netCDF files with station data. These
## netCDF files have been generated with the esd-package using write2nc4.station and contain
## daily data and some summary statistics. The precalculated summary statistics are used for
## plotting the maps. The intention is that this app is flexible and adjusts the output according
## to the netCDf files and teir contents. To make the app as speedy as possible, it only reads the
## actual data presented, such as pre-calculated summary statistics and selected time series or 
## date. The netCDF files allow for direct access, which means that only the required data are 
## extracted. Some numbers may be estimated, such as expected number of events per year: 365*Pr(X) -
## For temperature use the normal distribution, for precipitation use the "rain equation" - together 
## with the pre-computed summary statistics: (mean, sd) or (fw, mu)
## Rasmus Benestad & Abdelkader Mezghani, 2018-06-21

## The esd-package is available from github.com/metno/esd
library(esd)
library(shiny)
library(shinydashboard)
library(leaflet)
library(plotly)

## Functions used by the app: -------------------------------------------------------------------------------------

## Organises the names of the statistic presented in the map and their appearances in the menu. Supports multiple languages
type2name <-function(stattype,lingo,types) {
  names <- rbind(
    c("Høyde over havet","Start år","Dager uten nedbør","Siste år","Breddegrad","Lengdegrad","Maksimumsverdi",           
      "Gjennomsnitt","Minimumsverdi","Antall år med data","Antall høye rekorder (%)",
      "Trend (per tiår)","Trend: dager med nedbør (%)","Trend: nedbørsintensitet", 
      "Dager med nedbør (%)","Typisk nedbørsintensitet (mm/dag)",
      "Antall dager over terskelverdi","Utvalgt dato","Standardavvik","Antall lave rekorder (%)"),
    c("Høyde over havet","Start år","Dager uten nedbør","Siste år","Breddegrad","Lengdegrad","Maksimumsverdi",           
      "Gjennomsnitt","Minimumsverdi","Antall år med data","Rekorder: registrert/(antall uten klimaendring)",
      "Trend","Trend: dager med nedbør (%)","Trend: nedbørsintensitet", 
      "Dager med nedbør (%)","Typisk nedbørsintensitet (mm/dag)",
      "Antall dager over terskelverdi","Utvalgt dato","Standardavvik","Lave rekorder: registrert/(antall uten klimaendring)"),
    c("Altitude","Start year","Days without precipitation","End year","Latitude","Longitude","Maximum",           
      "Average","Minimum","Years with data"," Number of record-highs (%)",
      "Trend (per decade)","Trend in wet days","Trend in rain intensity", 
      "Number of wet days (%)","Mean rain intensity (mm/day)","Number of days above threshold",
      "Specific date","Standard deviation","Number of record-lows (%)")
  )
  matchingname <- names[as.numeric(lingo),]
  descr <- matchingname[match(tolower(stattype),tolower(types))]
  return(descr)
}

explainmapstatistic <- function(stattype,lingo,types) {
  descriptions <- rbind(
    c("Høyde over havet i meter (metadata)","Året da målingene startet (metadata)",
      "Hvor mange dager det har gått uten nedbør",
      "Siste år med målinger (metadata)","Målestasjonens breddegrad (metadata)",
      "Målestasjoens lengdegrad (metadata)","Maksimumsverdi",           
      "Gjennomsnittlig nedbørsmengde (mm) eller temperatur for et helt år eller sesong",
      "Minste målte verdi","Hvor lang er måleserien (i antall år)",
      "Forholdet (i %) mellom antall registrerte rekorder og hva man forventer i et stabilt klima",
      "Trend (per tiår)","Trend i dager med nedbør (%/tiår)","Trend i nedbørsintensitet (mm/dag per tiår)", 
      "Dager med nedbør (%)","Gjennomsnittlig nedbørsmengde for dager det regner mer enn 1mm (mm/dag)",
      "Forventet antall dager over terskelverdi","Målte verdier for en valgt dag",
      "Standardavvik av avvik fra normalen over et år eller en sesong",
      "Forholdet (i %) mellom antall registrerte rekorder og hva man forventer i et stabilt klima"),
    c("Høgde over havet i meter (metadata)","Året da mælingane starta (metadata)",
      "Kor mange dagar det har gått utan nedbør",
      "Siste år med mælinger (metadata)","Mælestasjonens breddegrad (metadata)",
      "Mælestasjoens lengdegrad (metadata)","Maksimumsverdi",           
      "Gjennomsnittleg nedbørsmengde (mm) eller temperatur for et heilt år eller sesong",
      "Minste mælte verdi","Kor myke målledata som finnes (i antall år)",
      "Forholdet (i %) mellom antall registrerte rekordar og kva ein forventar i eit stabilt klima",
      "Trend (per tiår)","Trend i dagar med nedbør (%/tiår)","Trend i nedbørsintensitet (mm/dag per tiår)", 
      "Dagar med nedbør (%)","Gjennomsnittleg nedbørsmengde for dager det regner meir enn 1mm (mm/dag)",
      "Forventa antall dagar over terskelverdi","Mælte verdier for ein vald dag",
      "Standardavvik av avvik fra normalen over eit år eller ein sesong",
      "Forholdet (i %) mellom antall registrerte rekordar og kva ein forventer i eit stabilt klima"),
    c("The elevation of the station in m above sea level (metadata))",
      "The year when the observations started (metadata)","Number of days since it last rained",
      "The last year with observations (metadata)","The latitude of the station in degrees north (metadata)",
      "The longitude of the station in degrees east (metadata)","The highest recorded value",           
      "The average year or season in terms of total precipitation or mean temperature",
      "The smallest value","How many years there is with data (metadata)",
      "The number of record-highs compared to expected number given a stable climate (%)",
      "Trend (per decade)","Trend in number of wet days",
      "Trend in the annual or seasonal wet-day mean precipitation", 
      "The mean number of wet days over the whole year or seasons (%)",
      "The mean wet-day mean precipitation over the whole year or seasons (mm/day)",
      "The expected number of days above threshold",
      "Observations made for a specific date",
      "The standard deviation of anomalies over the whole year or seasons",
      "The number of record-highs compared to expected number given a stable climate (%)")
  )
  print(paste('explainmapstatistic',lingo,stattype))
  description <- descriptions[as.numeric(lingo),]
  descr <- description[match(tolower(stattype),tolower(types))]
  return(descr)
}


## Extract the avaiable statistics to present on the map based on the aggregated statistics stored in the netCDF files
getstattype <- function(fname,lingo=NULL) {
  print(paste('getstattype',fname,lingo))
  meta <- retrieve.stationsummary(fname)
  doubleuscrs <- unlist(lapply(gregexpr('_',names(meta)),length)) > 1
  names(meta)[doubleuscrs] <- sub('_','-',names(meta)[doubleuscrs])
  names(meta) <- paste(names(meta),'_',sep='')
  stattype <- rownames(table(substr(names(meta),1,regexpr('_',names(meta))-1)[sapply(meta,is.numeric)]))
  stattype <- stattype[!is.element(stattype,c('station.id'))]
  stattype <- sub('-','_',stattype)
  if (length(grep("last_element_highest",stattype))>0) {
    stattype <- stattype[-grep("last_element_highest",stattype)]
  }
  if (length(grep("last_element_lowest",stattype))>0) {
    stattype <- stattype[-grep("last_element_lowest",stattype)]
  }
  stattype <- c(stattype,'Number_of_days','Specific_day')
  if (!is.null(lingo)) {
    names(stattype) <- type2name(stattype,lingo,types)
  }
  return(stattype)
}

## Plain text description of the statistics presented on the climate indicators for ordinary people.
vari2name <- function(x,vars=c('pre','t2m','tmax','tmin',
                               'cc','ss','pp','fg','fx','sd','dd'),
                      names=c('Precipitation','Daily mean temperature',
                              'Daily max temperature','Daily min temperature',
                              'Cloud cover','Sunshine','Pressure','Wind speed',
                              'Wind gust','Snow depth','Wind direction'),nc=3) {
  y <- x
  if (length(vars) != length(names)) stop("vars have different length to names in 'variname'")
  for (i in 1:length(x)) {
    pattern <- tolower(substr(x[i],1,nc))
    #print(pattern)
    ii <- grep(pattern = pattern,substr(vars,1,nc))
    if (length(ii)>0) y[i] <- names[ii]
  }
  return(y)
}

## The start-up settings - global variables etc used in the UI and server. Supports several languages
print('--- <Initiatial settings> ---')
## Defaults
verbose <-FALSE                     ## For debugging
lingo <- 1                         ## Default language option                
#firstlocation <- 'Oslo - blind'   ## Default location
#zoom <- 5                         ## Default zooming in the map
reg1 <- 1                          ## Default source of dataset/region

## Data sources - representing different regions
src <- c('metnod','ecad','ghcnd')
## The labelling of the data sources in the menu
regions <- rbind(c('Norge','Europa','Verden'),
                 c('Noreg','Europa','Verden'),
                 c('Norway','Europe','World'))
names(src) <- regions[1,]
descrlab <- c('Forklaring:','Forklaring:','Description:')

sources <- rbind(c('Oppdaterte data fra Meteorologisk institutt. Kun stasjoner med mer enn 30 år er inkludert',
                   'Oppdaterte data fra Meteorologisk institutt. Kun stasjoner med mer enn 30 år er inkludert',
                   'Up-to-date data from Met Norway. Only includes station series longer than 30 years.'),
                 c('Åpne data fra European Climate and Assessment Dataset (ECA&D). Kilde: https://www.ecad.eu/',
                   'Åpne data fra European Climate and Assessment Dataset (ECA&D). Kilde: https://www.ecad.eu/',
                   'Open climate data from Climate and Assessment Dataset (ECA&D). Source: https://www.ecad.eu/'),
                 c('Åpne data fra Global Historical Climate Network (GHCN). Kilde: https://www.ncdc.noaa.gov/ghcn-daily-description',
                   'Åpne data fra Global Historical Climate Network (GHCN). Kilde: https://www.ncdc.noaa.gov/ghcn-daily-description',
                   'Open data from Global Historical Climate Network (GHCN). Source: https://www.ncdc.noaa.gov/ghcn-daily-description'))

## Types of statistics
types <- c("altitude","first.year","lastrains","last.year","latitude","longitude","max",           
           "mean","min","number.valid","records","trend","trend_wetfreq","trend_wetmean", 
           "wetfreq","wetmean","Number_of_days","Specific_day","sd","lows")

## Seasons for the statistics presented in the maps
sea <- c('All year'='all','Dec-Feb'='DJF',
         'Mar-May'='MAM','Jun-Aug'='JJA','Sep-Nov'='SON')
## Seasons to present in the time series plots
seaTS <- c('All year'='all','Dec-Feb'='DJF',
           'Mar-May'='MAM','Jun-Aug'='JJA','Sep-Nov'='SON',month.abb)

## Thesholds
#thresholds <- seq(10,50,by=10)

timespace <- c('Annual_cycle_month','Annual_cycle_day',
               'Histogram_location','Histogram_map')
timespacenames <- rbind(c('Sesongvariasjon på månedsbasis','Sesongvariasjon på dagsbasis',
                          'Histogram for gitt sted','Statistikk for steder vist på kartet'),
                        c('Sesongvariasjon på månedsbasis','Sesongvariasjon på dagsbasis',
                          'Histogram for gitt sted','Statistikk for steder vist på kartet'),
                        c('Annual cycle (monthly)','Annual cycle (daily)',
                          'Histogram for selected location','Statstics for data shown in map'))
names(timespace) <- timespacenames[1,]

## Set the optional labels and titles in the menu based on chosen language 
languages <- 1:3; language.names <- c('Bokmål','Nynorsk','English')
maintitle <- c('Meteorologisk institutt klimadata','Meteorologisk institutt klimadata','MET Norway Climate records')
maptitle <- c('Velg sted','Vel stad','Location selection')
tstitle <- c('Tidsutvikling (historisk vær)','Tidsutvikling (historisk vêr)','Time series (past weather)')
htitle <- c('Statistikk (historisk klima)','Statistikk (historisk klima)','Statistical distribution (past climate)')
cftitle <- c('Om portalen & Tilbakemeldinger','Om portalen & Tilbakemeldingar','About & feedback')
lab.timescale <- c("Tidsskala","Tidsskala","Time scale")
lab.timespace <- c("Tid/rom","Tid/rom","Time or Space")
lab.season <- c("Årstid","Årstid","Season")
lab.highlight <- c("Uthev","Uthev","Higlight")
lab.aspect <- c("Perspektiv","Perspektiv","Aspect")
lab.timeperiod <- c("Tidsperiode","Tidsperiode","Time period")
lab.threshold <- c("Terskelverdi","Treskelverdi","Threshold")
lab.location <- c("Sted","Stad","Location")
lab.statitics <- c("Statistikk vist på kartet","Statistikk vist på kartet","Statistics shown in map")
lab.date <- c("Utvalgt dato","Utvald dato","A specific day")
lab.highlight <- c('Uthev','Uthev','Highlight')
lab.exclude <- c('Ekcluder','Eksluder','Exclude')
aspectsP <- c("sum","wetfreq","wetmean","Number_of_days")
aspectnameP <- rbind(c("Nedbørsmengde","Nedbørsfrekvens","Nedbørsintensitet","Antall dager med mye nedbør"),
                     c("Nedbørsmengde","Nedbørsfrekvens","Nedbørsintensitet","Antall dager med mye nedbør"),
                     c("Total amount","Rain frequency","Mean rain intensity","Days with heavy rain"))
aspectsT <- c("mean","anomaly","Number_of_days")
aspectnameT <- rbind(c("Målt","Avvik fra normalen","Antall dager"),
                     c("Mæling","Avvik fra normalen","Antall dager"),
                     c("Measured","Anomaly","Number of days"))
varnames=rbind(c('Nedbør','Middeltemperatur','Maksimumstemperatur','Minimumstemperatur',
                 'Skydekke','Soltimer','Trykk','Vindhastighet',
                 'Maks vindhastighet','Snødybde','Vindretning'),
               c('Nedbør','Middeltemperatur','Maksimumstemperatur','Minimumstemperatur',
                 'Skydekke','Soltimer','Trykk','Vindhastighet',
                 'Maks vindhastighet','Snødybde','Vindretning'),
               c('Precipitation','Daily mean temperature','Daily max temperature','Daily min temperature',
                 'Cloud cover','Sunshine','Pressure','Wind speed',
                 'Wind gust','Snow depth','Wind direction'))
timescales <- rbind(c('Dag','Måned','Sesong','År'),
                    c('Dag','Måned','Sesong','År'),
                    c('Day','Month','Season','Year'))
lab.speficicday <- c('Utvalgt dag','Utvald dag','Specific day')
aspects <- aspectsP
tscales <- c("day","month","season","year"); names(tscales) <- tscales
highlighting <- c('None','New records','Top 10','Low 10')

##-----------------------------------------------------------------------------------------------------------

names(languages) <- language.names

## Get a list of files with data - Get the file names of the data
fnames <- list.files(path='data',pattern='.nc',full.names = TRUE)
fnames <- fnames[grep('.nc',fnames,fixed=TRUE)]
fnames <- fnames[grep(src[reg1],fnames)]

## Extract variables
#varids <- list.files(path='data',pattern='.nc',full.names = FALSE)
varids <- substr(fnames,6,nchar(fnames))
varids <- varids[grep(src[reg1],fnames)]
varids <- substr(varids,1,regexpr('.',varids,fixed=TRUE)-1)
#print(varids)

## Setting for menues etc. 
ci <- c(1:length(varids)); names(ci) <- vari2name(varids)

## Extract information about summary statistics from the netCDF-files
ipre <- ci[varids=='precip']
stattype <- getstattype(fnames[ipre])
print(stattype); print(varids)

## Get the names of locations, etc.
print('Get metadata & summary statistics')
Y <- retrieve.stationsummary(fnames[ipre])
print('Get first station')
y <- retrieve.station(fnames[ipre],stid=Y$station.id[Y$location=="Oslo - blind"],verbose=verbose)
#y <- retrieve.station(fnames[1],stid=Y$station.id[Y$location=="De bilt"],verbose=verbose)

print('Get range for the sliding bar')
statisticmin <- round(min(Y$mean,na.rm=TRUE))
statisticmax <- round(max(Y$mean,na.rm=TRUE))

cntrs <- c('All',rownames(table(Y$country)))

## The variable 'filter' is used for zoomin in on the data based on their range of values
filter <- rep(TRUE,length(Y$station.id))

print('--- <Settings OK> ---')




