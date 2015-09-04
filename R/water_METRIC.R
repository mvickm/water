#' Estimates Net Radiation as in METRIC Model
#' @author Guillermo F Olmedo, \email{guillermo.olmedo@@gmail.com}
#' @references 
#' R. G. Allen, M. Tasumi, and R. Trezza, "Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC) - Model" Journal of Irrigation and Drainage Engineering, vol. 133, p. 380, 2007
#' @export
METRIC.Rn <- function(path=getwd(), image.DN, DEM, WeatherStation, aoi){
  surface.model <-METRICtopo(DEM)
  solar.angles.r <- solarAngles(surface.model = surface.model)
  Rs.inc <- incSWradiation(surface.model = surface.model, solar.angles = solar.angles.r, WeatherStation = WeatherStation)
  image.TOAr <- calcTOAr(image.DN = image.DN, incidence.rel = solar.angles.r$incidence.rel)
  image.SR <- calcSR(path=path, image.TOAr=image.TOAr, 
                      surface.model=surface.model, 
                      incidence.hor = solar.angles.r$incidence.hor, 
                      WeatherStation=WeatherStation, sat="auto", ESPA = F)
  albedo <- albedo(image.SR = image.SR, sat="auto")
  LAI <- LAI(method = "metric2010", image = image.TOAr, L=0)
  Ts <- surfaceTemperature(sat = "auto", LAI=LAI)
  Rl.out <- outLWradiation(LAI = LAI, Ts=Ts)
  Rl.inc <- incLWradiation(WeatherStation,DEM = surface.model$DEM, solar.angles = solar.angles.r)
  surf.emissivity <- 0.95 + 0.01 * LAI 
  Rn <- Rs.inc - albedo*Rs.inc + Rl.inc - Rl.out - (1-surf.emissivity)*Rl.inc
  plot(Rn, main="METRIC Net Radiation")
  return(Rn)
}

#' Estimates Net Radiation as in METRIC Model
#' @author Guillermo F Olmedo, \email{guillermo.olmedo@@gmail.com}
#' @references 
#' R. G. Allen, M. Tasumi, and R. Trezza, "Satellite-based energy balance for mapping evapotranspiration with internalized calibration (METRIC) - Model" Journal of Irrigation and Drainage Engineering, vol. 133, p. 380, 2007
#' @export
METRIC.G <- function(path=getwd(), Rn, DEM, image.DN, WeatherStation=WeatherStation){
  surface.model <-METRICtopo(DEM)
  solar.angles.r <- solarAngles(surface.model = surface.model)
  image.TOAr <- calcTOAr(image.DN = image.DN, incidence.rel = solar.angles.r$incidence.rel)
  image.SR <- calcSR(path=path, image.TOAr=image.TOAr, 
                      surface.model=surface.model, 
                      incidence.hor = solar.angles.r$incidence.hor, 
                      WeatherStation=WeatherStation, sat="auto", ESPA = F)
  albedo <- albedo(image.SR = image.SR, sat="auto")
  Ts <- surfaceTemperature(sat = "auto", image.TOAr = image.TOAr)
  G <- soilHeatFlux(image = image.SR, Ts=Ts,albedo=albedo, Rn)
}