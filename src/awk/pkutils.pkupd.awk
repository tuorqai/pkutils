
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function pkupd_parse_arguments(    i, m) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^=]+$/) {
            if (ARGV[i] ~ /^(-h|-?|--help)$/) {
                OPTIONS["help"] = 1;
            } else {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            }
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/) {
                OPTIONS["root"] = m[2];
            } else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            printf "Unrecognized argument: %s!\n", ARGV[i];
            return 0;
        }
    }

    return 1;
}

function pkupd_read_checksums(repo,    m, file) {
    RS = "\n"; FS = " ";

    while ((getline < repo["checksums_txt"]) > 0) {
        if (NF == 2) {
            # match($2, /^.*\/([^\/]*)-[^-]*-[^-]*-[^-]*\.t[bglx]z$/, m);
            match($2, /([^\/]*$)/, m);
            file = m[1];
            repo["checksums"][file] = $1;
        }
    }
    close(repo["checksums_txt"]);
}

function pkupd_sync_repo(repo,    index_txt, failed) {
    # quite dirty, but gotta somehow handle official repo's layout
    if (repo["name"] ~ /slackware|slackware64|extra|pasture|patches|testing/) {
        repo["url_path"] = repo["url_path"] "/" repo["name"];
    }

    printf "[%s] Updating %s://%s...\n", repo["type"], repo["url_scheme"], repo["url_path"];

    if (repo["type"] == "pk") {
        index_txt = "PACKAGES.TXT";
    } else if (repo["type"] == "sb") {
        index_txt = "SLACKBUILDS.TXT";
    } else {
        printf "-- Internal error: bad repo type %s!\n", repo["type"] > "/dev/stderr";
        return 0;
    }

    failed += pk_fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/CHECKSUMS.md5", repo["url_path"]),
                         sprintf("%s/CHECKSUMS.md5", repo["dir"]),
                         0);
    
    repo["checksums_txt"] = repo["dir"]"/CHECKSUMS.md5"
    pkupd_read_checksums(repo);

    failed += pk_fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/CHECKSUMS.md5.asc", repo["url_path"]),
                         sprintf("%s/CHECKSUMS.md5.asc", repo["dir"]),
                         repo["checksums"]["CHECKSUMS.md5.asc"]);
    failed += pk_fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/%s", repo["url_path"], index_txt),
                         sprintf("%s/%s", repo["dir"], index_txt),
                         repo["checksums"][index_txt]);
    repo["index_txt"] = sprintf("%s/%s", repo["dir"], index_txt);

    if (failed > 0) {
        printf "-- Failed to retrieve %d files.\n", failed > "/dev/stderr";
        return 0;
    }

    printf "\n";
    return 1;
}

function sync_repos(    i) {
    for (i = REPOS["length"]; i >= 1; i--) {
        if (!pkupd_sync_repo(REPOS[i])) {
            printf "Error: failed to synchronize \"%s\" repo!\n", REPOS[i]["name"] > "/dev/stderr";
            REPOS[i]["failed"] = 1;
        }
    }
    return;
}

function index_binary_package(repo, pk,   i, m) {
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

    pk["repo_id"] = repo["name"];
    pk["checksum"] = repo["checksums"][db_get_tar_name(pk)];
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
            sub(/:/, "\\:", $i);
            pk["src_download"] = $i;
        } else if ($i ~ /^SLACKBUILD DOWNLOAD_x86_64:\s+/) {
            sub(/SLACKBUILD DOWNLOAD_x86_64:\s+/, "", $i);
            sub(/:/, "\\:", $i);
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
    OFS = ":"; ORS = "\n";

    printf "Indexing %s...\n", repo["name"];

    while ((getline < repo["index_txt"]) > 0) {
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
    close(repo["index_txt"]);
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
                DB[i]["suggests"],    \
                DB[i]["src_download"],        \
                DB[i]["src_download_x86_64"], \
                DB[i]["src_checksum"],        \
                DB[i]["src_checksum_x86_64"] >> index_dat;
    }
}

function pkupd_main() {
    if (!pkupd_parse_arguments()) {
        return 1;
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