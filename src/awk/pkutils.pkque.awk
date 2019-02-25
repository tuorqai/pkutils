
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function pkque_parse_arguments(argc, argv, options, query,    i, m) {
    for (i = 1; i < argc; i++) {
        if (argv[i] ~ /^-(s|-strict)$/) {
            options["strict"] = 1;
        } else if (argv[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(argv[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/)           options["root"]  = m[2];
            else if (m[1] ~ /^-r$|^--repo$/)      query["repo_id"] = query["repo_id"] "|" m[2];
            else if (m[1] ~ /^-e$|^--series$/)    query["series"]  = query["series"]  "|" m[2];
            else if (m[1] ~ /^-v$|^--version$/)   query["version"] = query["version"] "|" m[2];
            else if (m[1] ~ /^-a$|^--arch$/)      query["arch"]    = query["arch"]    "|" m[2];
            else if (m[1] ~ /^-t$|^--tag$/)       query["tag"]     = query["tag"]     "|" m[2];
            else if (m[1] ~ /^-d$|^--desc$/)      query["desc"]    = query["desc"]    "|" m[2];
            else {
                printf "Unrecognized option: %s\n", m[1];
                return 0;
            }
        } else {
            query["name"] = query["name"] "|" argv[i];
        }
    }

    for (i in query) {
        sub(/^\|/, "", query[i]);
    }

    return 1;
}

function pkque_print_package(pk, installed,    status) {
    status = pk_is_installed(pk, installed);

    if (status == 1) {
        status = "installed";
    } else if (status == 2) {
        status = "different version installed";
    }

    if (status) {
        printf "\n%s:%s/%s %s-%s-%s%s [%s]\n  %s\n",
            pk["repo_id"], pk["series"], pk["name"],
            pk["version"], pk["arch"], pk["build"], pk["tag"],
            status, pk["description"];
    } else {
        printf "\n%s:%s/%s %s-%s-%s%s\n  %s\n",
            pk["repo_id"], pk["series"], pk["name"],
            pk["version"], pk["arch"], pk["build"], pk["tag"],
            pk["description"];
    }
}

function pkque_query(results, query, dirs, options) {
    return pk_query(results, query, dirs["lib"] "/index.dat", options["strict"], 0);
}

function pkque_main(    i, dirs, options, query, packages, total_results, installed) {
    if (!pkque_parse_arguments(ARGC, ARGV, options, query)) {
        return 1;
    }

    pk_setup_dirs(dirs, options["root"]);

    if (!pk_check_dirs(dirs)) {
        printf "Run `pkupd' first.\n";
        return 0;
    }

    total_results = pkque_query(packages, query, dirs, options);
    if (total_results < 1) {
        printf "No packages found.\n";
        return 0;
    }

    pk_get_installed_packages(dirs, installed);

    for (i = 1; i <= total_results; i++) {
        pkque_print_package(packages[i], installed);
    }

    if (total_results > 3) {
        printf "\nTotal packages found: %d.\n", total_results;
    }

    printf "\n";

    return 0;
}

BEGIN {
    rc = pkque_main();
    exit rc;
}
