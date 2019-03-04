
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
        if (ARGV[i] ~ /^-[^-]+$/) {
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
        } else if (ARGV[i] ~ /^--?.+$/) {
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
function fetch_slackbuild(pk, repo,
                            i, n, d, c, tar, output, uri,
                            sources, checksums, failed,
                            basename, sym, m)
{
    # Sperva xvataem zapacovannhie v .tar.gz scripthi dlea sborchi
    tar = db_get_tar_name(pk);
    uri = sprintf("%s/%s/%s", repo["uri"], pk["series"], tar);
    output = sprintf("%s/repo_%s/%s", DIRS["lib"], repo["name"], tar);
    if (!get_file(output, uri)) {
        return 0;
    }

    # Potom sozdaem pusthie directorii dlea nix
    if (OPTIONS["dryrun"]) {
        printf ">> mkdir -p %s/repo_%s/%s\n", DIRS["lib"], repo["name"], pk["name"];
    } else {
        if (system(sprintf("mkdir -p %s/repo_%s/%s/\n", DIRS["lib"], repo["name"], pk["name"])) > 0) {
            return 0;
        }
    }

    # I tolhco posle etogo moghno teanuth sobstvenno isxodnichi
    printf "Downloading sources for %s...\n", db_get_full_name(pk);

    if (OPTIONS["arch"] == "x86_64" && pk["src_download_x86_64"]) {
        d = "src_download_x86_64";
        c = "src_checksum_x86_64";
    } else {
        d = "src_download";
        c = "src_checksum";
    }

    n = split(pk[d], sources, " ");
    if (n <= 0) {
        return 1;
    }
    split(pk[c], checksums, " ");

    for (i = 1; i <= n; i++) {
        match(sources[i], /\/([^\/]+)$/, m);
        basename = m[1];
        output = sprintf("%s/%s", DIRS["cache"], basename);
        sym = sprintf("%s/repo_%s/%s/%s",
            DIRS["lib"], repo["name"], pk["name"], basename);
        if (!fetch_file(output, sources[i], checksums[i]) ||
            !make_symlink(sym, output))
        {
            return 0;
        }
    }

    return 1;
}

# --------------------------------
# -- fetch_package
# --------------------------------
function fetch_package(pk,    i, r, tar, uri, output) {
    for (i = 1; i <= REPOS["length"]; i++) {
        if (REPOS[i]["name"] == pk["repo_id"]) {
            r = i;
            break;
        }
    }

    if (!r) {
        printf "Error: no repo %s\n", pk["repo_id"] > "/dev/stderr";
        return 0;
    }

    printf "Downloading package %s...\n", db_get_full_name(pk);

    if (pk["type"] == "SlackBuild") {
        TEMPORARY = REPOS[r]["name"];
        return fetch_slackbuild(pk, REPOS[r]);
    }

    tar = db_get_tar_name(pk);
    uri = sprintf("%s/%s/%s", REPOS[r]["uri"], pk["location"], tar);
    output = sprintf("%s/%s", REPOS[r]["cache"], tar);
    TEMPORARY = output;

    if (!get_file(output, uri, pk["checksum"])) {
        return 0;
    }

    return 1;
}

# --------------------------------
# -- elist_fetch
# --------------------------------
function elist_fetch(self,    i, p, output, failed) {
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        if (!fetch_package(DB[p])) {
            printf "f++\n";
            failed++;
        }
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
function build_slackbuild(sb, syscom, repo_name,    status, cmd) {
    cmd = sprintf("PK_CACHEDIR=\"%s\" PK_LIBDIR=\"%s\" %s/build.sh %s %s \"%s\"",
        DIRS["cache"], DIRS["lib"],
        DIRS["libexec"],
        sb["name"], repo_name, syscom);

    if (OPTIONS["dryrun"]) {
        system("DRYRUN=yes " cmd);
        return 1;
    }

    status = system(cmd);
    if (status == 200) {
        printf "Got interrupted by user. Stopping... :(\n";
        exit 200;
    }
    if (status >= 1) {
        printf "Failed to build %s.\n", db_get_full_name(sb);
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
    printf "pkadd 5.0m13\n";

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

    if (queries["length"] <= 0) {
        if (OPTIONS["upgrade"]) {
            upgrade_system(results);
        } else {
            printf "No query.\n";
            return 0;
        }
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

    if (OPTIONS["use_deps"]) {
        printf "Resolving dependencies...\n";
        for (i = 1; i <= results["length"]; i++) {
            add_to_dependency_list(results[i], dlist);
        }
        printf "Done!\n";

        for (i = 1; i <= dlist["length"]; i++) {
            insert_package(dlist[i], er, eu, ei);
        }
    } else {
        for (i = 1; i <= results["length"]; i++) {
            insert_package(results[i], er, eu, ei);
        }
    }

    if (er["length"] == 0 && eu["length"] == 0 && ei["length"] == 0) {
        printf "Nothing to do.\n";
        return 0;
    }

    elist_prompt(er);
    elist_prompt(eu);
    elist_prompt(ei);

    printf "\nSummary: %d reinstalled, %d upgraded, %d installed (%d total).\n",
        er["length"], eu["length"], ei["length"],
        (er["length"] + eu["length"] + ei["length"]);

    if (OPTIONS["fetch_only"]) {
        printf "Note: Packages will be downloaded only.";
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
