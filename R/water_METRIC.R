#' Estimates Net Radiation as in METRIC Model
#' @param image.DN         raw imagen in digital counts to evaluate
#' @param WeatherStation   Weather Station data, can be a waterWeatherStation 
#' object
#' @param MTL              Landsat metadata file
#' @param sat              Landsat satellite version. "L7" or "L8"
#' @param thermalband      Landsat low gain thermalband
#' @param plain            Logical. If TRUE surface is assumed plain
#' @param DEM              Digital Elevation Model of the study area. Not needed
#' if plain = TRUE
#' @param aoi              SpatialPolygon object with limits of Area of interest
#' @param alb.coeff        coefficient to transform narrow to broad band albedo.
#' See Details.
#' @param LAI.method       Method used to estimate LAI from spectral data. 
#' See Details.
#' @author Guillermo F Olmedo, \email{guillermo.olmedo@@gmail.com}
#' @references 
#' R. G. Allen, M. Tasumi, and R. Trezza, "Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC) - Model" Journal of Irrigation and Drainage Engineering, vol. 133, p. 380, 2007
#' @export
METRIC.Rn <- function(image.DN, WeatherStation, MTL, sat = "auto", thermalband, 
                      alb.coeff = "Tasumi", LAI.method = "metric2010", 
                      plain = TRUE, DEM, aoi){
  path=getwd()
  #pb <- txtProgressBar(min = 0, max = 100, style = 3)
  if(plain==TRUE){
    DEM <- raster(image.DN[[1]])
    values(DEM) <- WeatherStation$location$elev
  }
  surface.model <-METRICtopo(DEM)
  #setTxtProgressBar(pb, 3)
  solar.angles.r <- solarAngles(surface.model = surface.model, 
                                WeatherStation = WeatherStation, MTL = MTL)
  Rs.inc <- incSWradiation(surface.model = surface.model, 
                           solar.angles = solar.angles.r, 
                           WeatherStation = WeatherStation)
  if(sat=="L7" | sat=="L8"){
  image.TOAr <- calcTOAr(image.DN = image.DN, sat=sat, MTL = MTL, 
                         incidence.rel = solar.angles.r$incidence.rel)
  image.SR <- calcSR(image.TOAr=image.TOAr, sat = sat, 
                     surface.model=surface.model, 
                     incidence.hor = solar.angles.r$incidence.hor, 
                     WeatherStation=WeatherStation)}
  if(sat=="MODIS"){image.SR <- image.DN}
  albedo <- albedo(image.SR = image.SR,  coeff=alb.coeff, sat=sat)
  #setTxtProgressBar(pb, 6)
  if(sat=="MODIS"){image.TOAr <- image.DN} # Only used for LAI estimation,
                                           # and some LAI models, use SR
  LAI <- LAI(method = LAI.method, image = image.TOAr, L=0.1)
  if(sat=="L7" | sat=="L8"){
  Ts <- surfaceTemperature(LAI=LAI, sat = sat, thermalband = thermalband,
                           WeatherStation = WeatherStation)}
  if(sat=="MODIS"){Ts <- image.DN$LST}
  #setTxtProgressBar(pb, 35)
  Rl.out <- outLWradiation(LAI = LAI, Ts=Ts)
  Rl.inc <- incLWradiation(WeatherStation,DEM = surface.model$DEM, 
                           solar.angles = solar.angles.r, Ts= Ts)
  Rn <- netRadiation(LAI, albedo, Rs.inc, Rl.inc, Rl.out)
  plot(Rn, main="METRIC Net Radiation")
  return(Rn)
}

#' Estimates Net Radiation as in METRIC Model
#' @param image.DN         raw imagen in digital counts to evaluate
#' @param WeatherStation   Weather Station data, can be a waterWeatherStation 
#' object
#' @param Rn               RasterLayer with Net Radiation data in W/m2
#' @param plain            Logical. If TRUE surface is assumed plain
#' @param DEM              Digital Elevation Model of the study area. Not needed
#' if plain = TRUE
#' @param aoi              SpatialPolygon object with limits of Area of interest
#' @author Guillermo F Olmedo, \email{guillermo.olmedo@@gmail.com}
#' @references 
#' R. G. Allen, M. Tasumi, and R. Trezza, "Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC) - Model" Journal of Irrigation and Drainage Engineering, vol. 133, p. 380, 2007
#' @export
METRIC.G <- function(image.DN, WeatherStation=WeatherStation, Rn,  
                     plain = TRUE, DEM, aoi){
  path=getwd()
  if(plain==TRUE){
    DEM <- raster(image.DN[[1]])
    values(DEM) <- WeatherStation$location$elev
  } 
  surface.model <-METRICtopo(DEM)
  solar.angles.r <- solarAngles(surface.model = surface.model)
  image.TOAr <- calcTOAr(image.DN = image.DN, 
                         incidence.rel = solar.angles.r$incidence.rel)
  image.SR <- calcSR(image.TOAr=image.TOAr, 
                      surface.model=surface.model, 
                      incidence.hor = solar.angles.r$incidence.hor, 
                      WeatherStation=WeatherStation, sat="auto")
  albedo <- albedo(image.SR = image.SR)
  Ts <- surfaceTemperature(sat = "auto" )
  G <- soilHeatFlux(image = image.SR, Ts=Ts,albedo=albedo, Rn)
}


#' Estimates Energy Balance using METRIC2010 Model
#' @param image.DN         raw imagen in digital counts to evaluate
#' @param image.SR         L8 ONLY. Surface reflectance imagen. water package does not 
#' include a model to calculate surface reflectance for Landsat 8 images. Landsat 8 users 
#' should download precalculated surface reflectances from espa website 
#' (espa.cr.usgs.gov). 
#' @param WeatherStation   Weather Station data, can be a waterWeatherStation 
#' object
#' @param MTL              Landsat metadata file
#' @param sat              Landsat satellite version. "L7" or "L8"
#' @param thermalband      Landsat low gain thermalband
#' @param plain            Logical. If TRUE surface is assumed plain
#' @param DEM              Digital Elevation Model of the study area. Not needed
#' if plain = TRUE
#' @param aoi              SpatialPolygon object with limits of Area of interest
#' @param alb.coeff        coefficient to transform narrow to broad band albedo.
#' See Details.
#' @param LST.method       Method for land surface temperature estimation. "SC" 
#' for single channel or "SW" for split window algorithm. 
#' "SW" is only available for L8. See \code{water::surfaceTemperature}
#' @param LAI.method       Method used to estimate LAI from spectral data. 
#' See Details.
#' @param L                L value for SAVI calculation
#' @param Zom.method       method selected to calculate momentum roughness 
#' length. Use "short.crops" for short crops methods from Allen et al (2007); 
#' "custom" for custom method also in Allen et al (2007); Or "Perrier" to use 
#' Perrier equation as in Santos et al (2012) and Pocas et al (2014).
#' @param anchors.method   method to select anchor pixels. Currently only 
#' "CITRA-MCB" automatic method available.
#' @param n                number of pair of anchors pixels to calculate
#' @param ETp.coef         ETp coefficient usually 1.05 or 1.2 for alfalfa
#' @param Z.om.ws          momentum roughness lenght for WeatherStation. Usually
#' 0.0018 or 0.03 for long grass
#' @param verbose          Logical. If TRUE will print aditional data to console
#' @details
#' There are differents models to convert narrowband data to broadband albedo. 
#' You can choose alb.coeff ="Tasumi" to use Tasumi et al (2008) coefficients, 
#' calculated for Landsat 7; alb.coeff ="Liang" to use Liang Landsat 7 
#' coefficients or "Olmedo" to use Olmedo coefficients for Landsat 8.
#' @author Guillermo F Olmedo, \email{guillermo.olmedo@@gmail.com}
#' @references 
#' R. G. Allen, M. Tasumi, and R. Trezza, "Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC) - Model" Journal of Irrigation and Drainage Engineering, vol. 133, p. 380, 2007
#' @export
METRIC.EB <- function(image.DN, image.SR, WeatherStation, MTL, sat = "auto",
                      thermalband, plain=TRUE, DEM, aoi,
                      alb.coeff = "Tasumi", LST.method = "SC",
                      LAI.method = "metric2010", L = 0.1,
                      Zom.method = "short.crops", anchors.method = "CITRA-MCB",
                      n = 1, ETp.coef= 1.05, Z.om.ws=0.0018, 
                      verbose = FALSE){
  path=getwd()
  #pb <- txtProgressBar(min = 0, max = 100, style = 3)
  if(plain==TRUE){
    DEM <- raster(image.DN[[1]])
    values(DEM) <- WeatherStation$location$elev
  }
  surface.model <-METRICtopo(DEM)
  #setTxtProgressBar(pb, 3)
  if(missing(MTL)){MTL <- list.files(path = path, pattern = "MTL.txt", full.names = T)}
  solar.angles.r <- solarAngles(surface.model = surface.model, 
                                WeatherStation = WeatherStation, MTL = MTL)
  Rs.inc <- incSWradiation(surface.model = surface.model, 
                           solar.angles = solar.angles.r, 
                           WeatherStation = WeatherStation)
  if(sat=="L7" | sat=="L8"){
    image.TOAr <- calcTOAr(image.DN = image.DN, sat=sat, MTL = MTL,
                           incidence.rel = solar.angles.r$incidence.rel)
    if(sat=="L7"){
      image.SR <- calcSR(image.TOAr=image.TOAr, sat = sat, 
                         surface.model=surface.model, 
                         incidence.hor = solar.angles.r$incidence.hor, 
                         WeatherStation=WeatherStation)}
    }
  if(sat=="MODIS"){image.SR <- image.DN}
  albedo <- albedo(image.SR = image.SR,  coeff=alb.coeff, sat=sat)
  #setTxtProgressBar(pb, 6)
  if(sat=="MODIS"){image.TOAr <- image.DN} # Only used for LAI estimation,
  # and some LAI models, use SR
  LAI <- LAI(method = LAI.method, image = image.TOAr, L=L)
  if(sat=="L7" | sat=="L8"){
    Ts <- surfaceTemperature(LAI=LAI, sat = sat, image.DN=image.DN,
                             WeatherStation = WeatherStation, method = LST.method)}
  if(sat=="MODIS"){Ts <- image.DN$LST}
  #setTxtProgressBar(pb, 35)
  Rl.out <- outLWradiation(LAI = LAI, Ts=Ts)
  Rl.inc <- incLWradiation(WeatherStation,DEM = surface.model$DEM, 
                           solar.angles = solar.angles.r, Ts= Ts)
  Rn <- netRadiation(LAI, albedo, Rs.inc, Rl.inc, Rl.out)
  Rn[Rn < 0]  <-  0
  #setTxtProgressBar(pb, 40)
  G <- soilHeatFlux(image = image.SR, Ts=Ts,albedo=albedo, 
                    Rn=Rn, LAI=LAI)
  G[G < 0]  <-  0
  Z.om <- momentumRoughnessLength(LAI=LAI, mountainous = TRUE, 
                                  method = Zom.method, 
                                  surface.model = surface.model)
  par(mfrow=c(1,2))
  hot.and.cold <- calcAnchors(image = image.TOAr, Ts = Ts, LAI = LAI, plots = T,
                              albedo = albedo, Z.om = Z.om, n = n, 
                              anchors.method = anchors.method, WeatherStation = WeatherStation,
                              deltaTemp = 5, verbose = verbose)
  print(hot.and.cold)
  #setTxtProgressBar(pb, 45)
  H <- calcH(anchors = hot.and.cold, Ts = Ts, Z.om = Z.om, mountainous = !plain,
             WeatherStation = WeatherStation, ETp.coef = ETp.coef,
             Z.om.ws = Z.om.ws, DEM = DEM, Rn = Rn, G = G, verbose = verbose)
  par(mfrow=c(1,1))
  #setTxtProgressBar(pb, 99)
  H <-  H$H
  LE <- Rn - G - H
  LE[LE < 0]  <-  0
  EB <- stack(Rn, G, H, LE, Ts)
  EB <- saveLoadClean(imagestack = EB,
                stack.names = c("NetRadiation", "SoilHeat", "SensibleHeat", 
                                "LatentHeat", "surfaceTemperature"), 
                file = "EB", overwrite=TRUE)
  #setTxtProgressBar(pb, 100)
  return(EB)
}
  
