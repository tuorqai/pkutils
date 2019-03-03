
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"
@include "pkutils.deps.awk"

function usage() {
    printf "...\n";
}

function parse_arguments(queries,    i, j, m, a, t) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^-]+$/) {
            t = split(ARGV[i], a, //);
            for (j = 2; j <= t; j++) {
                if (a[j] == "a") {
                    set_option("show_all", 1);
                } else if (a[j] == "d") {
                    set_option("show_deps", 1);
                } else if (a[j] == "x") {
                    set_option("no_repeat", 1);
                } else if (a[j] == "e") {
                    set_option("show_desc", 1);
                } else if (a[j] == "0") {
                    set_option("dump_db", 1);
                } else if (a[j] == "s") {
                    set_option("strong", 1);
                } else if (a[j] == "h" || a[j] == "?") {
                    set_option("usage", 1);
                } else {
                    printf "Unrecognized switch: -%s\n", a[j] >> "/dev/stderr";
                    return 0;
                }
            }
        } else if (ARGV[i] ~ /^--?.+$/) {
            t = split(ARGV[i], a, /=/);
            if (a[1] == "--include-locals") {
                set_option("show_all", 1);
            } else if (a[1] == "--dependencies") {
                set_option("show_deps", 1);
            } else if (a[1] == "--no-repeat") {
                set_option("no_repeat", 1);
            } else if (a[1] == "--description") {
                set_option("show_desc", 1);
            } else if (a[1] == "--dump-db") {
                set_option("dump_db", 1);
            } else if (a[1] == "--strong") {
                set_option("strong", 1);
            } else if (a[1] == "--help") {
                set_option("usage", 1);
            } else if ((a[1] == "-R" || a[1] == "--root") && t == 2) {
                set_option("root", a[2]);
            } else {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            }
        } else {
            queries[++queries["length"]] = ARGV[i];
        }
    }

    return 1;
}

function pkque_print_package(pk) {
    printf "\n%s:%s/%s %s\n  %s\n",
        pk["repo_id"], pk["series"], pk["name"],
        pk_get_full_version(pk),
        pk["description"];
}

function pkque_main(    i, p, d, queries, results, dlist, fmt, j, stash) {
    if (!parse_arguments(queries)) {
        return 1;
    }

    if (OPTIONS["usage"]) {
        usage();
        return 0;
    }

    pk_setup_dirs(OPTIONS["root"]);
    if (!pk_check_dirs()) {
        printf "Run `pkupd' first.\n";
        return 255;
    }
    pk_parse_options();

    printf "Reading packages index...";
    db_rebuild();
    printf " Done.\n";

    if (OPTIONS["dump_db"]) {
        db_dump();
        return 0;
    }

    db_weak_query(results, queries);
    if (results["length"] <= 0) {
        printf "No packages found.\n";
        return 0;
    }

    printf "\n";

    for (i = 1; i <= results["length"]; i++) {
        p = results[i];

        if (!OPTIONS["show_all"] && DB[p]["repo_id"] == "local") {
            continue;
        }

        printf "%s:%s/%s %s\n",
            DB[p]["repo_id"],
            DB[p]["series"],
            DB[p]["name"],
            db_get_signature(DB[p]);

        if (OPTIONS["show_desc"]) {
            if (!DB[p]["description"]) {
                printf "  (no description available)\n";
            } else {
                printf "  %s\n", DB[p]["description"];
            }
        }

        if (!OPTIONS["show_deps"]) {
            printf "\n";
            continue;
        }

        delete dlist;
        make_dependency_list(p, dlist);
        if (dlist["length"] <= 1) {
            printf "No dependencies or information is not available.\n\n";
            continue;
        }

        for (j = dlist["length"]; j >= 1; j--) {
            d = dlist[j];
            if (!(d in stash)) {
                stash[d] = 65535;
                stash["size"]++;
                fmt = sprintf("  %%%ds`- %%s (%%s, %%s)\n", dlist[j, "level"] * 2);
            } else if (OPTIONS["no_repeat"]) {
                continue;
            } else {
                fmt = sprintf("  %%%ds`- (%%s (%%s, %%s))\n", dlist[j, "level"] * 2);
            }
            printf fmt, "",
                DB[d]["name"], DB[d]["repo_id"], db_get_signature(DB[d]);
        }

        printf "  Total dependencies: %d/%d.\n\n",
            stash["size"] - 1, dlist["length"] - 1;
        delete stash;
    }

    if (results["length"] > 5) {
        printf "Total packages found: %d.\n", results["length"];
    }

    if (!OPTIONS["show_desc"] && !OPTIONS["show_deps"]) {
        printf "\n";
    }
    return 0;
}

BEGIN {
    rc = pkque_main();
    exit rc;
}
