
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function pkadd_parse_arguments(argc, argv, _options, _query,    i, m) {
    for (i = 1; i < argc; i++) {
        if (argv[i] ~ /^-[^=]+$/) {
                 if (argv[i] ~ /^(-u|--upgrade)$/)      _options["upgrade"] = 1;
            else if (argv[i] ~ /^(-f|--reinstall)$/)    _options["force"] = 1;
            else if (argv[i] ~ /^(-d|--dry-run)$/)      _options["dryrun"] = 1;
            else if (argv[i] ~ /^(--enable-deps)$/)     _options["use_deps"] = 1;
            else if (argv[i] ~ /^(--disable-deps)$/)    _options["use_deps"] = 0;
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
    for (i = 1; i <= elist["count"]; i++) {
        if (elist["packages"][i]["name"] == pk["name"]) {
            return;
        }
    }

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

    printf "\n%d package(s) will be %s:\n", elist["count"], toupper(elist["action"]);
    for (i = 1; i <= elist["count"]; i++) {
        printf "-- %s (%s)\n", elist["packages"][i]["name"], elist["packages"][i]["hint"];
    }
    printf "\n";
}

function pkadd_elist_fetch_all(elist, options,    errors, i) {
    for (i = 1; i <= elist["count"]; i++) {
        errors += pk_fetch_file(elist["packages"][i]["url_scheme"],
                                elist["packages"][i]["url_host"],
                                elist["packages"][i]["url_path"],
                                elist["packages"][i]["file"],
                                elist["packages"][i]["checksum"],
                                options);
    }

    return errors;
}

function pkadd_fetch(elistr, elisti, elistu, options,    errors) {
    while (1) {
        errors += pkadd_elist_fetch_all(elistr, options);
        errors += pkadd_elist_fetch_all(elisti, options);
        errors += pkadd_elist_fetch_all(elistu, options);

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

function pkadd_insert_package(pk, repos, installed, locked, _er, _eu, _ei, options,
                                  i, r, status, oldpk,
                                  dep, total_deps, dep_names, dep_query, deps_found)
{
    if (pk["required"] && options["use_deps"] && !options["upgrade"]) {
        total_deps = split(pk["required"], dep_names, /,/);
        for (i = 1; i <= total_deps; i++) {
            sub(/[<>=][A-Za-z0-9\.]$/, "", dep_names[i]);
            dep_query["name"] = dep_names[i];
            deps_found = pkadd_query(dep, dep_query);
            if (deps_found > 0) {
                status = pkadd_insert_package(dep[1],
                repos, installed, locked,
                _er, _eu, _ei, options);
                if (status == 0) { return 0; }
                delete dep_query;
                continue;
            }

            printf "Warning: can't find dependency %s for %s\n", \
                dep_names[i], pk["name"] >> "/dev/stderr";
        }
    }

    r = pkadd_repo_get_index(pk["repo_id"], repos);
    if (r <= 0) {
        printf "Warning: can't find repository %s!\n", pk["repo_id"] >> "/dev/stderr";
        printf "Package %s will not installed or upgraded.\n", pk["name"] >> "/dev/stderr";
        return 1;
    }

    pk["fullname"] = sprintf("%s-%s-%s-%s%s.%s",
        pk["name"], pk["version"], pk["arch"],
        pk["build"], pk["tag"], pk["type"]);
    pk["remote"]   = sprintf("%s/%s/%s",
        repos[r]["url_path"], pk["location"], pk["fullname"]);
    pk["output"]   = sprintf("%s/%s/%s",
        dirs["cache"], repos[r]["name"], pk["fullname"]);

    status = pk_is_installed(pk, installed, oldpk);

    if (status == 1) {
        #
        # Case A: same package of exact same version is installed
        if (options["force"]) {
            pkadd_elist_add(_er, 0, pk, repos[r]);
            return 1;
        }

        if (query["name"]) {
            printf "Package %s (%s) installed already.\n", pk["name"], pk["version"];
        }
    } else if (status == 2) {
        #
        # Case B: same package is installed but version is different
        if (pk_is_locked(pk, locked)) {
            printf "Package %s (%s) is locked.\n", pk["name"], pk["version"];
            return 1;
        }

        pkadd_elist_add(_eu, oldpk, pk, repos[r]);
    } else {
        #
        # Case C: package is not installed
        if (options["upgrade"]) {
            return 1;
        }
        pkadd_elist_add(_ei, 0, pk, repos[r]);
    }

    return 1;
}

function pkadd_main(    i, options, query, packages, total_packages, installed,
                        repos, locked, elistr, elisti, elistu, status)
{
    if (!pkadd_parse_arguments(ARGC, ARGV, options, query)) {
        return 255;
    }

    pk_setup_dirs(dirs, options["root"]);
    if (!pk_check_dirs(dirs)) {
        printf "Run `pkupd' first!\n";
        return 255;
    }

    pk_parse_options(dirs, options);

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

    elistu["action"] = "upgraded";
    elistu["command"] = "upgradepkg";
    elistu["count"] = 0;
    elistu["packages"][0] = 0;

    elisti["action"] = "installed";
    elisti["command"] = "installpkg";
    elisti["count"] = 0;
    elisti["packages"][0] = 0;

    for (i = 1; i <= total_packages; i++) {
        status = pkadd_insert_package(packages[i], repos, installed, locked,
            elistr, elistu, elisti, options);
        if (!status) {
            return 255;
        }
    }

    delete packages;
    delete repos;

    if (elistr["count"] == 0 &&
        elisti["count"] == 0 &&
        elistu["count"] == 0)
    {
        printf "Nothing to do.\n";
        return 0;
    }

    pkadd_elist_prompt(elistr);
    pkadd_elist_prompt(elisti);
    pkadd_elist_prompt(elistu);

    if (pk_answer("Continue?", "y") == 0) {
        printf "Exiting...\n";
        return 255;
    }

    if (!pkadd_fetch(elistr, elisti, elistu, options)) {
        printf "Exiting...\n";
        return 255;
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
