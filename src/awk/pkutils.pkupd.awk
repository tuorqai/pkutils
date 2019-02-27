
@include "pkutils.foundation.awk"

function pkupd_parse_arguments(argc, argv, options,    i, m) {
    for (i = 1; i < argc; i++) {
        if (argv[i] ~ /^-[^=]+$/) {
            if (argv[i] ~ /^(-h|-?|--help)$/) {
                options["help"] = 1;
            } else {
                printf "Unrecognized option: %s\n", argv[i] >> "/dev/stderr";
                return 0;
            }
        } else if (argv[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(argv[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/) {
                options["root"] = m[2];
            } else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            printf "Unrecognized argument: %s!\n", argv[i];
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

function pkupd_sync_repo(repo, options,    index_txt, failed) {
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
                         0, options);
    
    repo["checksums_txt"] = repo["dir"]"/CHECKSUMS.md5"
    pkupd_read_checksums(repo);

    failed += pk_fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/CHECKSUMS.md5.asc", repo["url_path"]),
                         sprintf("%s/CHECKSUMS.md5.asc", repo["dir"]),
                         repo["checksums"]["CHECKSUMS.md5.asc"],
                         options);
    failed += pk_fetch_file(repo["url_scheme"], repo["url_host"],
                         sprintf("%s/%s", repo["url_path"], index_txt),
                         sprintf("%s/%s", repo["dir"], index_txt),
                         repo["checksums"][index_txt],
                         options);
    repo["index_txt"] = sprintf("%s/%s", repo["dir"], index_txt);

    if (failed > 0) {
        printf "-- Failed to retrieve %d files.\n", failed > "/dev/stderr";
        return 0;
    }

    printf "\n";
    return 1;
}

function pkupd_sync_repos(repos, total_repos, options,    i) {
    for (i = total_repos; i >= 1; i--) {
        if (!pkupd_sync_repo(repos[i], options)) {
            printf "Error: failed to synchronize \"%s\" repo!\n", repos[i]["name"] > "/dev/stderr";
            delete repos[i];
            return 0;
        }
    }
    return 1;
}

function pkupd_index_repo(repo, packages, total,    file, m) {
    FS = "\n"; RS = "";
    OFS = ":"; ORS = "\n";

    printf "Indexing %s...\n", repo["name"];

    while ((getline < repo["index_txt"]) > 0) {
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
                } else if ($i ~ "^" package["name"] ": " package["name"] " \\(.+\\)$") {
                    match($i, "^" package["name"] ": " package["name"] " \\((.+)\\)$", m);

                    package["description"] = m[1];
                }
            }
            file = sprintf("%s-%s-%s-%s%s.%s",
                package["name"], package["version"], package["arch"],
                package["build"], package["tag"], package["type"]);
            package["checksum"] = repo["checksums"][file];
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

        if (!package["description"]) {
            package["description"] = "(no description)";
        }
        
        total++;
        packages[total]["repo_id"]      = repo["name"];
        packages[total]["location"]     = package["location"];
        packages[total]["series"]       = package["series"];
        packages[total]["name"]         = package["name"];
        packages[total]["version"]      = package["version"];
        packages[total]["arch"]         = package["arch"];
        packages[total]["build"]        = package["build"];
        packages[total]["tag"]          = package["tag"];
        packages[total]["type"]         = package["type"];
        packages[total]["checksum"]     = package["checksum"];
        packages[total]["description"]  = package["description"];

        delete package["description"];
    }
    close(repo["index_txt"]);

    return total;
}

function pkupd_make_package_list(repos, total_repos, packages,    i, total) {
    for (i = total_repos; i >= 1; i--) {
        if (!(i in repos)) {
            continue;
        }
        total = pkupd_index_repo(repos[i], packages, total);
    }

    return total;
}

function pkupd_write_package_list(db, packages, total_packages,    i) {
    printf "" > db;

    for (i = 1; i <= total_packages; i++) {
        print packages[i]["repo_id"], packages[i]["location"], packages[i]["series"], \
            packages[i]["name"], packages[i]["version"], packages[i]["arch"], \
            packages[i]["build"], packages[i]["tag"], packages[i]["type"], \
            packages[i]["checksum"], packages[i]["description"] >> db;
    }
}

function pkupd_main(    options, dirs, repos, total_repos, packages, total_packages, status) {
    if (!pkupd_parse_arguments(ARGC, ARGV, options)) {
        return 1;
    }

    pk_setup_dirs(dirs, options["root"]);
    if (!pk_check_dirs(dirs)) {
        printf "Have a nice day!\n";
        if (!pk_populate_dirs(dirs)) {
            printf "Failed to set up directories.\n" >> "/dev/stderr";
            return 1;
        }
    }

    pk_parse_options(dirs, options);

    total_repos = pk_parse_repos_list(dirs, repos);
    pkupd_sync_repos(repos, total_repos, options);
    total_packages = pkupd_make_package_list(repos, total_repos, packages);
    pkupd_write_package_list(dirs["lib"] "/index.dat", packages, total_packages);
}

BEGIN {
    rc = pkupd_main();
    exit rc;
}