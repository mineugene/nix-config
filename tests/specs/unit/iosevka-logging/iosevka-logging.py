import ast
import io
import logging
from types import SimpleNamespace

source = open("font-patcher").read()
tree = ast.parse(source)
setup = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "setup_global_logger")
output = io.StringIO()
namespace = {"logging": logging, "os": __import__("os"), "sys": SimpleNamespace(stdout=output)}
exec(compile(ast.Module(body=[setup], type_ignores=[]), "font-patcher", "exec"), namespace)
namespace["setup_global_logger"](SimpleNamespace(font="test-font", debugmode=0))
logger = namespace["logger"]
logger.debug("debug")
logger.info("info")
logger.warning("warning")
logger.error("error")
logger.critical("critical")
assert output.getvalue() == "WARNING: warning\nERROR: error\nCRITICAL: critical\n", output.getvalue()
