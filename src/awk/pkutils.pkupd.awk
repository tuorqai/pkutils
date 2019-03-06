
@include "pkutils.version.awk"
@include "pkutils.argparser.awk"
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function arg_version()      { set_option("usage", 2); }
function arg_help()         { set_option("usage", 1); }
function arg_verbose()      { set_option("verbose", OPTIONS["verbose"] + 1); }
function arg_root(v)        { set_option("root", v); }

function register_arguments() {
    register_argument("V", "--version", "arg_version",
        "Show the version and quit.");
    register_argument("?", "--help", "arg_help",
        "Show the usage page.");
    register_argument("v", "--verbose", "arg_verbose",
        "Increase the verbosity level.");
    register_argument("-", "--root", "arg_root",
        "Set other root directory.", 1);
}

function pkupd_read_checksums(repo,    file, entry) {
    RS = "\n"; FS = " ";
    file = sprintf("%s/repo_%s/CHECKSUMS.md5", DIRS["lib"], repo["name"]);

    while ((getline < file) > 0) {
        if (NF == 2 && length($1) == 32) {
            repo["checksums"][$2] = $1;
        }
    }
    close(file);
}

function pkupd_sync_repo(repo,    index_txt, failed) {
    # quite dirty, but gotta somehow handle the official repo's layout
    if (repo["name"] ~ /^(slackware(64)?|extra|pasture|patches|testing)$/) {
        repo["uri"] = repo["uri"] "/" repo["name"];
    }

    printf "Synchronizing %s %s...\n",
        repo["type"] == "pk" ? "repository" : "SlackBuild repository",
        repo["name"];

    if (repo["type"] == "pk") {
        index_txt = "PACKAGES.TXT";
    } else if (repo["type"] == "sb") {
        index_txt = "SLACKBUILDS.TXT";
    } else {
        printf "-- Internal error: bad repo type %s!\n", repo["type"] > "/dev/stderr";
        return 0;
    }

    uri = sprintf("%s/CHECKSUMS.md5", repo["uri"]);
    output = sprintf("%s/repo_%s/CHECKSUMS.md5", DIRS["lib"], repo["name"]);
    if (!get_file(output, uri)) {
        failed++;
    }

    uri = sprintf("%s/CHECKSUMS.md5.asc", repo["uri"]);
    output = sprintf("%s/repo_%s/CHECKSUMS.md5.asc", DIRS["lib"], repo["name"]);
    if (!get_file(output, uri)) {
        failed++;
    }

    pkupd_read_checksums(repo);

    uri = sprintf("%s/%s", repo["uri"], index_txt);
    output = sprintf("%s/repo_%s/%s", DIRS["lib"], repo["name"], index_txt);
    if (!get_file(output, uri, repo["checksums"]["./" index_txt])) {
        failed++;
    }

    if (failed > 0) {
        printf "-- Failed to retrieve %d files.\n", failed > "/dev/stderr";
        return 0;
    }

    return 1;
}

function sync_repos(    i) {
    for (i = REPOS["length"]; i >= 1; i--) {
        if (!pkupd_sync_repo(REPOS[i])) {
            printf "Error: failed to synchronize \"%s\" repo!\n", REPOS[i]["name"] > "/dev/stderr";
            REPOS[i]["failed"] = 1;
        }
    }
    printf "Done.\n";
}

function index_binary_package(repo, pk,   i, m, path) {
    for (i = 1; i < NF; i++) {
        if ($i ~ /^PACKAGE NAME:\s+.*/) {
            sub(/PACKAGE NAME:\s+/, "", $i);
            match($i, /(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)\.(t[bglx]z)/, m);
            pk["name"]     = m[1];
            pk["version"]  = m[2];
            pk["arch"]     = m[3];
            pk["build"]    = m[4];
            pk["tag"]      = m[5];
            pk["type"]     = m[6];
        } else if ($i ~ /^PACKAGE LOCATION:\s+.*/) {
            sub(/PACKAGE LOCATION:\s+(\.\/)?/, "", $i);
            match($i, /([^\/]*$)/, m);
            pk["location"] = $i;
            pk["series"]   = m[1];
        } else if ($i ~ /^PACKAGE REQUIRED:\s+.*/) {
            sub(/PACKAGE REQUIRED:\s+/, "", $i);
            pk["required"] = $i;
        } else if ($i ~ /^PACKAGE CONFLICTS:\s+.*/) {
            sub(/PACKAGE CONFLICTS:\s+/, "", $i);
            pk["conflicts"] = $i;
        } else if ($i ~ /^PACKAGE SUGGESTS:\s+.*/) {
            sub(/PACKAGE SUGGESTS:\s+/, "", $i);
            pk["suggests"] = $i;
        } else if ($i ~ "^" pk["name"] ": " pk["name"] " \\(.+\\)$") {
            match($i, "^" pk["name"] ": " pk["name"] " \\((.+)\\)$", m);
            pk["description"] = m[1];
        }
    }

    if (repo["name"] ~ /^(slackware(64)?|extra|pasture|patches|testing)$/) {
        path = sprintf("./%s/%s", pk["series"], db_get_tar_name(pk));
    } else {
        path = sprintf("./%s/%s", pk["location"], db_get_tar_name(pk));
    }
    pk["checksum"] = repo["checksums"][path];
    pk["repo_id"] = repo["name"];
}

function index_slackbuild(repo, pk,    i, m) {
    for (i = 1; i < NF; i++) {
        if ($i ~ /^SLACKBUILD NAME:\s+/) {
            sub(/SLACKBUILD NAME:\s+/, "", $i);
            pk["name"] = $i;
        } else if ($i ~ /^SLACKBUILD LOCATION:\s+/) {
            sub(/SLACKBUILD LOCATION:\s+/, "", $i);
            pk["location"] = $i;
        } else if ($i ~ /^SLACKBUILD VERSION:\s+/) {
            sub(/SLACKBUILD VERSION:\s+/, "", $i);
            pk["version"] = $i;
        } else if ($i ~ /^SLACKBUILD DOWNLOAD:\s+/) {
            sub(/SLACKBUILD DOWNLOAD:\s+/, "", $i);
            pk["src_download"] = $i;
        } else if ($i ~ /^SLACKBUILD DOWNLOAD_x86_64:\s+/) {
            sub(/SLACKBUILD DOWNLOAD_x86_64:\s+/, "", $i);
            pk["src_download_x86_64"] = $i;
        } else if ($i ~ /^SLACKBUILD MD5SUM:\s+/) {
            sub(/SLACKBUILD MD5SUM:\s+/, "", $i);
            pk["src_checksum"] = $i;
        } else if ($i ~ /^SLACKBUILD MD5SUM_x86_64:\s+/) {
            sub(/SLACKBUILD MD5SUM_x86_64:\s+/, "", $i);
            pk["src_checksum_x86_64"] = $i;
        } else if ($i ~ /^SLACKBUILD REQUIRES:\s+/) {
            sub(/SLACKBUILD REQUIRES:\s+/, "", $i);
            gsub(/\s+/, ",", $i);
            pk["required"] = $i;
        } else if ($i ~ /^SLACKBUILD SHORT DESCRIPTION:\s+/) {
            sub(/SLACKBUILD SHORT DESCRIPTION:\s+/, "", $i);
            pk["description"] = $i;
        }
    }

    pk["repo_id"] = repo["name"];
    match(pk["location"], /.*\/([^\/]*)\/[^\/]*/, m);
    pk["series"] = m[1];
    pk["type"] = "SlackBuild";
}

function index_repo(repo, packages,    file, m) {
    FS = "\n"; RS = "";
    if (repo["type"] == "pk") {
        file = sprintf("%s/repo_%s/PACKAGES.TXT", DIRS["lib"], repo["name"]);
    } else {
        file = sprintf("%s/repo_%s/SLACKBUILDS.TXT", DIRS["lib"], repo["name"]);
    }

    printf "Indexing %s...\n", repo["name"];

    while ((getline < file) > 0) {
        if ($0 ~ /^PACKAGE\s+/) {
            k = ++DB["length"];
            DB[k][0] = 0; # specialhnhy hack po pricine otsutstvia privedenia typof
            index_binary_package(repo, DB[k]);
            delete DB[k][0];
        } else if ($0 ~ /^SLACKBUILD\s+/) {
            k = ++DB["length"];
            DB[k][0] = 0;
            index_slackbuild(repo, DB[k]);
            delete DB[k][0];
        } else {
            continue;
        }
    }
    close(file);
}

function db_build(    i) {
    for (i = REPOS["length"]; i >= 1; i--) {
        if (REPOS[i]["failed"]) {
            continue;
        }
        index_repo(REPOS[i], packages);
    }
}

function write_index_dat(    i, index_dat) {
    index_dat = DIRS["lib"] "/index.dat";
    printf "" > index_dat;

    OFS = "\n"; ORS = "\n--------------------------------\n";

    for (i = 1; i <= DB["length"]; i++) {
        print   DB[i]["repo_id"],     \
                DB[i]["location"],    \
                DB[i]["series"],      \
                DB[i]["name"],        \
                DB[i]["version"],     \
                DB[i]["arch"],        \
                DB[i]["build"],       \
                DB[i]["tag"],         \
                DB[i]["type"],        \
                DB[i]["checksum"],    \
                DB[i]["description"], \
                DB[i]["required"],    \
                DB[i]["conflicts"],   \
                DB[i]["suggests"],    \
                DB[i]["src_download"],        \
                DB[i]["src_download_x86_64"], \
                DB[i]["src_checksum"],        \
                DB[i]["src_checksum_x86_64"] >> index_dat;
    }
}

function pkupd_main() {
    register_arguments();
    if (!parse_arguments3(0, 65536)) {
        return 1;
    }

    if (OPTIONS["usage"] >= 2) {
        pkutils_version();
        return 0;
    }

    if (OPTIONS["usage"] >= 1) {
        usage("pkupd", "Synchronise package repositories.", "[OPTIONS]");
        return 0;
    }

    pk_setup_dirs(OPTIONS["root"]);
    if (!pk_check_dirs()) {
        printf "Have a nice day!\n";
        if (!pk_populate_dirs()) {
            printf "Failed to set up directories.\n" >> "/dev/stderr";
            return 255;
        }
    }
    pk_parse_options();

    pk_parse_repos_list();
    sync_repos();
    db_build();
    if (!DB["length"]) {
        printf "*\n"
        printf "* It looks like all repositories failed to synchronize.\n";
        printf "* Check your network connection.\n";
        printf "*\n";
        return 255;
    }

    write_index_dat(packages, total_packages);
}

BEGIN {
    rc = pkupd_main();
    exit rc;
}