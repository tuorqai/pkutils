
@include "pkutils.foundation.awk"

function read_checksums(repo,    m, file) {
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
    delete repo["checksums_txt"];
}

function make_index(repo, output,    package, m) {
    FS = "\n"; RS = "";
    OFS = ":"; ORS = "\n";

    while ((getline < repo["txt"]) > 0) {
        if ($0 ~ /^PACKAGE\s+/) {
            for (i = 1; i < NF; i++) {
                if ($i ~ /^PACKAGE NAME:\s+.*/) {
                    sub(/PACKAGE NAME:\s+/, "", $i);
                    match($i, /(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)\.(t[bglx]z)/, m);

                    package["name"] = m[1];
                    package["version"] = m[2];
                    package["arch"] = m[3];
                    package["build"] = m[4];
                    package["tag"] = m[5];
                    package["type"] = m[6];
                } else if ($i ~ /^PACKAGE LOCATION:\s+.*/) {
                    sub(/PACKAGE LOCATION:\s+(\.\/)?/, "", $i);
                    match($i, /([^\/]*$)/, m);

                    package["location"] = $i;
                    package["series"] = m[1];
                }
            }
            package["file"] = sprintf("%s-%s-%s-%s%s.%s",
                package["name"], package["version"], package["arch"],
                package["build"], package["tag"], package["type"]);
            package["checksum"] = repo["checksums"][package["file"]];
            delete package["file"];
        } else if ($0 ~ /^SLACKBUILD\s+/) {
            for (i = 1; i < NF; i++) {
                if ($i ~ /^SLACKBUILD NAME:\s+/) {
                    sub(/SLACKBUILD NAME:\s+/, "", $i);
                    package["name"] = $i;
                } else if ($i ~ /^SLACKBUILD LOCATION:\s+/) {
                    sub(/SLACKBUILD LOCATION:\s+/, "", $i);
                    package["location"] = $i;
                } else if ($i ~ /^SLACKBUILD VERSION:\s+/) {
                    sub(/SLACKBUILD VERSION:\s+/, "", $i);
                    package["version"] = $i;
                }
            }
            
            match(package["location"], /.*\/([^\/]*)\/[^\/]*/, m);
            package["series"] = m[1];
            package["arch"] = "source";
            package["build"] = 0;
            package["type"] = "SlackBuild";
            package["checksum"] = 0;
        } else {
            continue;
        }

        print repo["type"], repo["name"], repo["url_scheme"], \
            repo["url_host"], repo["url_path"], \
            package["location"], package["series"], \
            package["name"], package["version"], package["arch"], \
            package["build"], package["tag"], package["type"], \
            package["checksum"] >> output;
    }
    close(repo["txt"]);
    delete repo["txt"];
}

function update_and_index_repo(repo, index_dat,    index_txt, status) {
    # quite dirty, but gotta somehow handle official repo's layout
    if (repo["name"] ~ /slackware|slackware64|extra|pasture|patches|testing/) {
        repo["url_path"] = sprintf("%s/%s", repo["url_path"], repo["name"]);
    }

    printf "[%s] Updating and indexing %s://%s...\n", repo["type"], repo["url_scheme"], repo["url_path"];

    if (repo["type"] == "pk") {
        index_txt = "PACKAGES.TXT";
    } else if (repo["type"] == "sb") {
        index_txt = "SLACKBUILDS.TXT";
    } else {
        printf "-- Internal error: bad repo type %s!\n", repo["type"] > "/dev/stderr";
        return 0;
    }

    status += fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/CHECKSUMS.md5", repo["url_path"]),
                         sprintf("%s/CHECKSUMS.md5", repo["dir"]));
    
    repo["checksums_txt"] = repo["dir"]"/CHECKSUMS.md5"
    read_checksums(repo);

    status += fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/CHECKSUMS.md5.asc", repo["url_path"]),
                         sprintf("%s/CHECKSUMS.md5.asc", repo["dir"]),
                         repo["checksums"]["CHECKSUMS.md5.asc"]);
    status += fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/%s", repo["url_path"], index_txt),
                         sprintf("%s/%s", repo["dir"], index_txt),
                         repo["checksums"][index_txt]);
    repo["txt"] = sprintf("%s/%s", repo["dir"], index_txt);

    if (status > 0) {
        printf "-- Failed to retrieve %d files.\n", status > "/dev/stderr";
        return 0;
    }

    make_index(repo, index_dat);
    printf "\n";
    return 1;
}

function pkupd(dirs, repos,    r, total_repos, index_dat) {
    index_dat = sprintf("%s/index.dat", dirs["lib"]);

    # is there a better way to wipe out a file?
    printf "" > index_dat;

    total_repos = length(repos);

    for (r = total_repos; r >= 1; r--) {
        if (!update_and_index_repo(repos[r], index_dat)) {
            printf "Error: failed to synchronize \"%s\" repo!\n", repos[r]["name"] > "/dev/stderr";
            return 0;
        }
    }
    fflush(index_dat);
    return 1;
}

BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^--root=.+/) {
            match(ARGV[i], /^(--root=)(.*)/, m);
            root = m[2];
        } else {
            printf "Unrecognized argument: %s!\n", ARGV[i];
            exit 1;
        }
    }

    if (!setup_dirs(dirs, root, 0)) {
        printf "Failed to set up directories.\n" >> "/dev/stderr";
        exit 1;
    }

    parse_repos_list(sprintf("%s/repos.list", dirs["etc"]), repos);
    status = pkupd(dirs, repos);
    if (!status) {
        printf "Failed to synchronize repositories!\n" > "/dev/stderr";
        exit 1;
    }
}