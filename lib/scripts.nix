{ pkgs }:
{ name, src }:
pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";
    text = builtins.readFile src;
}
