# GLog – Simple Logging System for Delphi

**GLog** is a lightweight logging library for Delphi applications. It provides basic yet flexible functionality to log messages to files and/or console, supporting different severity levels.

## Project Structure

- **`GLog.pas`** – Core unit implementing the logging functionality.
- **`LogTest.dpr`** – Basic example of how to use the logging system.
- **`LogTest2.dpr`** – Example demonstrating usage of different log levels (`info`, `warning`, `error`).
- **`LogTest3.dpr`** – Demonstration of file and console logging.

## Features

- Multiple log levels: INFO, WARNING, ERROR
- Log to file and/or console
- Configurable log output format
- Enable or disable logging as needed
- Simple integration into existing Delphi projects

## Quick Start

```pascal
uses GLog;

begin
  LogToConsole := True;
  LogToFile := True;
  LogFileName := 'mylog.txt';

  LogInfo('Application started.');
  LogWarning('This is a warning.');
  LogError('An error occurred.');
end.
```

## Memory Management

This project uses [FastMM5](https://github.com/pleriche/FastMM5) – a fast replacement memory manager for Delphi. It improves performance and memory debugging capabilities.

Make sure to include `FastMM5.pas` in your project if you're building from source.

## Requirements

- FastMM5 memory manager
- No other external dependencies

## License

This project is licensed under the MIT License – feel free to use, modify, and distribute it.

---

Developed with simplicity and extensibility in mind. Contributions are welcome!
