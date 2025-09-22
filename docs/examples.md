# Examples

This document contains practical examples of using GhostMap for various GIS tasks.

## Basic Geometry Operations

### Creating and Using Points

```zig
const std = @import("std");
const ghostmap = @import("ghostmap");

pub fn main() !void {
    // Create points
    const nyc = try ghostmap.Point.init(40.7128, -74.0060);
    const london = try ghostmap.Point.init(51.5074, -0.1278);

    // Calculate distance
    const distance = nyc.distance(london);
    std.debug.print("Distance: {d} km\n", .{distance});

    // Project to Web Mercator
    const mercator = ghostmap.projectToWebMercator(nyc);
    std.debug.print("Web Mercator: x={d}, y={d}\n", .{mercator.x, mercator.y});
}
```

### Working with Polygons

```zig
pub fn polygonExample() !void {
    // Create a simple square polygon
    const polygon = [_]ghostmap.Point{
        try ghostmap.Point.init(0.0, 0.0),
        try ghostmap.Point.init(10.0, 0.0),
        try ghostmap.Point.init(10.0, 10.0),
        try ghostmap.Point.init(0.0, 10.0),
    };

    // Calculate area
    const area = ghostmap.polygonArea(&polygon);
    std.debug.print("Area: {d} square degrees\n", .{area});

    // Test point containment
    const test_point = try ghostmap.Point.init(5.0, 5.0);
    const inside = ghostmap.polygonContainsPoint(&polygon, test_point);
    std.debug.print("Point inside polygon: {}\n", .{inside});

    // Get bounding box
    const bbox = ghostmap.BoundingBox.fromPolygon(&polygon);
    std.debug.print("Bounds: {d} to {d} lat, {d} to {d} lng\n",
        .{bbox.min_lat, bbox.max_lat, bbox.min_lng, bbox.max_lng});
}
```

### Line Intersection

```zig
pub fn intersectionExample() !void {
    // Define two line segments
    const p1 = try ghostmap.Point.init(0.0, 0.0);
    const p2 = try ghostmap.Point.init(10.0, 10.0);
    const p3 = try ghostmap.Point.init(0.0, 10.0);
    const p4 = try ghostmap.Point.init(10.0, 0.0);

    // Find intersection
    if (ghostmap.lineSegmentIntersection(p1, p2, p3, p4)) |intersection| {
        std.debug.print("Intersection at: lat={d}, lng={d}\n", .{intersection.lat, intersection.lng});
    } else {
        std.debug.print("No intersection found\n", .{});
    }
}
```

## GeoJSON I/O

### Parsing GeoJSON

```zig
pub fn geojsonExample(allocator: std.mem.Allocator) !void {
    // Parse a GeoJSON Point
    const point_json = "{\"type\":\"Point\",\"coordinates\":[-74.006,40.7128]}";
    const point = try ghostmap.parseGeoJSONPoint(allocator, point_json);
    std.debug.print("Parsed point: lat={d}, lng={d}\n", .{point.lat, point.lng});

    // Parse a GeoJSON Polygon
    const polygon_json = "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[10,0],[10,10],[0,10],[0,0]]]}";
    const polygon = try ghostmap.parseGeoJSONPolygon(allocator, polygon_json);
    defer allocator.free(polygon);
    std.debug.print("Parsed polygon with {d} points\n", .{polygon.len});
}
```

### Serializing to GeoJSON

```zig
pub fn serializeExample(allocator: std.mem.Allocator) !void {
    const point = try ghostmap.Point.init(40.7128, -74.0060);
    const json = try ghostmap.pointToGeoJSON(point, allocator);
    defer allocator.free(json);

    std.debug.print("GeoJSON: {s}\n", .{json});
}
```

## Raster Data

### Creating and Using Rasters

```zig
pub fn rasterExample(allocator: std.mem.Allocator) !void {
    // Create a bounding box
    const bbox = ghostmap.BoundingBox{
        .min_lat = 0.0,
        .max_lat = 10.0,
        .min_lng = 0.0,
        .max_lng = 10.0,
    };

    // Create a 100x100 raster
    var raster = try ghostmap.Raster.init(allocator, 100, 100, bbox);
    defer raster.deinit(allocator);

    // Set some values
    raster.set(50, 50, 100.0);
    const value = raster.get(50, 50);
    std.debug.print("Raster value at (50,50): {d}\n", .{value});
}
```

## Multi-Part Geometries

### Working with Multi-Polygons

```zig
pub fn multiGeometryExample(allocator: std.mem.Allocator) !void {
    // Create two polygons
    const poly1 = [_]ghostmap.Point{
        try ghostmap.Point.init(0.0, 0.0),
        try ghostmap.Point.init(5.0, 0.0),
        try ghostmap.Point.init(5.0, 5.0),
        try ghostmap.Point.init(0.0, 5.0),
    };

    const poly2 = [_]ghostmap.Point{
        try ghostmap.Point.init(10.0, 10.0),
        try ghostmap.Point.init(15.0, 10.0),
        try ghostmap.Point.init(15.0, 15.0),
        try ghostmap.Point.init(10.0, 15.0),
    };

    const multi_poly = [_]ghostmap.Polygon{ &poly1, &poly2 };

    // Get combined bounding box
    const bbox = ghostmap.multiPolygonBoundingBox(&multi_poly);
    std.debug.print("Multi-polygon bounds: lat {d}-{d}, lng {d}-{d}\n",
        .{bbox.min_lat, bbox.max_lat, bbox.min_lng, bbox.max_lng});
}
```

## Error Handling

```zig
pub fn errorHandlingExample() void {
    // Invalid latitude
    const result = ghostmap.Point.init(100.0, 0.0);
    if (result) |point| {
        std.debug.print("Point created: lat={d}, lng={d}\n", .{point.lat, point.lng});
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }

    // Invalid GeoJSON
    const allocator = std.heap.page_allocator;
    const invalid_json = "{\"type\":\"Point\",\"coordinates\":[200, 0]}";
    const parse_result = ghostmap.parseGeoJSONPoint(allocator, invalid_json);
    if (parse_result) |point| {
        std.debug.print("Parsed: lat={d}, lng={d}\n", .{point.lat, point.lng});
    } else |err| {
        std.debug.print("Parse error: {}\n", .{err});
    }
}
```