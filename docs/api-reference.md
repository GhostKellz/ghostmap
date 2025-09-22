# API Reference

This document provides detailed API documentation for GhostMap.

## Core Types

### Point

```zig
pub const Point = struct {
    lat: f64,
    lng: f64,

    pub fn init(lat: f64, lng: f64) !Point
    pub fn distance(self: Point, other: Point) f64
};
```

Represents a geographic coordinate with latitude and longitude.

- `lat`: Latitude in degrees (-90 to 90)
- `lng`: Longitude in degrees (-180 to 180)

**Methods:**
- `init(lat, lng)`: Creates a new point with validation
- `distance(other)`: Calculates Haversine distance in kilometers

### Line

```zig
pub const Line = []const Point;
```

A sequence of connected points representing a line string.

### Polygon

```zig
pub const Polygon = []const Point;
```

A closed shape defined by points. Points should be ordered counterclockwise for exterior rings.

### BoundingBox

```zig
pub const BoundingBox = struct {
    min_lat: f64,
    max_lat: f64,
    min_lng: f64,
    max_lng: f64,

    pub fn fromPolygon(polygon: Polygon) BoundingBox
    pub fn contains(self: BoundingBox, point: Point) bool
};
```

Represents a rectangular geographic bounds.

### WebMercatorPoint

```zig
pub const WebMercatorPoint = struct {
    x: f64,
    y: f64,
};
```

A point in Web Mercator projection coordinates (meters from origin).

### Multi-Part Geometries

```zig
pub const MultiPoint = []const Point;
pub const MultiLineString = []const Line;
pub const MultiPolygon = []const Polygon;

pub const Geometry = union(enum) {
    point: Point,
    line: Line,
    polygon: Polygon,
    multi_point: MultiPoint,
    multi_line: MultiLineString,
    multi_polygon: MultiPolygon,
};
```

Multi-part geometry types for complex shapes.

### Raster

```zig
pub const Raster = struct {
    width: usize,
    height: usize,
    data: []f64,
    bounds: BoundingBox,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, bounds: BoundingBox) !Raster
    pub fn deinit(self: *Raster, allocator: std.mem.Allocator) void
    pub fn get(self: Raster, x: usize, y: usize) f64
    pub fn set(self: *Raster, x: usize, y: usize, value: f64) void
};
```

Basic raster data structure for elevation and imagery data.

## Functions

### Spatial Operations

#### polygonArea
```zig
pub fn polygonArea(polygon: Polygon) f64
```
Calculates the area of a polygon using the shoelace formula. Returns area in square degrees.

#### polygonContainsPoint
```zig
pub fn polygonContainsPoint(polygon: Polygon, point: Point) bool
```
Tests if a polygon contains a point using the ray casting algorithm.

#### lineSegmentIntersection
```zig
pub fn lineSegmentIntersection(p1: Point, p2: Point, p3: Point, p4: Point) ?Point
```
Finds the intersection point of two line segments. Returns null if no intersection.

#### multiPolygonBoundingBox
```zig
pub fn multiPolygonBoundingBox(multi_polygon: MultiPolygon) BoundingBox
```
Calculates the bounding box for a multi-polygon.

### Projections

#### projectToWebMercator
```zig
pub fn projectToWebMercator(point: Point) WebMercatorPoint
```
Projects a WGS84 point to Web Mercator coordinates.

### I/O Functions

#### GeoJSON Parsing
```zig
pub fn parseGeoJSONPoint(allocator: std.mem.Allocator, json_str: []const u8) !Point
pub fn parseGeoJSONLineString(allocator: std.mem.Allocator, json_str: []const u8) ![]Point
pub fn parseGeoJSONPolygon(allocator: std.mem.Allocator, json_str: []const u8) ![]Point
```

Parse GeoJSON geometry strings into GhostMap types.

#### GeoJSON Serialization
```zig
pub fn pointToGeoJSON(point: Point, allocator: std.mem.Allocator) ![]u8
```

Serialize a Point to GeoJSON string.

## Error Types

- `error.InvalidLatitude`: Latitude out of range (-90 to 90)
- `error.InvalidLongitude`: Longitude out of range (-180 to 180)
- `error.InvalidGeoJSON`: Malformed GeoJSON input

## Memory Management

All functions that allocate memory take an `std.mem.Allocator` parameter. Remember to free allocated memory:

```zig
const line = try parseGeoJSONLineString(allocator, json);
defer allocator.free(line);
```