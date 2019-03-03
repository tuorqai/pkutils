
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"
@include "pkutils.deps.awk"

# --------------------------------
# -- usage
# --------------------------------
function usage() {
    printf "...\n";
}

# --------------------------------
# -- parse_arguments
# --------------------------------
function parse_arguments(queries,    i, j, t, a, m) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[A-Za-z0-9]+$/) {
            t = split(ARGV[i], a, //);
            for (j = 2; j <= t; j++) {
                if (a[j] == "y") {
                    set_option("always_reply", 1001);
                } else if (a[j] == "n") {
                    set_option("always_reply", 1000);
                } else if (a[j] == "u") {
                    set_option("upgrade", 1);
                } else if (a[j] == "f") {
                    set_option("force", 1);
                } else if (a[j] == "x") {
                    set_option("dryrun", 1);
                } else if (a[j] == "d") {
                    set_option("fetch_only", 1);
                } else if (a[j] == "h" || a[j] == "?") {
                    set_option("usage", 1);
                } else {
                    printf "Unrecognized switch: -%s\n", a[j] >> "/dev/stderr";
                    return 0;
                }
            }
        } else if (ARGV[i] ~ /^--?[A-Za-z0-9=\-\.\/]+$/) {
            t = split(ARGV[i], a, /=/);
            if (a[1] == "--assume-yes") {
                set_option("always_reply", 1001);
            } else if (a[1] == "--assume-no") {
                set_option("always_reply", 1000);
            } else if (a[1] == "--upgrade") {
                set_option("upgrade", 1);
            } else if (a[1] == "--reinstall") {
                set_option("force", 1);
            } else if (a[1] == "--dry-run") {
                set_option("dryrun", 1);
            } else if (a[1] == "--download") {
                set_option("fetch_only", 1);
            } else if (a[1] == "--enable-deps") {
                set_option("use_deps", 1);
            } else if (a[1] == "--disable-deps") {
                set_option("use_deps", 0);
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

# --------------------------------
# -- elist_add_package
# --------------------------------
function elist_add_package(self, p, op,    k) {
    for (k = 1; k <= self["length"]; k++) {
        if (self[k] == p) {
            return;
        }
    }

    k = ++self["length"];
    self[k] = p;
    self[k, "tar"] = db_get_tar_name(DB[p]);
    if (op) {
        self[k, "hint"] = db_get_signature(DB[op]) " -> " db_get_signature(DB[p]);
    } else {
        self[k, "hint"] = db_get_signature(DB[p]);
    }
}

# --------------------------------
# -- elist_prompt
# --------------------------------
function elist_prompt(self,    i, p) {
    if (self["length"] == 0) {
        return;
    }

    printf "\n%d package(s) will be %s:\n", self["length"], self["action"];
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        printf "-- %s (%s)\n", DB[p]["name"], self[i, "hint"];
    }
}

# --------------------------------
# -- fetch_sources
# --------------------------------
function fetch_sources(pk, tar, repo,    i, x, total, sources, checksums, m) {
    # Sperva xvataem zapacovannhie v .tar.gz scripthi dlea sborchi
    x["path"] = sprintf("%s/%s/%s", repo["url_path"], pk["series"], tar);
    x["out"] = sprintf("%s/repo_%s/%s", DIRS["lib"], repo["name"], tar);
    pk_fetch_file(repo["url_scheme"], repo["url_host"], x["path"], x["out"]);

    # Potom sozdaem pusthie directorii dlea nich
    if (OPTIONS["dryrun"]) {
        printf ">> mkdir -p %s/repo_%s/%s\n", DIRS["lib"], repo["name"], pk["name"];
    } else {
        if (system(sprintf("mkdir -p %s/repo_%s/%s/\n", DIRS["lib"], repo["name"], pk["name"])) > 0) {
            return 1;
        }
    }

    # I tolhco posle etogo moghno teanuth sobstvenno isxodnichi
    if (OPTIONS["arch"] == "x86_64" && pk["src_download_x86_64"]) {
        x["download"] = "src_download_x86_64";
        x["checksum"] = "src_checksum_x86_64";
    } else {
        x["download"] = "src_download";
        x["checksum"] = "src_checksum";
    }

    total = split(pk[x["download"]], sources, " ");
    split(pk[x["checksum"]], checksums, " ");
    if (total <= 0) {
        return 0;
    }

    for (i = 1; i <= total; i++) {
        match(sources[i], /\/([^\/]+)$/, m);
        if (pk_fetch_remote(DIRS["cache"] "/" m[1], sources[i], checksums[i]) > 0) {
            return 1;
        }
        x["sym"] = sprintf("%s/repo_%s/%s/%s", DIRS["lib"], repo["name"], pk["name"], m[1]);
        pk_make_symlink(x["sym"], DIRS["cache"] "/" m[1]);
    }

    return 0;
}

# --------------------------------
# -- fetch_package
# --------------------------------
function fetch_package(pk, tar,    i, r, pk_url_path, pk_output) {
    for (i = 1; i <= REPOS["length"]; i++) {
        if (REPOS[i]["name"] == pk["repo_id"]) {
            r = i;
            break;
        }
    }

    if (!r) {
        printf "Error: no repo %s\n", pk["repo_id"] > "/dev/stderr";
        return 1;
    }

    if (pk["type"] == "SlackBuild") {
        TEMPORARY = REPOS[r]["name"];
        return fetch_sources(pk, tar, REPOS[r]);
    }

    pk_url_path = sprintf("%s/%s/%s", REPOS[r]["url_path"], pk["location"], tar);
    pk_output = sprintf("%s/%s", REPOS[r]["cache"], tar);
    TEMPORARY = pk_output;

    return pk_fetch_file(REPOS[r]["url_scheme"], REPOS[r]["url_host"],
        pk_url_path, pk_output, pk["checksum"]);
}

# --------------------------------
# -- elist_fetch
# --------------------------------
function elist_fetch(self,    i, p, output, failed) {
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        failed += fetch_package(DB[p], self[i, "tar"]);
        if (DB[p]["type"] == "SlackBuild") {
            self[i, "repo"] = TEMPORARY;
        } else {
            self[i, "cache"] = TEMPORARY;
        }
    }
    return failed;
}

# --------------------------------
# -- build_slackbuild
# --------------------------------
function build_slackbuild(sb, syscom, repo_name,    dir, cmd) {
    dir = sprintf("%s/repo_%s/%s", DIRS["lib"], repo_name, sb["name"]);
    cmd["untar"] = sprintf("cd %s/repo_%s && tar xf %s.tar.gz",
        DIRS["lib"], repo_name, sb["name"]);
    cmd["exports"] = sprintf("export OUTPUT=%s/%s", DIRS["cache"], repo_name);
    cmd["build"] = sprintf("cd %s && %s && sh %s.SlackBuild",
        dir, cmd["exports"], sb["name"]);
    cmd["install"] = sprintf("%s %s/%s/%s-%s-*.t?z",
        syscom, DIRS["cache"], repo_name, sb["name"], sb["version"]);

    if (OPTIONS["dryrun"]) {
        printf ">> %s\n", cmd["untar"];
        printf ">> %s\n", cmd["build"];
        printf ">> %s\n", cmd["install"];
        return 1;
    }

    if (system(cmd["untar"]) > 0) {
        return 0;
    }
    if (system(cmd["build"]) > 0) {
        return 0;
    }
    if (system(cmd["install"]) > 0) {
        return 0;
    }
    return 1;
}

# --------------------------------
# -- elist_process
# --------------------------------
function elist_process(self,    i, p) {
    if (self["length"] == 0) {
        return;
    }

    if (OPTIONS["root"]) {
        self["command"] = sprintf("%s --root %s", self["command"], OPTIONS["root"]);
    }

    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        if (DB[p]["type"] == "SlackBuild") {
            build_slackbuild(DB[p], self["command"], self[i, "repo"]);
            continue;
        }

        if (OPTIONS["dryrun"]) {
            printf ">> %s %s\n", self["command"], self[i, "cache"];
            continue;
        }

        system(self["command"] " " self[i, "cache"]);
    }
}

# --------------------------------
# -- insert_package
# --------------------------------
function insert_package(p, er, eu, ei,    status) {
    status = db_is_installed(p);

    if (status >= 65536) {
        elist_add_package(eu, p, status - 65535);
    } else if (status >= 32768) {
        printf "Package %s is locked by expression %s.\n",
            DB[p]["name"], LOCK[status - 32767];
    } else if (status == 1) {
        if (OPTIONS["force"]) {
            elist_add_package(er, p);
        } else {
            printf "Package %s (%s) is installed already.\n",
                DB[p]["name"], db_get_signature(DB[p]);
        }
    } else {
        if (!OPTIONS["upgrade"]) {
            elist_add_package(ei, p);
        }
    }
}

# --------------------------------
# -- upgrade_system
# --------------------------------
function upgrade_system(results,    i, status) {
    for (i = DB["first_local"]; i <= DB["length"]; i++) {
        status = db_is_upgradable(i);
        if (status < 65536) {
            continue;
        }
        results[++results["length"]] = status - 65535;
    }
}

# --------------------------------
# -- pkadd_main
# --------------------------------
function pkadd_main(    i, p, queries, results, er, eu, ei) {
    if (!parse_arguments(queries)) {
        return 255;
    }

    if (OPTIONS["usage"]) {
        usage();
        return 0;
    }

    pk_setup_dirs(OPTIONS["root"]);
    if (!pk_check_dirs()) {
        printf "Run `pkupd' first!\n";
        return 255;
    }
    pk_parse_options();

    printf "Reading packages index...";
    db_rebuild();
    printf " Done.\n";

    pk_parse_repos_list();
    parse_lock_list();

    if (OPTIONS["upgrade"] && queries["length"] <= 0) {
        upgrade_system(results);
    } else {
        db_query(results, queries);
        if (results["length"] <= 0) {
            printf "No packages found.\n";
            return 0;
        }
    }

    er["action"] = "REINSTALLED";
    er["command"] = "upgradepkg --reinstall";
    eu["action"] = "UPGRADED";
    eu["command"] = "upgradepkg";
    ei["action"] = "INSTALLED";
    ei["command"] = "installpkg";

    for (i = 1; i <= results["length"]; i++) {
        p = results[i];
        if (!DB[p]["required"] || !OPTIONS["use_deps"]) {
            insert_package(p, er, eu, ei);
            continue;
        }

        printf "Calculating dependencies for %s...\n", db_get_full_name(DB[p]);
        delete dlist;
        make_dependency_list(p, dlist);
        printf "Done!\n";

        for (j = 1; j <= dlist["length"]; j++) {
            insert_package(dlist[j], er, eu, ei);
        }
    }

    if (er["length"] == 0 && eu["length"] == 0 && ei["length"] == 0) {
        printf "Nothing to do.\n";
        return 0;
    }

    elist_prompt(er);
    elist_prompt(eu);
    elist_prompt(ei);

    if (OPTIONS["fetch_only"]) {
        printf "\nNote: Packages will be downloaded only.";
    }

    if (pk_answer("\nContinue?", "y") == 0) {
        printf "Exiting...\n";
        return 255;
    }

    failed += elist_fetch(er);
    failed += elist_fetch(eu);
    failed += elist_fetch(ei);

    if (failed > 0) {
        printf "Exiting...\n";
        return 255;
    }

    if (OPTIONS["fetch_only"]) {
        return 0;
    }

    elist_process(er);
    elist_process(eu);
    elist_process(ei);

    return 0;
}

# --------------------------------
# -- 
# --------------------------------
BEGIN {
    rc = pkadd_main();
    exit rc;
}
