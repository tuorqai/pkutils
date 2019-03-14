#
# Copyright (c) 2019 Valery Timiriliyev timiriliyev@gmail.com
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

@include "pkutils.version.awk"
@include "pkutils.argparser.awk"
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"
@include "pkutils.deps.awk"

function arg_version()      { set_option("usage", 2); }
function arg_help()         { set_option("usage", 1); }
function arg_verbose()      { set_option("verbose", OPTIONS["verbose"] + 1); }
function arg_root(v)        { set_option("root", v); }
function arg_dump_db()      { set_option("dump_db", 1); }
function arg_strong()       { set_option("strong", 1); }
function arg_show_deps()    { set_option("show_deps", 1); }
function arg_show_desc()    { set_option("show_desc", 1); }
function arg_no_repeat_deps() { set_option("no_repeat", 1); }

function register_arguments() {
    register_argument("V", "--version", "arg_version",
        "Show the version and quit.");
    register_argument("?", "--help", "arg_help",
        "Show the usage page.");
    register_argument("v", "--verbose", "arg_verbose",
        "Increase the verbosity level.");
    register_argument("-", "--root", "arg_root",
        "Set other root directory.", 1);

    register_argument("0", "--dump-db", "arg_dump_db",
        "Print out all contents of the database in human-readable format and exit.");
    register_argument("s", "--strong", "arg_strong",
        "Enable strict search.");
    register_argument("p", "--show-deps", "arg_show_deps",
        "Show dependency tree.");
    register_argument("n", "--no-repeat-deps", "arg_no_repeat_deps",
        "Don't list repeating dependencies in the tree.");
    register_argument("e", "--show-desc", "arg_show_desc",
        "Show description of the package if it's available.");
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
                } else if (a[j] == "V") {
                    set_option("usage", 2);
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
            } else if (a[1] == "--version") {
                set_option("usage", 2);
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

function pkque_main(    i, p, d, queries, results, dlist, fmt, j, stash) {
    register_arguments();
    if (!parse_arguments3(queries)) {
        return 1;
    }

    if (OPTIONS["usage"] >= 2) {
        pkutils_version();
        return 0;
    }

    if (OPTIONS["usage"] >= 1) {
        usage("pkque", "Part of pkutils: Search internal package database.",
            "[OPTIONS] <PKEXPR...>");
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

        status = get_package_status(p);
        if (DB[p]["repo_id"] == "local" && status != 65536) {
            # not an orphan, so probably has been displayed or will be
            continue;
        }

        printf "%s:%s/%s %s",
            DB[p]["repo_id"],
            DB[p]["series"],
            DB[p]["name"],
            db_get_signature(DB[p]);

        if (status == -1) {
            printf " [downgrade]\n";
        } else if (status == 0) {
            printf " [installed]\n";
        } else if (status == 1) {
            printf " [upgrade]\n";
        } else if (status == 32768) {
            printf " [other tag]\n";
        } else if (status == 65536) {
            printf " [orphan]\n";
        } else {
            printf "\n";
        }

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
        add_to_dependency_list(p, dlist, !OPTIONS["no_repeat"]);
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
            } else {
                fmt = sprintf("  %%%ds`- (%%s (%%s, %%s))\n", dlist[j, "level"] * 2);
            }
            printf fmt, "",
                DB[d]["name"], DB[d]["repo_id"], db_get_signature(DB[d]);
        }

        printf "  Total dependencies: ";
        if (OPTIONS["no_repeat"]) {
            printf "%d.\n\n", stash["size"] - 1;
        } else {
            printf "%d/%d.\n\n",
                stash["size"] - 1, dlist["length"] - 1;
        }
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
