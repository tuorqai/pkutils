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

function arg_assume_no()    { set_option("always_reply", 1000); }
function arg_assume_yes()   { set_option("always_reply", 1001); }
function arg_upgrade()      { set_option("upgrade", 1); }
function arg_reinstall()    { set_option("force", 1); }
function arg_dry_run()      { set_option("dryrun", 1); }
function arg_download()     { set_option("fetch", 1); }
function arg_verbose()      { set_option("verbose", OPTIONS["verbose"] + 1); }
function arg_version()      { set_option("usage", 2); }
function arg_help()         { set_option("usage", 1); }
function arg_root(v)        { set_option("root", v); }

# --------------------------------
# -- register_arguments
# --------------------------------
function register_arguments() {
    register_argument("V", "--version", "arg_version",
        "Show the version and quit.");
    register_argument("?", "--help", "arg_help",
        "Show the usage page.");
    register_argument("v", "--verbose", "arg_verbose",
        "Increase the verbosity level.");
    register_argument("-", "--root", "arg_root",
        "Set other root directory.", 1);
    
    register_argument("u", "--upgrade", "arg_upgrade",
        "Set pkadd to the upgrade mode. Without any pkexprs given, it will upgrade all available packages.");
    register_argument("f", "--reinstall", "arg_reinstall",
        "Force reinstallation of packages.");
    register_argument("d", "--download", "arg_download",
        "Do not install packages, but download them.");
    register_argument("x", "--dry-run", "arg_dry_run",
        "Do not actually install nor download packages. No changes will be done on the system.");

    register_argument("y", "--assume-yes", "arg_assume_yes",
        "Assume that user replies Y to all prompts.");
    register_argument("n", "--assume-no", "arg_assume_no",
        "Assume that user replies N to all prompts.");
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
    register_arguments();
    if (!parse_arguments3(queries)) {
        return 255;
    }

    if (OPTIONS["usage"] >= 2) {
        pkutils_version();
        return 0;
    }

    if (OPTIONS["usage"] >= 1) {
        usage("pkadd", "Install or upgrade packages. Part of pkutils.",
            "[OPTIONS] <PKEXPR...>");
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
