//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

/// A geographic point with latitude and longitude coordinates
pub const Point = struct {
    lat: f64,
    lng: f64,

    /// Create a new point with validation
    pub fn init(lat: f64, lng: f64) !Point {
        if (lat < -90.0 or lat > 90.0) {
            return error.InvalidLatitude;
        }
        if (lng < -180.0 or lng > 180.0) {
            return error.InvalidLongitude;
        }
        return .{ .lat = lat, .lng = lng };
    }

    /// Calculate haversine distance to another point in kilometers
    pub fn distance(self: Point, other: Point) f64 {
        const earth_radius_km = 6371.0;
        const dlat = std.math.degreesToRadians(other.lat - self.lat);
        const dlng = std.math.degreesToRadians(other.lng - self.lng);
        const a = std.math.sin(dlat / 2) * std.math.sin(dlat / 2) +
            std.math.cos(std.math.degreesToRadians(self.lat)) * std.math.cos(std.math.degreesToRadians(other.lat)) *
                std.math.sin(dlng / 2) * std.math.sin(dlng / 2);
        const c = 2 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1 - a));
        return earth_radius_km * c;
    }
};

/// A line string represented as a slice of points
pub const Line = []const Point;

/// A polygon represented as a slice of points (simple polygon)
/// Points should be ordered counterclockwise for exterior rings
pub const Polygon = []const Point;

/// Multi-part geometries for complex shapes
pub const MultiPoint = []const Point;
pub const MultiLineString = []const Line;
pub const MultiPolygon = []const Polygon;

/// A bounding box for spatial queries
pub const BoundingBox = struct {
    min_lat: f64,
    max_lat: f64,
    min_lng: f64,
    max_lng: f64,

    /// Create a bounding box from a polygon
    pub fn fromPolygon(polygon: Polygon) BoundingBox {
        if (polygon.len == 0) return .{ .min_lat = 0, .max_lat = 0, .min_lng = 0, .max_lng = 0 };

        var min_lat = polygon[0].lat;
        var max_lat = polygon[0].lat;
        var min_lng = polygon[0].lng;
        var max_lng = polygon[0].lng;

        for (polygon) |point| {
            min_lat = @min(min_lat, point.lat);
            max_lat = @max(max_lat, point.lat);
            min_lng = @min(min_lng, point.lng);
            max_lng = @max(max_lng, point.lng);
        }

        return .{
            .min_lat = min_lat,
            .max_lat = max_lat,
            .min_lng = min_lng,
            .max_lng = max_lng,
        };
    }

    /// Check if a point is inside the bounding box
    pub fn contains(self: BoundingBox, point: Point) bool {
        return point.lat >= self.min_lat and point.lat <= self.max_lat and
            point.lng >= self.min_lng and point.lng <= self.max_lng;
    }
};

/// Calculate the area of a simple polygon using the shoelace formula
/// Returns area in square degrees (not meters - for geographic coords)
pub fn polygonArea(polygon: Polygon) f64 {
    if (polygon.len < 3) return 0.0;

    var area: f64 = 0.0;
    var j = polygon.len - 1;

    for (polygon, 0..) |pi, i| {
        const pj = polygon[j];
        area += (pj.lng - pi.lng) * (pj.lat + pi.lat);
        j = i;
    }

    return @abs(area) / 2.0;
}

/// Calculate bounding box for multi-polygon
pub fn multiPolygonBoundingBox(multi_polygon: MultiPolygon) BoundingBox {
    if (multi_polygon.len == 0 or multi_polygon[0].len == 0) {
        return .{ .min_lat = 0, .max_lat = 0, .min_lng = 0, .max_lng = 0 };
    }

    var bbox = BoundingBox.fromPolygon(multi_polygon[0]);

    for (multi_polygon[1..]) |polygon| {
        const poly_bbox = BoundingBox.fromPolygon(polygon);
        bbox.min_lat = @min(bbox.min_lat, poly_bbox.min_lat);
        bbox.max_lat = @max(bbox.max_lat, poly_bbox.max_lat);
        bbox.min_lng = @min(bbox.min_lng, poly_bbox.min_lng);
        bbox.max_lng = @max(bbox.max_lng, poly_bbox.max_lng);
    }

    return bbox;
}

/// Parse a GeoJSON Point string into a Point
pub fn parseGeoJSONPoint(allocator: std.mem.Allocator, json_str: []const u8) !Point {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidGeoJSON;

    const type_str = root.object.get("type") orelse return error.InvalidGeoJSON;
    if (type_str != .string or !std.mem.eql(u8, type_str.string, "Point")) return error.InvalidGeoJSON;

    const coords = root.object.get("coordinates") orelse return error.InvalidGeoJSON;
    if (coords != .array or coords.array.items.len != 2) return error.InvalidGeoJSON;

    const lng = coords.array.items[0];
    const lat = coords.array.items[1];
    if (lng != .float or lat != .float) return error.InvalidGeoJSON;

    return try Point.init(lat.float, lng.float);
}

/// Parse a GeoJSON LineString into a Line (allocated slice)
pub fn parseGeoJSONLineString(allocator: std.mem.Allocator, json_str: []const u8) ![]Point {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidGeoJSON;

    const type_str = root.object.get("type") orelse return error.InvalidGeoJSON;
    if (type_str != .string or !std.mem.eql(u8, type_str.string, "LineString")) return error.InvalidGeoJSON;

    const coords = root.object.get("coordinates") orelse return error.InvalidGeoJSON;
    if (coords != .array) return error.InvalidGeoJSON;

    var line = try allocator.alloc(Point, coords.array.items.len);
    errdefer allocator.free(line);

    for (coords.array.items, 0..) |coord, i| {
        if (coord != .array or coord.array.items.len != 2) return error.InvalidGeoJSON;
        const lng = coord.array.items[0];
        const lat = coord.array.items[1];
        if (lng != .float or lat != .float) return error.InvalidGeoJSON;
        line[i] = try Point.init(lat.float, lng.float);
    }

    return line;
}

/// Parse a GeoJSON Polygon into a Polygon (allocated slice, assumes simple polygon)
pub fn parseGeoJSONPolygon(allocator: std.mem.Allocator, json_str: []const u8) ![]Point {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidGeoJSON;

    const type_str = root.object.get("type") orelse return error.InvalidGeoJSON;
    if (type_str != .string or !std.mem.eql(u8, type_str.string, "Polygon")) return error.InvalidGeoJSON;

    const coords = root.object.get("coordinates") orelse return error.InvalidGeoJSON;
    if (coords != .array or coords.array.items.len == 0) return error.InvalidGeoJSON;

    // Assume first ring is the exterior
    const exterior = coords.array.items[0];
    if (exterior != .array) return error.InvalidGeoJSON;

    var polygon = try allocator.alloc(Point, exterior.array.items.len);
    errdefer allocator.free(polygon);

    for (exterior.array.items, 0..) |coord, i| {
        if (coord != .array or coord.array.items.len != 2) return error.InvalidGeoJSON;
        const lng = coord.array.items[0];
        const lat = coord.array.items[1];
        if (lng != .float or lat != .float) return error.InvalidGeoJSON;
        polygon[i] = try Point.init(lat.float, lng.float);
    }

    return polygon;
}

/// Serialize a Point to GeoJSON string
pub fn pointToGeoJSON(point: Point, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"type\":\"Point\",\"coordinates\":[{d:.6},{d:.6}]}}", .{ point.lng, point.lat });
}

/// Project a WGS84 point to Web Mercator coordinates
pub fn projectToWebMercator(point: Point) WebMercatorPoint {
    const earth_radius = 6378137.0; // meters
    const x = point.lng * (earth_radius * std.math.pi / 180.0);
    const lat_rad = point.lat * std.math.pi / 180.0;
    const y = earth_radius * std.math.log(f64, std.math.e, std.math.tan(std.math.pi / 4.0 + lat_rad / 2.0));
    return .{ .x = x, .y = y };
}

/// A point in Web Mercator projection (meters from origin)
pub const WebMercatorPoint = struct {
    x: f64,
    y: f64,
};

/// Check if a polygon contains a point using ray casting algorithm
pub fn polygonContainsPoint(polygon: Polygon, point: Point) bool {
    if (polygon.len < 3) return false;

    var inside = false;
    var j = polygon.len - 1;

    for (polygon, 0..) |_, i| {
        const pi = polygon[i];
        const pj = polygon[j];

        if (((pi.lng > point.lng) != (pj.lng > point.lng)) and
            (point.lat < (pj.lat - pi.lat) * (point.lng - pi.lng) / (pj.lng - pi.lng) + pi.lat))
        {
            inside = !inside;
        }
        j = i;
    }

    return inside;
}

/// Find intersection point of two line segments
/// Returns null if no intersection or parallel
pub fn lineSegmentIntersection(p1: Point, p2: Point, p3: Point, p4: Point) ?Point {
    const denom = (p1.lng - p2.lng) * (p3.lat - p4.lat) - (p1.lat - p2.lat) * (p3.lng - p4.lng);
    if (@abs(denom) < 1e-10) return null; // Parallel or coincident

    const t = ((p1.lng - p3.lng) * (p3.lat - p4.lat) - (p1.lat - p3.lat) * (p3.lng - p4.lng)) / denom;
    const u = -((p1.lng - p2.lng) * (p1.lat - p3.lat) - (p1.lat - p2.lat) * (p1.lng - p3.lng)) / denom;

    if (t >= 0 and t <= 1 and u >= 0 and u <= 1) {
        const ix = p1.lng + t * (p2.lng - p1.lng);
        const iy = p1.lat + t * (p2.lat - p1.lat);
        return Point.init(iy, ix) catch null; // Note: lat, lng order
    }

    return null;
}

/// Basic raster data structure for elevation/imagery
pub const Raster = struct {
    width: usize,
    height: usize,
    data: []f64,
    bounds: BoundingBox,

    /// Initialize a new raster
    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, bounds: BoundingBox) !Raster {
        const data = try allocator.alloc(f64, width * height);
        @memset(data, 0.0);
        return .{
            .width = width,
            .height = height,
            .data = data,
            .bounds = bounds,
        };
    }

    /// Deinitialize the raster
    pub fn deinit(self: *Raster, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    /// Get value at coordinates
    pub fn get(self: Raster, x: usize, y: usize) f64 {
        if (x >= self.width or y >= self.height) return 0.0;
        return self.data[y * self.width + x];
    }

    /// Set value at coordinates
    pub fn set(self: *Raster, x: usize, y: usize, value: f64) void {
        if (x >= self.width or y >= self.height) return;
        self.data[y * self.width + x] = value;
    }
};

test "Point initialization" {
    const p = try Point.init(40.7128, -74.0060); // New York City
    try std.testing.expectEqual(@as(f64, 40.7128), p.lat);
    try std.testing.expectEqual(@as(f64, -74.0060), p.lng);
}

test "Point validation" {
    // Test invalid latitude
    try std.testing.expectError(error.InvalidLatitude, Point.init(91.0, 0.0));
    // Test invalid longitude
    try std.testing.expectError(error.InvalidLongitude, Point.init(0.0, 181.0));
}

test "Haversine distance" {
    const p1 = try Point.init(52.2296756, 21.0122287);
    const p2 = try Point.init(41.8919300, 12.5113300);
    const distance = p1.distance(p2);
    try std.testing.expectApproxEqAbs(@as(f64, 1315.510), distance, 1.0);
}

test "Bounding box from polygon" {
    const p1 = try Point.init(10.0, 10.0);
    const p2 = try Point.init(20.0, 20.0);
    const p3 = try Point.init(10.0, 20.0);
    const polygon = [_]Point{ p1, p2, p3 };
    const bbox = BoundingBox.fromPolygon(&polygon);
    try std.testing.expectEqual(@as(f64, 10.0), bbox.min_lat);
    try std.testing.expectEqual(@as(f64, 20.0), bbox.max_lat);
    try std.testing.expectEqual(@as(f64, 10.0), bbox.min_lng);
    try std.testing.expectEqual(@as(f64, 20.0), bbox.max_lng);
}

test "Point in polygon (ray casting)" {
    const p1 = try Point.init(0.0, 0.0);
    const p2 = try Point.init(10.0, 0.0);
    const p3 = try Point.init(10.0, 10.0);
    const p4 = try Point.init(0.0, 10.0);
    const polygon = [_]Point{ p1, p2, p3, p4 };
    const inside_point = try Point.init(5.0, 5.0);
    const outside_point = try Point.init(15.0, 5.0);
    try std.testing.expect(polygonContainsPoint(&polygon, inside_point));
    try std.testing.expect(!polygonContainsPoint(&polygon, outside_point));
}

test "GeoJSON Point parsing" {
    const json = "{\"type\":\"Point\",\"coordinates\":[-74.0060,40.7128]}";
    const point = try parseGeoJSONPoint(std.testing.allocator, json);
    try std.testing.expectEqual(@as(f64, 40.7128), point.lat);
    try std.testing.expectEqual(@as(f64, -74.0060), point.lng);
}

test "GeoJSON Point serialization" {
    const point = try Point.init(40.7128, -74.0060);
    const json = try pointToGeoJSON(point, std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\":\"Point\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "-74.006") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "40.7128") != null);
}

test "GeoJSON LineString parsing" {
    const json = "{\"type\":\"LineString\",\"coordinates\":[[-74.0,40.7],[-87.6,41.9]]}";
    const line = try parseGeoJSONLineString(std.testing.allocator, json);
    defer std.testing.allocator.free(line);
    try std.testing.expectEqual(@as(usize, 2), line.len);
    try std.testing.expectEqual(@as(f64, 40.7), line[0].lat);
    try std.testing.expectEqual(@as(f64, -74.0), line[0].lng);
}

test "GeoJSON Polygon parsing" {
    const json = "{\"type\":\"Polygon\",\"coordinates\":[[[-74.0,40.7],[-87.6,41.9],[-74.0,41.9],[-74.0,40.7]]]}";
    const polygon = try parseGeoJSONPolygon(std.testing.allocator, json);
    defer std.testing.allocator.free(polygon);
    try std.testing.expectEqual(@as(usize, 4), polygon.len);
    try std.testing.expectEqual(@as(f64, 40.7), polygon[0].lat);
}

test "Web Mercator projection" {
    const p = try Point.init(40.7128, -74.0060); // New York City
    const mercator = projectToWebMercator(p);
    // Check that x is negative (west) and y is positive (north)
    try std.testing.expect(mercator.x < 0);
    try std.testing.expect(mercator.y > 0);
    // Check approximate range
    try std.testing.expectApproxEqAbs(@as(f64, -8.2e6), mercator.x, 1e6);
    try std.testing.expectApproxEqAbs(@as(f64, 5e6), mercator.y, 1e6);
}

test "Web Mercator projection (origin)" {
    const point = try Point.init(0.0, 0.0); // Equator, prime meridian
    const mercator = projectToWebMercator(point);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), mercator.x, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), mercator.y, 1.0);
}

test "Polygon area calculation" {
    const polygon = [_]Point{
        try Point.init(0.0, 0.0),
        try Point.init(4.0, 0.0),
        try Point.init(4.0, 4.0),
        try Point.init(0.0, 4.0),
    };
    const area = polygonArea(&polygon);
    try std.testing.expectApproxEqAbs(@as(f64, 16.0), area, 0.1);
}

test "Multi-polygon bounding box" {
    const poly1 = [_]Point{
        try Point.init(0.0, 0.0),
        try Point.init(2.0, 0.0),
        try Point.init(2.0, 2.0),
        try Point.init(0.0, 2.0),
    };
    const poly2 = [_]Point{
        try Point.init(3.0, 3.0),
        try Point.init(5.0, 3.0),
        try Point.init(5.0, 5.0),
        try Point.init(3.0, 5.0),
    };
    const multi_poly = [_]Polygon{ &poly1, &poly2 };
    const bbox = multiPolygonBoundingBox(&multi_poly);
    try std.testing.expectEqual(@as(f64, 0.0), bbox.min_lat);
    try std.testing.expectEqual(@as(f64, 5.0), bbox.max_lat);
    try std.testing.expectEqual(@as(f64, 0.0), bbox.min_lng);
    try std.testing.expectEqual(@as(f64, 5.0), bbox.max_lng);
}

test "Line segment intersection" {
    const p1 = try Point.init(0.0, 0.0);
    const p2 = try Point.init(10.0, 10.0);
    const p3 = try Point.init(0.0, 10.0);
    const p4 = try Point.init(10.0, 0.0);
    const intersection = lineSegmentIntersection(p1, p2, p3, p4);
    try std.testing.expect(intersection != null);
    if (intersection) |ip| {
        try std.testing.expectApproxEqAbs(@as(f64, 5.0), ip.lat, 0.1);
        try std.testing.expectApproxEqAbs(@as(f64, 5.0), ip.lng, 0.1);
    }
}

test "Line segment intersection (no intersection)" {
    const p1 = try Point.init(0.0, 0.0);
    const p2 = try Point.init(10.0, 0.0);
    const p3 = try Point.init(0.0, 10.0);
    const p4 = try Point.init(10.0, 20.0);
    const intersection = lineSegmentIntersection(p1, p2, p3, p4);
    try std.testing.expect(intersection == null);
}

test "Line segment intersection (parallel)" {
    const p1 = try Point.init(0.0, 0.0);
    const p2 = try Point.init(10.0, 0.0);
    const p3 = try Point.init(0.0, 5.0);
    const p4 = try Point.init(10.0, 5.0);
    const intersection = lineSegmentIntersection(p1, p2, p3, p4);
    try std.testing.expect(intersection == null);
}

test "Raster operations" {
    const bbox = BoundingBox{ .min_lat = 0, .max_lat = 10, .min_lng = 0, .max_lng = 10 };
    var raster = try Raster.init(std.testing.allocator, 10, 10, bbox);
    defer raster.deinit(std.testing.allocator);

    raster.set(5, 5, 42.0);
    try std.testing.expectEqual(@as(f64, 42.0), raster.get(5, 5));
    try std.testing.expectEqual(@as(f64, 0.0), raster.get(0, 0));
}
