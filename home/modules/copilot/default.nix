{ pkgs, ... }:
{
    home.sessionVariables = {
        COPILOT_NODE_COMMAND = "${pkgs.nodejs}/bin/node";
    };
}
