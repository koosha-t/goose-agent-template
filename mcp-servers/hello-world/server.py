"""
Hello World MCP Server
======================
A sample MCP server demonstrating tool patterns for the goose-agent-template.

Tools:
  - greet(name)        : read-only, returns a greeting
  - add_numbers(a, b)  : read-only, returns the sum
  - log_message(msg, level) : write, "logs" a message

Run locally:
  pip install -r requirements.txt
  python server.py
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP(
    "hello-world",
    instructions=(
        "Sample tools for the goose-agent-template.\n\n"
        "Available tools:\n"
        "- greet: Say hello to someone\n"
        "- add_numbers: Add two numbers together\n"
        "- log_message: Log a message at a given level\n\n"
        "Use greet and add_numbers freely (read-only). "
        "Use log_message when you need to record something (write operation)."
    ),
    stateless_http=True,
    json_response=True,
)


@mcp.tool()
def greet(name: str = "World") -> str:
    """Greet someone by name. This is a read-only operation."""
    return f"Hello, {name}!"


@mcp.tool()
def add_numbers(a: float, b: float) -> float:
    """Add two numbers and return the result. This is a read-only operation."""
    return a + b


@mcp.tool()
def log_message(message: str, level: str = "info") -> str:
    """Log a message at the specified level. This is a write operation.

    Args:
        message: The message to log
        level: Log level - one of: debug, info, warn, error
    """
    valid_levels = ("debug", "info", "warn", "error")
    if level not in valid_levels:
        return f"Error: level must be one of {valid_levels}, got '{level}'"
    # In a real server, this would write to a logging backend
    print(f"[{level.upper()}] {message}")
    return f"Logged at {level}: {message}"


if __name__ == "__main__":
    mcp.run(transport="streamable-http", host="0.0.0.0", port=8080)
