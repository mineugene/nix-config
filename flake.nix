{
    description = "Shareable Home Manager tooling and NixOS modules.";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        pi-dev-config = {
            url = "github:mineugene/pi-dev-config";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        pre-commit-hooks = {
            url = "github:cachix/git-hooks.nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        rust-overlay = {
            url = "github:oxalica/rust-overlay";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        openxlr = {
            url = "github:emaspa/openxlr";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        zsh-git-ignore = {
            url = "github:laggardkernel/git-ignore/8b085a3848a5efcf4db1c4dea769b5ae387f5a0a";
            flake = false;
        };
        zsh-git-escape-magic = {
            url = "github:knu/zsh-git-escape-magic/62af4f6a66601a517e168039614e5b528741a844";
            flake = false;
        };
    };

    outputs = inputs: import ./outputs inputs;
}
