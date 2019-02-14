
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function prompt_packages(action, list,    p) {
    if (length(list) <= 1)
        return 0;

    printf "%d package(s) will be %s:\n", (length(list) - 1), action;
    for (p in list) {
        if (p == 0) continue;
        printf "-- %s\n", p;
    }

    return (length(list) - 1);
}

function process_packages(cmd, list, options,    p) {
    if (length(list) <= 1)
        return;

    if (options["root"])
        cmd = sprintf("%s --root %s", cmd, options["root"]);

    for (p in list) {
        if (p == 0) continue;
        if (options["dryrun"] == 1) {
            printf ">> %s %s\n", cmd, list[p];
            continue;
        }

        system(sprintf("%s %s", cmd, list[p]));
    }
}

function answer(prompt, def,    reply) {
    if (def == "y")
        printf "%s (Y/n) ", prompt;
    else
        printf "%s (y/N) ", prompt;

    getline reply < "/dev/stdin";
    reply = tolower(reply);

    if (reply != def)
        return 0;

    return 1;
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

    # dirty way to explicitly initialize arrays
    reinstall_list[0] = 0;
    install_list[0] = 0;
    upgrade_list[0] = 0;

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
                    reinstall_list[name] = results[i]["output"];
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
                if (locked)
                    continue;

                upgrade_list[name] = results[i]["output"];
            }
        } else {
            if (!options["upgrade"]) {
                install_list[name] = results[i]["output"];
            }
        }
    }

    #
    # Step 3: Prompt user

    sum += prompt_packages("REINSTALLED", reinstall_list);
    sum += prompt_packages("INSTALLED", install_list);
    sum += prompt_packages("UPGRADED", upgrade_list);

    if (sum == 0) {
        printf "Nothing to do.\n";
        exit 0;
    }

    if (answer("Continue?", "y")) {
        printf "OK...\n";
        exit 0;
    }

    #
    # Step 4: download packages to cache

    while (1) {
        for (p = 1; p <= n; p++) {
            if (!(results[p]["name"] in reinstall_list ||
                  results[p]["name"] in install_list ||
                  results[p]["name"] in upgrade_list))
            {
                continue;
            }
            r = get_repo_idx(results[p]["repo_id"], repos);
            if (!r) exit 1;
            status += fetch_file(repos[r]["url_scheme"], repos[r]["url_host"],
                results[p]["remote"], results[p]["output"], results[p]["checksum"]);
        }

        if (!status) {
            printf "All packages downloaded successfully.\n";
            break;
        }

        printf "Failed to download %d packages.\n", status > "/dev/stderr";
        if (answer("Retry?", "n")) {
            status = 0;
            continue;
        }

        exit 1;
    }

    #
    # Step N: actually reinstall/install/upgrade packages

    process_packages("upgradepkg --reinstall", reinstall_list);
    process_packages("installpkg", install_list);
    process_packages("upgradepkg", upgrade_list);

    printf "Done.\n";
}
