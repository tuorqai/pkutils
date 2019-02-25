
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function pkadd_parse_arguments(argc, argv, _options, _query,    i, m) {
    for (i = 1; i < argc; i++) {
        if (argv[i] ~ /^-[^=]+$/) {
                 if (argv[i] ~ /^(-u|--upgrade)$/)      _options["upgrade"] = 1;
            else if (argv[i] ~ /^(-f|--reinstall)$/)    _options["force"] = 1;
            else if (argv[i] ~ /^(-d|--dry-run)$/)      _options["dryrun"] = 1;
            else {
                printf "Unrecognized option: %s\n", argv[i] >> "/dev/stderr";
                return 0;
            }
        } else if (argv[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(argv[i], /^([^=]+)=([^=]+)$/, m);

                 if (m[1] ~ /^-R$|^--root$/)    { _options["root"]  = m[2]; }
            else if (m[1] ~ /^-r$|^--repo$/)    { _query["repo_id"] = _query["repo_id"] "|" m[2]; }
            else if (m[1] ~ /^-e$|^--series$/)  { _query["series"]  = _query["series"]  "|" m[2]; }
            else if (m[1] ~ /^-v$|^--version$/) { _query["version"] = _query["version"] "|" m[2]; }
            else if (m[1] ~ /^-a$|^--arch$/)    { _query["arch"]    = _query["arch"]    "|" m[2]; }
            else if (m[1] ~ /^-t$|^--tag$/)     { _query["tag"]     = _query["tag"]     "|" m[2]; }
            else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            _query["name"] = _query["name"] "|" argv[i];
        }
    }

    return 1;
}

function pkadd_query(results, _query,    i) {
    for (i in _query) {
        sub(/^\|/, "", _query[i]);
    }
    return pk_query(results, _query, dirs["lib"] "/index.dat", 1, 1);
}

function pkadd_repo_get_index(name, repos,    i) {
    for (i in repos) {
        if (repos[i]["name"] == name) {
            return i;
        }
    }

    printf "Error: no repo %s\n", name > "/dev/stderr";
    return 0;
}

function pkadd_elist_add(elist, oldpk, pk, repo,    i) {
    i = ++elist["count"];
    elist["packages"][i]["name"]        = pk["name"];
    elist["packages"][i]["file"]        = pk["output"];
    elist["packages"][i]["url_scheme"]  = repo["url_scheme"];
    elist["packages"][i]["url_host"]    = repo["url_host"];
    elist["packages"][i]["url_path"]    = pk["remote"];
    elist["packages"][i]["checksum"]    = pk["checksum"];
    elist["packages"][i]["hint"]        = sprintf("%s-%s-%s%s",
                                                  pk["version"],
                                                  pk["arch"],
                                                  pk["build"],
                                                  pk["tag"]);

    if (isarray(oldpk)) {
        elist["packages"][i]["hint"] = sprintf("%s-%s-%s%s -> %s",
                                               oldpk["version"],
                                               oldpk["arch"],
                                               oldpk["build"],
                                               oldpk["tag"],
                                               elist["packages"][i]["hint"]);
    }
}

function pkadd_elist_prompt(elist,    i) {
    if (elist["count"] == 0) {
        return;
    }

    printf "%d package(s) will be %s:\n", elist["count"], toupper(elist["action"]);
    for (i = 1; i <= elist["count"]; i++) {
        printf "-- %s (%s)\n", elist["packages"][i]["name"], elist["packages"][i]["hint"];
    }
}

function pkadd_elist_fetch_all(elist,    errors, i) {
    for (i = 1; i <= elist["count"]; i++) {
        errors += pk_fetch_file(elist["packages"][i]["url_scheme"],
                                elist["packages"][i]["url_host"],
                                elist["packages"][i]["url_path"],
                                elist["packages"][i]["file"],
                                elist["packages"][i]["checksum"]);
    }

    return errors;
}

function pkadd_fetch(elistr, elisti, elistu, options,    errors) {
    if (options["dryrun"]) {
        printf "Dry run - do not download anything.\n";
        return 1;
    }

    while (1) {
        errors += pkadd_elist_fetch_all(elistr);
        errors += pkadd_elist_fetch_all(elisti);
        errors += pkadd_elist_fetch_all(elistu);

        if (!errors) {
            printf "All packages downloaded successfully.\n";
            break;
        }

        printf "Failed to download %d packages.\n", errors > "/dev/stderr";
        if (pk_answer("Retry?", "n") == 1) {
            errors = 0;
            continue;
        }

        return 0;
    }
    return 1;
}

function pkadd_elist_process(elist, options,    i) {
    if (elist["count"] == 0) {
        return;
    }

    if (options["root"]) {
        elist["command"] = sprintf("%s --root %s", elist["command"], options["root"]);
    }

    for (i = 1; i <= elist["count"]; i++) {
        if (options["dryrun"]) {
            printf ">> %s %s\n", elist["command"], elist["packages"][i]["file"];
            continue;
        }

        system(elist["command"] " " elist["packages"][i]["file"]);
    }
}

function pkadd_main(    i, j, options, query, packages, total_packages, installed,
                        repos, locked, elistr, elisti, elistu,
                        pkstatus, oldpk)
{
    if (!pkadd_parse_arguments(ARGC, ARGV, options, query)) {
        return 1;
    }

    pk_setup_dirs(dirs, options["root"]);
    if (!pk_check_dirs(dirs)) {
        printf "Run `pkupd' first!\n";
        return 1;
    }

    total_packages = pkadd_query(packages, query);
    if (total_packages <= 0) {
        printf "No packages found.\n";
        return 0;
    }

    pk_get_installed_packages(dirs, installed);
    pk_parse_repos_list(dirs, repos);
    pk_parse_lock_list(dirs, locked);

    elistr["action"] = "reinstalled";
    elistr["command"] = "upgradepkg --reinstall";
    elistr["count"] = 0;
    elistr["packages"][0] = 0;

    elisti["action"] = "installed";
    elisti["command"] = "installpkg";
    elisti["count"] = 0;
    elisti["packages"][0] = 0;

    elistu["action"] = "upgraded";
    elistu["command"] = "upgradepkg";
    elistu["count"] = 0;
    elistu["packages"][0] = 0;

    for (i = 1; i <= total_packages; i++) {
        j = pkadd_repo_get_index(packages[i]["repo_id"], repos);
        if (j <= 0) {
            return 1;
        }

        packages[i]["fullname"] = sprintf("%s-%s-%s-%s%s.%s",
                                          packages[i]["name"],
                                          packages[i]["version"],
                                          packages[i]["arch"],
                                          packages[i]["build"],
                                          packages[i]["tag"],
                                          packages[i]["type"]);
        packages[i]["remote"]   = sprintf("%s/%s/%s",
                                          repos[j]["url_path"],
                                          packages[i]["location"],
                                          packages[i]["fullname"]);
        packages[i]["output"]   = sprintf("%s/%s/%s",
                                          dirs["cache"],
                                          repos[j]["name"],
                                          packages[i]["fullname"]);

        pkstatus = pk_is_installed(packages[i], installed, oldpk);

        if (pkstatus == 1) {
            #
            # Case A: same package of exact same version is installed
            if (options["force"]) {
                pkadd_elist_add(elistr, 0, packages[i], repos[j]);
                continue;
            }

            if (query["name"]) {
                printf "Package %s (%s) installed already.\n", packages[i]["name"], packages[i]["version"];
            }
        } else if (pkstatus == 2) {
            #
            # Case B: same package is installed but version is different
            if (pk_is_locked(packages[i], locked)) {
                printf "Package %s (%s) is locked.\n", packages[i]["name"], packages[i]["version"];
                continue;
            }

            pkadd_elist_add(elistu, oldpk, packages[i], repos[j]);
        } else {
            #
            # Case C: package is not installed
            if (options["upgrade"]) {
                continue;
            }
            pkadd_elist_add(elisti, 0, packages[i], repos[j]);
        }
    }

    delete packages;
    delete repos;

    if (elistr["count"] == 0 &&
        elisti["count"] == 0 &&
        elistu["count"] == 0)
    {
        printf "Nothing to do.\n";
        exit 0;
    }

    pkadd_elist_prompt(elistr);
    pkadd_elist_prompt(elisti);
    pkadd_elist_prompt(elistu);

    if (pk_answer("Continue?", "y") == 0) {
        printf "Exiting...\n";
        return 1;
    }

    if (!pkadd_fetch(elistr, elisti, elistu, options)) {
        printf "Exiting...\n";
        return 1;
    }

    pkadd_elist_process(elistr, options);
    pkadd_elist_process(elisti, options);
    pkadd_elist_process(elistu, options);

    printf "Done.\n";
}

BEGIN {
    rc = pkadd_main();
    exit rc;
}
