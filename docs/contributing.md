# Contributing to GhostMap

Thank you for your interest in contributing to GhostMap! This document provides guidelines for contributing to the project.

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/ghostkellz/ghostmap.git
cd ghostmap
```

2. Build the project:
```bash
zig build
```

3. Run tests:
```bash
zig build test
```

4. Run the example:
```bash
zig build run
```

## Code Style

GhostMap follows Zig's official coding standards:

- Use 4 spaces for indentation
- Use `camelCase` for variable and function names
- Use `PascalCase` for type names
- Use `SCREAMING_SNAKE_CASE` for constants
- Keep lines under 100 characters when possible
- Use meaningful variable names
- Add documentation comments for public APIs

## Testing

- All new features must include comprehensive tests
- Tests should cover both success and error cases
- Use `zig test` to run the test suite
- Aim for high test coverage

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `zig build test`
6. Update documentation if needed
7. Commit your changes: `git commit -am 'Add some feature'`
8. Push to the branch: `git push origin feature/your-feature-name`
9. Submit a pull request

## Adding New Features

When adding new GIS functionality:

1. **Check existing code**: See if similar functionality already exists
2. **Follow the API patterns**: Use similar naming and error handling
3. **Add comprehensive tests**: Cover edge cases and error conditions
4. **Update documentation**: Add to API reference and examples
5. **Consider performance**: GIS operations should be efficient

## Reporting Issues

When reporting bugs:

- Use the issue template
- Include Zig version: `zig version`
- Provide a minimal reproduction case
- Include expected vs actual behavior
- Add any relevant error messages

## Documentation

- Keep the README up to date
- Add examples for new features
- Update API documentation
- Use clear, concise language

## License

By contributing to GhostMap, you agree that your contributions will be licensed under the MIT License.