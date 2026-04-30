from fastmcp import FastMCP
import logging
import math
import random
import sys

logger = logging.getLogger("Calculator")

if sys.platform == "win32":
    sys.stderr.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")

mcp = FastMCP("Calculator")


@mcp.tool()
def calculator(python_expression: str) -> dict:
    """Calculate a Python math expression. You can use math or random directly."""
    result = eval(python_expression, {"math": math, "random": random})
    logger.info("Calculating formula: %s, result: %s", python_expression, result)
    return {"success": True, "result": result}


if __name__ == "__main__":
    mcp.run(transport="stdio")
