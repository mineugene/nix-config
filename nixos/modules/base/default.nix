{
    nix.settings = {
        # Experimental features
        experimental-features = [
            "nix-command"
            "flakes"
        ];

        # Performance and caching
        auto-optimise-store = true;
        max-jobs = "auto";
        substituters = [
            "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
    };
}
