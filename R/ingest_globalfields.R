#' Ingest from global fields
#'
#' Read climate data from files as global fields
#'
#' @param siteinfo A data frame with rows for each site and columns `lon` for longitude, `lat` for latitude, 
#' `date_start` and `date_end` specifying required dates.
#' @param source A character used as identifiyer for the type of data source
#' (\code{"watch_wfdei"}, or \code{"cru"}).
#' @param getvars A named list of characters specifying the variable names in
#' the source dataset corresponding to standard names \code{"temp"} for temperature,
#' @param dir A character specifying the directory where data is located.
#' \code{"prec"} for precipitation, \code{"patm"} for atmospheric pressure,
#' \code{"vpd"} for vapour pressure deficit, \code{"netrad"} for net radiation,
#' \code{"swin"} for shortwave incoming radiation.
#' @param timescale A character or vector of characters, specifying the time scale of data used from
#' the respective source (if multiple time scales are available, otherwise is disregarded).
#' @param verbose if \code{TRUE}, additional messages are printed.
#'
#' @return A data frame (tibble) containing the time series of ingested data, nested for each site.
#' @import purrr dplyr
#' @export
#'
#' @examples \dontrun{inputdata <- ingest_bysite()}  
#'
ingest_globalfields <- function( siteinfo, source, getvars, dir, timescale, verbose=FALSE ){
  
  ## get a data frame with all dates for all sites
  ddf <- purrr::map(
    as.list(seq(nrow(siteinfo))),
    ~init_dates_dataframe(
      year(siteinfo$date_start[.]),
      year(siteinfo$date_end[.]),
      noleap = TRUE,
      freq = "days"))
  names(ddf) <- siteinfo$sitename
  ddf <- ddf %>%
    bind_rows(.id = "sitename") %>%
    select(-year_dec)
  
  if (source=="watch_wfdei"){
    ##----------------------------------------------------------------------
    ## Read WATCH-WFDEI data (extracting from NetCDF files for this site)
    ##----------------------------------------------------------------------
    ## temperature
    if ("temp" %in% names(getvars)){
      ddf <- ingest_globalfields_watch_byvar( ddf, siteinfo, dir, "Tair_daily" ) %>%
        dplyr::rename(temp = myvar) %>%
        dplyr::mutate(temp = temp - 273.15) %>%
        dplyr::right_join(ddf, by = c("sitename", "date"))
    }
    
    ## precipitation
    if ("prec" %in% names(getvars)){
      ddf <- ingest_globalfields_watch_byvar( ddf, siteinfo, dir, "Rainf_daily" ) %>%
        dplyr::mutate( rain = myvar ) %>%
        left_join(
          ingest_globalfields_watch_byvar( ddf, siteinfo, dir, "Snowf_daily" ) %>%
            dplyr::mutate( snow = myvar ),
          by = c("sitename", "date")
        ) %>%
        dplyr::rename(prec = (rain + snow) * 60 * 60 * 24 ) %>%  # kg/m2/s -> mm/day
        dplyr::right_join(ddf, by = c("sitename", "date"))
    }
    
    ## humidity
    if ("vpd" %in% names(getvars)){
      ddf <- ingest_globalfields_watch_byvar( ddf, siteinfo, dir, "Qair_daily" ) %>%
        dplyr::rename(qair = myvar) %>%
        dplyr::right_join(ddf, by = c("sitename", "date"))
    }
    
    ## PPFD
    if ("ppfd" %in% names(getvars)){
      kfFEC <- 2.04
      ddf <- ingest_globalfields_watch_byvar( ddf, siteinfo, dir, "SWdown_daily" ) %>%
        dplyr::rename(ppfd = myvar * kfFEC * 1.0e-6 * 60 * 60 * 24 ) %>%  # umol m-2 s-1 -> mol m-2 d-1
        dplyr::right_join(ddf, by = c("sitename", "date"))
    }
    
    if (timescale=="m"){
      rlang::abort("ingest_globalfields(): aggregating WATCH-WFDEI to monthly not implemented yet.")
    }
    
  } else if (source=="cru"){
    ##----------------------------------------------------------------------
    ## Read CRU monthly data (extracting from NetCDF files for this site)
    
    mdf <- ddf %>%
      dplyr::select(sitename, date) %>%
      dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
      dplyr::select(sitename, year, moy) %>%
      dplyr::distinct()
    
    cruvars <- c()
    
    ## temperature
    if ("temp" %in% names(getvars) || "vpd" %in% names(getvars)){
      cruvars <- c(cruvars, "temp")
      mdf <- ingest_globalfields_cru_byvar(siteinfo, dir, getvars[[ "temp" ]] ) %>%
        dplyr::select(sitename, date, myvar) %>%
        dplyr::rename(temp = myvar) %>%
        dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
        dplyr::select(-date) %>%
        dplyr::right_join(mdf, by = c("sitename", "year", "moy"))
      
    }
    
    ## precipitation
    if ("prec" %in% names(getvars)){
      cruvars <- c(cruvars, "prec")
      mdf <- ingest_globalfields_cru_byvar(siteinfo, dir, getvars[["prec"]] ) %>%
        dplyr::select(sitename, date, myvar) %>%
        dplyr::rename(prec = myvar) %>%
        dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
        dplyr::select(-date) %>%
        dplyr::right_join(mdf, by = c("sitename", "year", "moy"))
    }
    
    ## vpd from vapour pressure
    if ("vpd" %in% names(getvars)){
      cruvars <- c(cruvars, "vap")
      mdf <- ingest_globalfields_cru_byvar(siteinfo, dir, getvar[["vap"]] ) %>%
        dplyr::select(sitename, date, myvar) %>%
        dplyr::rename(vap = myvar) %>%
        dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
        dplyr::select(-date) %>%
        dplyr::right_join(mdf, by = c("sitename", "year", "moy"))
    }
    
    ## cloud cover
    if ("ccov" %in% names(getvars)){
      cruvars <- c(cruvars, "ccov")
      mdf <- ingest_globalfields_cru_byvar(siteinfo, dir, getvars[["ccov"]] ) %>%
        dplyr::select(sitename, date, myvar) %>%
        dplyr::rename(ccov = myvar) %>%
        dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
        # dplyr::select(-date) %>%
        dplyr::right_join(mdf, by = c("sitename", "year", "moy"))
    }
    
    ## wet days
    if ("wetd" %in% names(getvars)){
      cruvars <- c(cruvars, "wetd")
      mdf <- ingest_globalfields_cru_byvar(siteinfo,  dir, getvars[["wetd"]] ) %>%
        dplyr::select(sitename, date, myvar) %>%
        dplyr::rename(wetd = myvar) %>%
        dplyr::mutate(year = lubridate::year(date), moy = lubridate::month(date)) %>%
        dplyr::select(-date) %>%
        dplyr::right_join(mdf, by = c("sitename", "year", "moy"))
    }
    
    ## VPD
    ## calculated as a function of vapour pressure and temperature, vapour
    ## pressure is given by CRU data.
    if ("vap" %in% cruvars){
      ## calculate VPD (vap is in hPa)
      mdf <-  mdf %>%
        mutate( vpd_vap_cru_temp_cru = calc_vpd( eact = 1e2 * vap, tc = temp ) )
    }
    
    ## expand monthly to daily data
    if (length(cruvars)>0){
      ddf <- expand_clim_cru_monthly( mdf, cruvars ) %>%
        right_join( ddf, by = "date" )
    }
    
  }
  
  return( ddf )
  
}


##--------------------------------------------------------------------
## Extract temperature time series for a set of sites at once (opening
## each file only once).
##--------------------------------------------------------------------
ingest_globalfields_watch_byvar <- function( ddf, siteinfo, dir, varnam ){
  
  dirn <- paste0( dir, "/", varnam, "/" )
  
  ## loop over all year and months that are required
  year_start <- ddf %>%
    dplyr::pull(date) %>%
    min() %>%
    lubridate::year()
  
  year_end <- ddf %>%
    dplyr::pull(date) %>%
    max() %>%
    lubridate::year()
  
  allmonths <- 1:12
  allyears <- year_start:year_end
  
  ## construct data frame holding longitude and latitude info
  df_lonlat <- tibble(
    sitename = siteinfo$sitename,
    lon      = siteinfo$lon,
    lat      = siteinfo$lat
  )
  
  ## extract all the data
  df <- expand.grid(allmonths, allyears) %>%
    dplyr::as_tibble() %>%
    setNames(c("mo", "yr")) %>%
    rowwise() %>%
    dplyr::mutate(filename = paste0( dirn, "/", varnam, "_WFDEI_", sprintf( "%4d", yr ), sprintf( "%02d", mo ), ".nc" )) %>%
    dplyr::mutate(data = purrr::map(filename, ~extract_pointdata_allsites(., df_lonlat ) ))
  
  ## rearrange to a daily data frame
  complement_df <- function(df){
    df <- df %>%
      setNames(., c("myvar")) %>%
      mutate( dom = 1:nrow(.))
    return(df)
  }
  ddf <- df %>%
    tidyr::unnest(data) %>%
    dplyr::mutate(data = purrr::map(data, ~complement_df(.))) %>%
    tidyr::unnest(data) %>%
    dplyr::select(sitename, mo, yr, dom, myvar) %>%
    dplyr::mutate(date = lubridate::ymd(paste0(as.character(yr), "-", sprintf( "%02d", mo), "-", sprintf( "%02d", dom))) ) %>%
    dplyr::select(-mo, -yr, -dom)
  
  return( ddf )
}


##--------------------------------------------------------------------
## Extract temperature time series for a set of sites at once (opening
## each file only once).
##--------------------------------------------------------------------
ingest_globalfields_cru_byvar <- function( siteinfo, dir, varnam ){
  
  ## construct data frame holding longitude and latitude info
  df_lonlat <- tibble(
    sitename = siteinfo$sitename,
    lon      = siteinfo$lon,
    lat      = siteinfo$lat
  )
  
  ## extract the data
  filename <- list.files( dir, pattern=paste0( varnam, ".dat.nc" ) )
  df <- extract_pointdata_allsites( paste0(dir, filename), df_lonlat, get_time = TRUE ) %>%
    dplyr::mutate(data = purrr::map(data, ~setNames(., c("myvar", "date"))))
  
  ## rearrange to a monthly data frame
  mdf <- df %>%
    tidyr::unnest(data)
  
  return( mdf )
}


##--------------------------------------------------------------------
## Interpolates monthly data to daily data using polynomials or linear
## for a single year
##--------------------------------------------------------------------
expand_clim_cru_monthly <- function( mdf, cruvars ){
  
  ddf <- purrr::map( as.list(unique(mdf$year)), ~expand_clim_cru_monthly_byyr( ., mdf, cruvars ) ) %>%
    bind_rows()
  
  return( ddf )
  
}


##--------------------------------------------------------------------
## Interpolates monthly data to daily data using polynomials or linear
## for a single year
##--------------------------------------------------------------------
expand_clim_cru_monthly_byyr <- function( yr, mdf, cruvars ){
  
  nmonth <- 12
  
  startyr <- mdf$year %>% first()
  endyr   <- mdf$year %>% last()
  
  yr_pvy <- max(startyr, yr-1)
  yr_nxt <- min(endyr, yr+1)
  
  ## add first and last year to head and tail of 'mdf'
  first <- mdf[1:12,] %>% mutate( year = year - 1)
  last  <- mdf[(nrow(mdf)-11):nrow(mdf),] %>% mutate( year = year + 1 )
  
  ddf <- init_dates_dataframe( yr, yr ) %>%
    dplyr::select(-year_dec)
  
  ##--------------------------------------------------------------------
  ## air temperature: interpolate using polynomial
  ##--------------------------------------------------------------------
  if ("temp" %in% cruvars){
    mtemp     <- dplyr::filter( mdf, year==yr     )$temp
    mtemp_pvy <- dplyr::filter( mdf, year==yr_pvy )$temp
    mtemp_nxt <- dplyr::filter( mdf, year==yr_nxt )$temp
    if (length(mtemp_pvy)==0){
      mtemp_pvy <- mtemp
    }
    if (length(mtemp_nxt)==0){
      mtemp_nxt <- mtemp
    }
    
    ddf <- init_dates_dataframe( yr, yr ) %>%
      mutate( temp = monthly2daily( mtemp, "polynom", mtemp_pvy[nmonth], mtemp_nxt[1], leapyear = leap_year(yr) ) ) %>%
      right_join( ddf, by = c("date") ) %>%
      dplyr::select(-year_dec)
  }
  
  ##--------------------------------------------------------------------
  ## precipitation: interpolate using weather generator
  ##--------------------------------------------------------------------
  if ("prec" %in% cruvars){
    mprec <- dplyr::filter( mdf, year==yr )$prec
    mwetd <- dplyr::filter( mdf, year==yr )$wetd
    
    if (any(!is.na(mprec))&&any(!is.na(mwetd))){
      ddf <-  init_dates_dataframe( yr, yr ) %>%
        mutate( prec = get_daily_prec( mprec, mwetd, leapyear = leap_year(yr) ) ) %>%
        right_join( ddf, by = c("date") ) %>%
        dplyr::select(-year_dec)
    }
  }
  
  ##--------------------------------------------------------------------
  ## cloud cover: interpolate using polynomial
  ##--------------------------------------------------------------------
  if ("ccov" %in% cruvars){
    mccov     <- dplyr::filter( mdf, year==yr     )$ccov
    mccov_pvy <- dplyr::filter( mdf, year==yr_pvy )$ccov
    mccov_nxt <- dplyr::filter( mdf, year==yr_nxt )$ccov
    if (length(mccov_pvy)==0){
      mccov_pvy <- mccov
    }
    if (length(mccov_nxt)==0){
      mccov_nxt <- mccov
    }
    
    ddf <-  init_dates_dataframe( yr, yr ) %>%
      mutate( ccov_int = monthly2daily( mccov, "polynom", mccov_pvy[nmonth], mccov_nxt[1], leapyear = leap_year(yr) ) ) %>%
      ## Reduce CCOV to a maximum 100%
      mutate( ccov = ifelse( ccov_int > 100, 100, ccov_int ) ) %>%
      right_join( ddf, by = c("date") ) %>%
      dplyr::select(-year_dec)
  }
  
  ##--------------------------------------------------------------------
  ## VPD: interpolate using polynomial
  ##--------------------------------------------------------------------
  if ("vap" %in% cruvars){
    mvpd     <- dplyr::filter( mdf, year==yr     )$vpd_vap_temp
    mvpd_pvy <- dplyr::filter( mdf, year==yr_pvy )$vpd_vap_temp
    mvpd_nxt <- dplyr::filter( mdf, year==yr_nxt )$vpd_vap_temp
    if (length(mvpd_pvy)==0){
      mvpd_pvy <- mvpd
    }
    if (length(mvpd_nxt)==0){
      mvpd_nxt <- mvpd
    }
    
    ddf <- init_dates_dataframe( yr, yr ) %>%
      mutate( vpd = monthly2daily( mvpd, "polynom", mvpd_pvy[nmonth], mvpd_nxt[1], leapyear = (yr %% 4 == 0) ) ) %>%
      right_join( ddf, by = c("date") ) %>%
      dplyr::select(-year_dec)
  }
  
  return( ddf )
  
}

##--------------------------------------------------------------------
## Finds the closest land cell in the CRU dataset at the same latitude
##--------------------------------------------------------------------
find_nearest_cruland_by_lat <- function( lon, lat, filn ){
  
  if (!requireNamespace("ncdf4", quietly = TRUE))
    stop("Please, install 'ncdf4' package")
  
  nc <- ncdf4::nc_open( filn, readunlim=FALSE )
  crufield <- ncdf4::ncvar_get( nc, varid="TMP" )
  lon_vec <- ncdf4::ncvar_get( nc, varid="LON" )
  lat_vec <- ncdf4::ncvar_get( nc, varid="LAT" )
  crufield[crufield==-9999] <- NA
  ncdf4::nc_close(nc)
  
  ilon <- which.min( abs( lon_vec - lon ) )
  ilat <- which.min( abs( lat_vec - lat ) )
  
  if (!is.na(crufield[ilon,ilat])) {print("WRONG: THIS SHOULD BE NA!!!")}
  for (n in seq(2*length(lon_vec))){
    ilon_look <- (-1)^(n+1)*round((n+0.1)/2)+ilon
    if (ilon_look > length(lon_vec)) {ilon_look <- ilon_look %% length(lon_vec)} ## Wrap search around globe in latitudinal direction
    if (ilon_look < 1)               {ilon_look <- ilon_look + length(lon_vec) }
    print(paste("ilon_look",ilon_look))
    if (!is.na(crufield[ilon_look,ilat])) {
      break
    }
  }
  # if (!is.na(crufield[ilon_look,ilat])) {print("SUCCESSFULLY FOUND DATA")}
  return( lon_vec[ ilon_look ] )
  
}

##--------------------------------------------------------------------
## Extracts point data for a set of sites given by df_lonlat using
## functions from the raster package.
##--------------------------------------------------------------------
extract_pointdata_allsites <- function( filename, df_lonlat, get_time = FALSE ){
  
  ## load file using the raster library
  #print(paste("Creating raster brick from file", filename))
  if (!file.exists(filename)) rlang::abort(paste0("File not found: ", filename))
  rasta <- raster::brick(filename)
  
  df_lonlat <- raster::extract(rasta, sp::SpatialPoints(dplyr::select(df_lonlat, lon, lat)), sp = TRUE) %>%
    as_tibble() %>%
    tidyr::nest(data = c(-lon, -lat)) %>%
    right_join(df_lonlat, by = c("lon", "lat")) %>%
    mutate( data = purrr::map(data, ~dplyr::slice(., 1)) ) %>%
    dplyr::mutate(data = purrr::map(data, ~t(.))) %>%
    dplyr::mutate(data = purrr::map(data, ~as_tibble(.)))
  
  if (get_time){
    timevals <- raster::getZ(rasta)
    df_lonlat <- df_lonlat %>%
      mutate( data = purrr::map(data, ~bind_cols(., tibble(date = timevals))))
  }
  
  return(df_lonlat)
}