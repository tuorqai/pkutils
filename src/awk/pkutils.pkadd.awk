
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-(u|-upgrade)$/) {
            upgrade_mode = 1;
        } else if (ARGV[i] ~ /^-(f|-reinstall)$/) {
            force_mode = 1;
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);
            option = m[1];
            value = m[2];

            if (option ~ /^-R$|^--root$/)           root = value;
            else if (option ~ /^-r$|^--repo$/)      query["repo_id"] = query["repo_id"] "|" value;
            else if (option ~ /^-e$|^--series$/)    query["series"]  = query["series"]  "|" value;
            else if (option ~ /^-v$|^--version$/)   query["version"] = query["version"] "|" value;
            else if (option ~ /^-a$|^--arch$/)      query["arch"]    = query["arch"]    "|" value;
            else if (option ~ /^-t$|^--tag$/)       query["tag"]     = query["tag"]     "|" value;
            else {
                printf "Unrecognized option: %s\n", option;
                exit 1;
            }
        } else if (ARGV[i] ~ /^-/) {
            printf "Unrecognized argument: %s\n", ARGV[i];
            exit 1;
        } else {
            query["name"] = query["name"] "|" ARGV[i];
        }
    }

    for (j in query) sub(/^\|/, "", query[j]);

    setup_dirs(dirs, root);

    #
    # Step 1: look for packages

    n = do_query(dirs["lib"]"/index.dat", query, results, 0, 1);
    if (!n) {
        printf "No packages found.\n";
    }

    #
    # Step 1.1: look up installed packages and get repos info

    make_current_state(dirs, installed);
    parse_repos_list(dirs["etc"]"/repos.list", repos);

    #
    # Step 2: detect which packages should be upgraded or installed

    # dirty way to explicitly initialize arrays
    reinstall_list[0] = 0;
    install_list[0] = 0;
    upgrade_list[0] = 0;

    for (i = 1; i <= n; i++) {
        r = results[i]["repo_id"];

        results[i]["fullname"] = sprintf("%s-%s-%s-%s%s.%s",
                                         results[i]["name"],
                                         results[i]["version"],
                                         results[i]["arch"],
                                         results[i]["build"],
                                         results[i]["tag"],
                                         results[i]["type"]);
        results[i]["remote"]   = sprintf("%s/%s/%s",
                                         repos[r]["url_path"],
                                         results[i]["location"],
                                         results[i]["fullname"]);
        results[i]["output"]   = sprintf("%s/%s/%s",
                                         dirs["cache"],
                                         repos[r]["name"],
                                         results[i]["fullname"]);

        name = results[i]["name"];

        if (name in installed) {
            if (results[i]["version"] == installed[name]["version"]) {
                if (force_mode) {
                    reinstall_list[name] = results[i]["output"];
                } else if (!(upgrade_mode && !query["name"])) {
                    # do not show these messages if in upgrade mode and
                    # package name isn't set explicitly
                    printf "Package %s (%s) installed already.\n", name, results[i]["version"];
                }
            } else {
                upgrade_list[name] = results[i]["output"];
            }
        } else {
            if (!upgrade_mode) {
                install_list[name] = results[i]["output"];
            }
        }
    }

    #
    # Step 3: Prompt user

    if (length(reinstall_list) + length(install_list) + length(upgrade_list) == 3) {
        printf "Nothing to do.\n"
        exit 0;
    }

    if (length(reinstall_list) > 1) {
        printf "%d package(s) will be REINSTALLED:\n", length(reinstall_list);
        for (j in reinstall_list) {
            if (j == 0) continue;
            printf "-- %s\n", j;
        }
    }

    if (length(install_list) > 1) {
        printf "%d NEW package(s) will be INSTALLED:\n", length(install_list);
        for (j in install_list) {
            if (j == 0) continue;
            printf "-- %s\n", j;
        }
    }

    if (length(upgrade_list) > 1) {
        printf "%d package(s) will be UPGRADED:\n", length(upgrade_list);
        for (j in upgrade_list) {
            if (j == 0) continue;
            printf "-- %s\n", j;
        }
    }

    printf "Continue? (Y/n) ";
    getline answer < "/dev/stdin";
    answer = tolower(answer);
    if (answer == "n") {
        exit 0;
    }

    #
    # Step 4: download packages to cache

    while (1) {
        for (p = 1; p <= n; p++) {
            if (!(results[p]["name"] in reinstall_list ||
                  results[p]["name"] in install_list ||
                  results[p]["name"] in upgrade_list))
                continue;
            r = results[p]["repo_id"];
            status += fetch_file(repos[r]["url_scheme"], repos[r]["url_host"],
                results[p]["remote"], results[p]["output"], results[p]["checksum"]);
        }

        if (!status) {
            printf "All packages downloaded successfully.\n";
            break;
        }

        exit 1;
    }

    if (root) {
        pkgtools_root = sprintf("--root %s", root);
    }

    #
    # Step N: actually reinstall/install/upgrade packages

    if (length(reinstall_list) > 1) {
        for (j in reinstall_list) {
            if (j == 0) continue;
            printf "upgradepkg %s --reinstall %s\n", pkgtools_root, reinstall_list[j];
        }
    }

    if (length(install_list) > 1) {
        for (j in install_list) {
            if (j == 0) continue;
            printf "installpkg %s %s\n", pkgtools_root, install_list[j];
        }
    }

    if (length(upgrade_list) > 1) {
        for (j in upgrade_list) {
            if (j == 0) continue;
            printf "upgradepkg %s %s\n", pkgtools_root, upgrade_list[j];
        }
    }

    printf "Done.\n";
}
