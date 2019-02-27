
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

function pkque_print_package(pk) {
    printf "\n%s:%s/%s %s-%s-%s%s\n  %s\n",
        pk["repo_id"], pk["series"], pk["name"],
        pk["version"], pk["arch"], pk["build"], pk["tag"],
        pk["description"];
}

function pkque_query(_results, query, db, dirs, options) {
    return pk_query2(_results, query, db, options["strict"], 0);
}

function pkque_main(    i, dirs, options, query, packages, db) {
    if (!pkque_parse_arguments(ARGC, ARGV, options, query)) {
        return 1;
    }

    pk_setup_dirs(dirs, options["root"]);
    if (!pk_check_dirs(dirs)) {
        printf "Run `pkupd' first.\n";
        return 0;
    }

    pk_make_database(db, dirs);
    pkque_query(packages, query, db, dirs, options);
    if (packages["length"] < 1) {
        printf "No packages found.\n";
        return 0;
    }

    for (i = 1; i <= packages["length"]; i++) {
        pkque_print_package(packages[i]);
    }

    if (packages["length"] > 5) {
        printf "\nTotal packages found: %d.\n", packages["length"];
    }

    printf "\n";

    return 0;
}

BEGIN {
    rc = pkque_main();
    exit rc;
}
