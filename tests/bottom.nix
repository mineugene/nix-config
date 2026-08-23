{
    bottom,
    bottomAlias,
    bottomConfig,
    pkgs,
}:
assert bottomAlias == "btm";
assert bottom.enable;
assert
    bottom.settings.flags == {
        basic = true;
        default_widget_type = "proc";
        no_write = true;
        rate = "1s";
    };
assert
    bottom.settings.processes == {
        columns = [
            "pid"
            "name"
            "cpu%"
            "mem%"
            "user"
            "state"
            "time"
        ];
        default_sort = "cpu%";
        sort_order = "Descending";
        default_tree = true;
        tree_collapse = true;
        process_command = false;
        hide_k_threads = true;
    };
assert bottom.settings.styles.cpu.cpu_core_colours == [ "#7aa2f7" ];
assert bottom.settings.styles.widgets.bg_colour == "#1a1b26";
assert bottom.settings.styles.widgets.text == "#c0caf5";
assert !(bottom.settings ? row);
pkgs.runCommandLocal "bottom-check" { } ''
    grep -F 'basic = true' ${bottomConfig}
    grep -F 'default_widget_type = "proc"' ${bottomConfig}
    grep -F 'rate = "1s"' ${bottomConfig}
    grep -F 'columns = [' ${bottomConfig}
    grep -F 'default_tree = true' ${bottomConfig}
    grep -F 'tree_collapse = true' ${bottomConfig}
    grep -F 'bg_colour = "#1a1b26"' ${bottomConfig}
    touch "$out"
''
