def packageSource:
    if type == "string" then .
    elif type == "object" then .source
    else null
    end;

$defaults + .
| .packages = (
    (.packages // [])
    | if type != "array" then [$package]
      elif any(.[]; packageSource == $package) then .
      else . + [$package]
      end
)
