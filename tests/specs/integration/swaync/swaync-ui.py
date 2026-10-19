import sys
import xml.etree.ElementTree as ElementTree

root = ElementTree.parse(sys.argv[1]).getroot()
label = next(
    (element for element in root.iter("object") if element.get("id") == "app_name"),
    None,
)
assert label is not None and label.get("class") == "GtkLabel", "app_name label missing"
classes = {element.get("name") for element in label.iter("class")}
assert "app-name" in classes, "app_name label lacks app-name style class"
