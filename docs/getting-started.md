# Getting Started with GhostMap

GhostMap is a high-performance Geographic Information System (GIS) library written in Zig, providing comprehensive spatial data processing capabilities.

## Installation

### Using Zig Fetch

Add GhostMap to your `build.zig.zon`:

```bash
zig fetch --save https://github.com/ghostkellz/ghostmap/archive/refs/heads/main.tar.gz
```

This will add the dependency to your `build.zig.zon` file.

### Manual Addition

Alternatively, add it manually to your `build.zig.zon`:

```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .ghostmap = .{
            .url = "https://github.com/ghostkellz/ghostmap/archive/refs/heads/main.tar.gz",
            .hash = "TODO: add hash here", // Run zig build and update with the actual hash
        },
    },
}
```

Then in your `build.zig`:

```zig
const ghostmap = b.dependency("ghostmap", .{});
exe.root_module.addImport("ghostmap", ghostmap.module("ghostmap"));
```

## Quick Start

```zig
const std = @import("std");
const ghostmap = @import("ghostmap");

pub fn main() !void {
    // Create a geographic point
    const point = try ghostmap.Point.init(40.7128, -74.0060); // New York City
    
    // Project to Web Mercator
    const mercator = ghostmap.projectToWebMercator(point);
    
    // Calculate distance to another point
    const rome = try ghostmap.Point.init(41.8919300, 12.5113300);
    const distance = point.distance(rome);
    
    std.debug.print("Distance: {d} km\n", .{distance});
}
```

## Project Structure

GhostMap provides several key components:

- **Geometry Types**: Point, Line, Polygon, and multi-part variants
- **Spatial Operations**: Distance, area, intersection, containment
- **Projections**: Web Mercator coordinate transformations
- **Data I/O**: GeoJSON parsing and serialization
- **Raster Support**: Basic raster data structures

## Next Steps

- Check out the [API Reference](api-reference.md) for detailed function documentation
- See [Examples](examples.md) for more usage patterns
- Read the [Contributing Guide](../CONTRIBUTING.md) if you'd like to contribute