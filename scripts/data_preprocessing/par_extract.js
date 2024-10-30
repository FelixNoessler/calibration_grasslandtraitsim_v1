function bufferPoints(radius, bounds) {
    return function(pt) {
        pt = ee.Feature(pt);
        return bounds ? pt.buffer(radius).bounds() : pt.buffer(radius);
    };
}

function zonalStats(ic, fc, params) {
    // Initialize internal params dictionary.
    var _params = {
        reducer: ee.Reducer.mean(),
        scale: null,
        crs: null,
        bands: null,
        bandsRename: null,
        imgProps: null,
        imgPropsRename: null,
        datetimeName: 'datetime',
        datetimeFormat: 'YYYY-MM-dd HH:mm:ss'
};

// Replace initialized params with provided params.
if (params) {
    for (var param in params) {
    _params[param] = params[param] || _params[param];
    }
}

// Set default parameters based on an image representative.
var imgRep = ic.first();
var nonSystemImgProps = ee.Feature(null)
    .copyProperties(imgRep).propertyNames();
if (!_params.bands) _params.bands = imgRep.bandNames();
if (!_params.bandsRename) _params.bandsRename = _params.bands;
if (!_params.imgProps) _params.imgProps = nonSystemImgProps;
if (!_params.imgPropsRename) _params.imgPropsRename = _params.imgProps;

// Map the reduceRegions function over the image collection.
var results = ic.map(function(img) {
    // Select bands (optionally rename), set a datetime & timestamp property.
    img = ee.Image(img.select(_params.bands, _params.bandsRename))
    .set(_params.datetimeName, img.date().format(_params.datetimeFormat))
    .set('timestamp', img.get('system:time_start'));

    // Define final image property dictionary to set in output features.
    var propsFrom = ee.List(_params.imgProps)
    .cat(ee.List([_params.datetimeName, 'timestamp']));
    var propsTo = ee.List(_params.imgPropsRename)
    .cat(ee.List([_params.datetimeName, 'timestamp']));
    var imgProps = img.toDictionary(propsFrom).rename(propsFrom, propsTo);

    // Subset points that intersect the given image.
    var fcSub = fc.filterBounds(img.geometry());

    // Reduce the image by regions.
    return img.reduceRegions({
    collection: fcSub,
    reducer: _params.reducer,
    scale: _params.scale,
    crs: _params.crs
    })
    // Add metadata to each feature.
    .map(function(f) {
    return f.set(imgProps);
    });
}).flatten().filter(ee.Filter.notNull(_params.bandsRename));

return results;
}

// -----------------------------------
var start_year = 2006
var end_year = 2022 
var MODIS_PAR = ee.ImageCollection('MODIS/061/MCD18C2')
                .filter(
                    ee.Filter.date(
                    start_year + '-01-01', 
                    end_year + '-12-31'));            

// -----------------------------------
var pts = ee.FeatureCollection([
    ee.Feature(ee.Geometry.Point([13.75, 52.96]), {plot_id: 'SCH'}),
    ee.Feature(ee.Geometry.Point([10.37, 51.25]), {plot_id: 'HAI'}),
    ee.Feature(ee.Geometry.Point([9.41, 48.43]), {plot_id: 'ALB'})
]);
var ptsExplo = pts.map(bufferPoints(10000, false));

// -----------------------------------
var params = {
    reducer: ee.Reducer.median(),
    scale: 1000,
    crs: 'EPSG:5243',
    bands: ['GMT_0000_PAR', 'GMT_0300_PAR', 'GMT_0600_PAR', 'GMT_0900_PAR', 'GMT_1200_PAR', 'GMT_1500_PAR', 'GMT_1800_PAR', 'GMT_2100_PAR'],
    bandsRename: ['PAR_00', 'PAR_03', 'PAR_06', 'PAR_09', 'PAR_12', 'PAR_15', 'PAR_18', 'PAR_21'],
    datetimeName: 'date',
    datetimeFormat: 'YYYY-MM-dd'
};
var ptsModisStats = zonalStats(MODIS_PAR, ptsExplo, params);

// -----------------------------------
var removeGeometry = function(feature) {
    return feature.setGeometry(null);
};
var final_output = ptsModisStats.map(removeGeometry);

// -----------------------------------
Export.table.toDrive({
    collection: final_output,
    folder: 'GEE', 
    description: 'PAR_' + start_year + '_' + end_year,
    fileFormat: 'CSV'
});  