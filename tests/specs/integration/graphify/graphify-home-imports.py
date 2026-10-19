import importlib.util

import debugpy

assert importlib.util.find_spec("graphify") is None
