
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

BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-(u|-upgrade)$/)
        {
            options["upgrade"] = 1;
        }
        else if (ARGV[i] ~ /^-(f|-reinstall)$/)
        {
            options["force"] = 1;
        }
        else if (ARGV[i] ~ /^-(d|-dry-run)$/)
        {
            options["dryrun"] = 1;
        }
        else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/)
        {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);
            option = m[1];
            value = m[2];

            if (option ~ /^-R$|^--root$/)           options["root"]     = value;
            else if (option ~ /^-r$|^--repo$/)      query["repo_id"]    = query["repo_id"] "|" value;
            else if (option ~ /^-e$|^--series$/)    query["series"]     = query["series"]  "|" value;
            else if (option ~ /^-v$|^--version$/)   query["version"]    = query["version"] "|" value;
            else if (option ~ /^-a$|^--arch$/)      query["arch"]       = query["arch"]    "|" value;
            else if (option ~ /^-t$|^--tag$/)       query["tag"]        = query["tag"]     "|" value;
            else {
                printf "Unrecognized option: %s\n", option;
                exit 1;
            }
        }
        else if (ARGV[i] ~ /^-/)
        {
            printf "Unrecognized argument: %s\n", ARGV[i];
            exit 1;
        }
        else
        {
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

    for (i = 1; i <= n; i++) {
        r = get_repo_idx(results[i]["repo_id"], repos);
        if (!r) exit 1;

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
                if (options["force"]) {
                    k = ++reinstall_list["count"];
                    reinstall_list["packages"][k]["name"]       = name;
                    reinstall_list["packages"][k]["file"]       = results[i]["output"];
                    reinstall_list["packages"][k]["hint"]       = sprintf("%s-%s-%s%s",
                                                                    results[i]["version"],
                                                                    results[i]["arch"],
                                                                    results[i]["build"],
                                                                    results[i]["tag"]);
                    reinstall_list["packages"][k]["url_scheme"] = repos[r]["url_scheme"];
                    reinstall_list["packages"][k]["url_host"]   = repos[r]["url_host"];
                    reinstall_list["packages"][k]["url_path"]   = results[i]["remote"];
                } else if (!(options["upgrade"] && !query["name"])) {
                    # do not show these messages if in upgrade mode and
                    # package name isn't set explicitly
                    printf "Package %s (%s) installed already.\n", name, results[i]["version"];
                }
            } else {
                # Is this package is in lock list?
                for (j in lock_list) {
                    if (installed[name]["name"]     ~ lock_list[j]["name"]       &&
                        installed[name]["version"]  ~ lock_list[j]["version"]    &&
                        installed[name]["arch"]     ~ lock_list[j]["arch"]       &&
                        installed[name]["build"]    ~ lock_list[j]["build"]      &&
                        installed[name]["tag"]      ~ lock_list[j]["tag"])
                    {
                        printf "Package %s is locked.\n", name;
                        locked = 1;
                        break;
                    }
                }

                if (locked) {
                    locked = 0;
                    continue;
                }

                k = ++upgrade_list["count"];
                upgrade_list["packages"][k]["name"]         = name;
                upgrade_list["packages"][k]["file"]         = results[i]["output"];
                upgrade_list["packages"][k]["hint"]         = sprintf("%s-%s-%s%s -> %s-%s-%s%s",
                                                                installed[name]["version"],
                                                                installed[name]["arch"],
                                                                installed[name]["build"],
                                                                installed[name]["tag"],
                                                                results[i]["version"],
                                                                results[i]["arch"],
                                                                results[i]["build"],
                                                                results[i]["tag"]);
                upgrade_list["packages"][k]["url_scheme"]   = repos[r]["url_scheme"];
                upgrade_list["packages"][k]["url_host"]     = repos[r]["url_host"];
                upgrade_list["packages"][k]["url_path"]     = results[i]["remote"];
            }
        } else {
            if (!options["upgrade"]) {
                k = ++install_list["count"];
                install_list["packages"][k]["name"]         = name;
                install_list["packages"][k]["file"]         = results[i]["output"];
                install_list["packages"][k]["hint"]         = sprintf("%s-%s-%s%s",
                                                                results[i]["version"],
                                                                results[i]["arch"],
                                                                results[i]["build"],
                                                                results[i]["tag"]);
                install_list["packages"][k]["url_scheme"]   = repos[r]["url_scheme"];
                install_list["packages"][k]["url_host"]     = repos[r]["url_host"];
                install_list["packages"][k]["url_path"]     = results[i]["remote"];
            }
        }
    }

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

        printf "Failed to download %d packages.\n", status > "/dev/stderr";
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
