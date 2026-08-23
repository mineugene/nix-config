{
    programs.zsh.shellAliases.top = "btm";

    programs.bottom = {
        enable = true;
        settings = {
            flags = {
                basic = true;
                default_widget_type = "proc";
                no_write = true;
                rate = "1s";
            };
            processes = {
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
            styles = {
                cpu = {
                    all_entry_colour = "#7aa2f7";
                    avg_entry_colour = "#7aa2f7";
                    cpu_core_colours = [ "#7aa2f7" ];
                };
                memory = {
                    ram_colour = "#7aa2f7";
                    cache_colour = "#7dcfff";
                    swap_colour = "#bb9af7";
                };
                tables.headers = {
                    colour = "#7dcfff";
                    bold = true;
                };
                widgets = {
                    border_colour = "#3b4261";
                    selected_border_colour = "#7aa2f7";
                    widget_title = {
                        colour = "#7aa2f7";
                        bold = true;
                    };
                    bg_colour = "#1a1b26";
                    text = "#c0caf5";
                    selected_text = {
                        colour = "#1a1b26";
                        bg_colour = "#7aa2f7";
                        bold = true;
                    };
                    disabled_text = "#565f89";
                    thread_text = "#9ece6a";
                };
            };
        };
    };
}
