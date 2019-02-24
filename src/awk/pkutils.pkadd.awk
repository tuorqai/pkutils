
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function prompt_packages2(list,    p) {
    if (list["count"] == 0)
        return;

    printf "%d package(s) will be %s:\n", list["count"], toupper(list["action"]);
    for (p = 1; p <= list["count"]; p++) {
        printf "-- %s (%s)\n", list["packages"][p]["name"], list["packages"][p]["hint"];
    }
}

function process_packages2(list, options,    p) {
    if (list["count"] == 0)
        return;

    if (options["root"])
        list["command"] = sprintf("%s --root %s", list["command"], options["root"]);

    for (p = 1; p <= list["count"]; p++) {
        if (options["dryrun"] == 1) {
            printf ">> %s %s\n", list["command"], list["packages"][p]["file"];
            continue;
        }

        system(sprintf("%s %s", list["command"], list["packages"][p]["file"]));
    }
}

function answer(prompt, def,    reply) {
    if (def == "y")
        printf "%s [Y/n] ", prompt;
    else
        printf "%s [y/N] ", prompt;

    getline reply < "/dev/stdin";
    reply = tolower(reply);

    if (def == "y") {
        if (reply == "n")
            return 0;
        return 1;
    }

    if (reply == "y")
        return 1;
    return 0;
}

function get_repo_idx(name, repos,    r) {
    for (r in repos) {
        if (repos[r]["name"] == name) {
            return r;
        }
    }

    printf "Error: no repo %s\n", name > "/dev/stderr";
    return 0;
}

function fetch_all_packages(list,    errors, p) {
    for (p = 1; p <= list["count"]; p++) {
        errors += fetch_file(list["packages"][p]["url_scheme"],
                             list["packages"][p]["url_host"],
                             list["packages"][p]["url_path"],
                             list["packages"][p]["file"],
                             list["packages"][p]["checksum"]);
    }

    return errors;
}

function compare_packages(a, b) {
    if (a["name"]    == b["name"]    &&
        a["version"] == b["version"] &&
        a["arch"]    == b["arch"]    &&
        a["build"]   == b["build"]   &&
        a["tag"]     == b["tag"])
    {
        return 1;
    }

    return 0;
}

function is_package_locked(pk, locked,    x) {
    for (x in locked) {
        if (compare_packages(pk, locked[x])) {
            return 1;
        }
    }
    return 0;
}

function add_package_to_list(list, oldpk, newpk, repo, u,    x) {
    x = ++list["count"];
    list["packages"][x]["name"]       = newpk["name"];
    list["packages"][x]["file"]       = newpk["output"];
    
    list["packages"][x]["url_scheme"] = repo["url_scheme"];
    list["packages"][x]["url_host"]   = repo["url_host"];
    list["packages"][x]["url_path"]   = newpk["remote"];
    list["packages"][x]["checksum"]   = newpk["checksum"];

    if (oldpk) {
        list["packages"][x]["hint"] = sprintf("%s-%s-%s%s -> %s-%s-%s%s",
                                              oldpk["version"],
                                              oldpk["arch"],
                                              oldpk["build"],
                                              oldpk["tag"]);
    } else {
        list["packages"][x]["hint"] = sprintf("%s-%s-%s%s",
                                              newpk["version"],
                                              newpk["arch"],
                                              newpk["build"],
                                              newpk["tag"]);
    }
}

BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^=]+$/) {
                 if (ARGV[i] ~ /^(-u|--upgrade)$/)      options["upgrade"] = 1;
            else if (ARGV[i] ~ /^(-f|--reinstall)$/)    options["force"] = 1;
            else if (ARGV[i] ~ /^(-d|--dry-run)$/)      options["dryrun"] = 1;
            else {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                exit 1;
            }
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);
            option = m[1];
            value  = m[2];

                 if (option ~ /^-R$|^--root$/)      options["root"]     = value;
            else if (option ~ /^-r$|^--repo$/)      query["repo_id"]    = query["repo_id"] "|" value;
            else if (option ~ /^-e$|^--series$/)    query["series"]     = query["series"]  "|" value;
            else if (option ~ /^-v$|^--version$/)   query["version"]    = query["version"] "|" value;
            else if (option ~ /^-a$|^--arch$/)      query["arch"]       = query["arch"]    "|" value;
            else if (option ~ /^-t$|^--tag$/)       query["tag"]        = query["tag"]     "|" value;
            else {
                printf "Unrecognized option: %s\n", option >> "/dev/stderr";
                exit 1;
            }
        } else {
            query["name"] = query["name"] "|" ARGV[i];
        }
    }

    if (!setup_dirs(dirs, options["root"], 0)) {
        printf "Failed to set up directories.\n" > "/dev/stderr";
        exit 1;
    }

    #
    # Step 1: look for packages

    for (j in query)
        sub(/^\|/, "", query[j]);
    n = do_query(dirs["lib"]"/index.dat", query, results, 0, 1);
    if (!n) {
        printf "No packages found.\n";
    }

    #
    # Step 1.1: look up installed packages and get repos info

    make_current_state(dirs, installed);
    parse_repos_list(dirs["etc"]"/repos.list", repos);
    parse_lock_list(sprintf("%s/lock.list", dirs["etc"]), lock_list);

    #
    # Step 2: detect which packages should be upgraded or installed

    reinstall_list["action"] = "reinstalled";
    reinstall_list["command"] = "upgradepkg --reinstall";
    reinstall_list["count"] = 0;
    reinstall_list["packages"][0] = 0;

    install_list["action"] = "installed";
    install_list["command"] = "installpkg";
    install_list["count"] = 0;
    install_list["packages"][0] = 0;

    upgrade_list["action"] = "upgraded";
    upgrade_list["command"] = "upgradepkg";
    upgrade_list["count"] = 0;
    upgrade_list["packages"][0] = 0;

    for (p = 1; p <= n; p++) {
        r = get_repo_idx(results[p]["repo_id"], repos);
        if (!r) exit 1;

        results[p]["fullname"] = sprintf("%s-%s-%s-%s%s.%s",
                                         results[p]["name"],
                                         results[p]["version"],
                                         results[p]["arch"],
                                         results[p]["build"],
                                         results[p]["tag"],
                                         results[p]["type"]);
        results[p]["remote"]   = sprintf("%s/%s/%s",
                                         repos[r]["url_path"],
                                         results[p]["location"],
                                         results[p]["fullname"]);
        results[p]["output"]   = sprintf("%s/%s/%s",
                                         dirs["cache"],
                                         repos[r]["name"],
                                         results[p]["fullname"]);

        name = results[p]["name"];

        if (name in installed) {
            if (results[p]["version"] == installed[name]["version"]) {
                #
                # Case A: same package of exact same version is installed
                if (options["force"]) {
                    add_package_to_list(reinstall_list, 0, results[p], repos[r]);
                    continue;
                }

                if (query["name"])
                    printf "Package %s (%s) installed already.\n", name, results[p]["version"];
            } else {
                #
                # Case B: same package is installed but version is different
                if (is_package_locked(installed[name], lock_list)) {
                    printf "Package %s (%s) is locked.\n", name, results[p]["version"];
                    continue;
                }

                add_package_to_list(upgrade_list, installed[name], results[p], repos[r]);
            }
        } else {
            #
            # Case C: package is not installed
            if (options["upgrade"])
                continue;
            add_package_to_list(install_list, 0, results[p], repos[r]);
        }
    }

    delete results;
    delete repos;

    #
    # Step 3: Prompt user

    if (reinstall_list["count"] == 0 &&
        install_list["count"]   == 0 &&
        upgrade_list["count"]   == 0)
    {
        printf "Nothing to do.\n";
        exit 0;
    }

    prompt_packages2(reinstall_list);
    prompt_packages2(install_list);
    prompt_packages2(upgrade_list);

    if (answer("Continue?", "y") == 0) {
        printf "OK...\n";
        exit 0;
    }

    #
    # Step 4: download packages to cache

    while (1) {
        errors += fetch_all_packages(reinstall_list);
        errors += fetch_all_packages(install_list);
        errors += fetch_all_packages(upgrade_list);

        if (!errors) {
            printf "All packages downloaded successfully.\n";
            break;
        }

        printf "Failed to download %d packages.\n", errors > "/dev/stderr";
        if (answer("Retry?", "n") == 1) {
            errors = 0;
            continue;
        }

        exit 1;
    }

    #
    # Step N: actually reinstall/install/upgrade packages

    process_packages2(reinstall_list, options);
    process_packages2(install_list, options);
    process_packages2(upgrade_list, options);

    printf "Done.\n";
}
