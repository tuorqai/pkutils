
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

function pkdat_parse_arguments(argc, argv, _options,    m) {
    for (i = 1; i < argc; i++) {
        if (argv[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(argv[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/) {
                options["root"] = m[2];
            } else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            _options["target"] = _options["target"] "|" argv[i];
        }
    }

    sub(/^\|/, "", _options["target"]);

    return 1;
}

function pkdat_query(dirs, target, _results,    miniquery) {
    miniquery["name"] = target;
    return pk_query(_results, miniquery, dirs["lib"] "/index.dat", 1, 0);
}

function pkdat_query2(_results, dirs, target, db,    miniquery) {
    miniquery["name"] = target;
    pk_query2(_results, miniquery, db, 1, 0);
}

function pkdat_main(    i, j, dirs, options, db, results, names, total_names) {
    if (!pkdat_parse_arguments(ARGC, ARGV, options)) {
        return 255;
    }

    pk_setup_dirs(dirs, options["root"]);
    if (!pk_check_dirs(dirs)) {
        printf "Run `pkupd' first.\n";
        return 0;
    }

    pk_make_database(db, dirs);
    pkdat_query2(results, dirs, options["target"], db);
    if (results["length"] < 1) {
        printf "No packages found.\n";
        return 0;
    }

    total_names = split(options["target"], names, /\|/);

    for (j = 1; j <= total_names; j++) {
        printf "\n";
        printf "Package name: %s\n", names[j];

        for (i = 1; i <= results["length"]; i++) {
            if (results[i]["name"] != names[j]) {
                continue;
            }
            printf "-- %s/%s:%s-%s-%s%s\n", results[i]["repo_id"],
                results[i]["series"], results[i]["version"],
                results[i]["arch"], results[i]["build"], results[i]["tag"];
        }
    }

    printf "\n";

    return 0;
}

BEGIN {
    rc = pkdat_main();
    exit rc;
}
