
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"
@include "pkutils.deps.awk"

function pkadd_parse_arguments(queries,    i, m) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^=]+$/) {
            if (ARGV[i] ~ /^(-u|--upgrade)$/) {
                OPTIONS["upgrade"] = 1;
            } else if (ARGV[i] ~ /^(-f|--reinstall)$/) {
                OPTIONS["force"] = 1;
            } else if (ARGV[i] ~ /^(-d|--dry-run)$/) {
                OPTIONS["dryrun"] = 1;
            } else if (ARGV[i] ~ /^(--enable-deps)$/) {
                OPTIONS["use_deps"] = 1;
            } else if (ARGV[i] ~ /^(--disable-deps)$/) {
                OPTIONS["use_deps"] = 0;
            } else if (ARGV[i] ~ /^(-F|--fetch)$/) {
                OPTIONS["fetch_only"] = 1;
            } else {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            }
        } else if (ARGV[i] ~ /^-([^=]+)=([^=]+)$/) {
            match(ARGV[i], /^([^=]+)=([^=]+)$/, m);

            if (m[1] ~ /^-R$|^--root$/) {
                OPTIONS["root"]  = m[2];
            } else {
                printf "Unrecognized option: %s\n", m[1] >> "/dev/stderr";
                return 0;
            }
        } else {
            queries[++queries["length"]] = ARGV[i];
        }
    }

    return 1;
}

function pkadd_elist_process(elist,    i) {
    if (elist["count"] == 0) {
        return;
    }

    if (OPTIONS["root"]) {
        elist["command"] = sprintf("%s --root %s", elist["command"], OPTIONS["root"]);
    }

    for (i = 1; i <= elist["count"]; i++) {
        if (OPTIONS["dryrun"]) {
            printf ">> %s %s\n", elist["command"], elist["packages"][i]["file"];
            continue;
        }

        system(elist["command"] " " elist["packages"][i]["file"]);
    }
}

function elist_add_package(self, p,    k) {
    for (k = 1; k <= self["length"]; k++) {
        if (self[k] == p) {
            return;
        }
    }

    k = ++self["length"];
    self[k] = p;
    self[k, "tar"] = db_get_tar_name(DB[p]);
    self[k, "hint"] = "N/A";
}

function elist_prompt(self,    i) {
    if (self["length"] == 0) {
        return;
    }

    printf "\n%d package(s) will be %s:\n", self["length"], self["action"];
    for (i = 1; i <= self["length"]; i++) {
        printf "-- %s (%s)\n", DB[self[i]]["name"], self[i, "hint"];
    }
}

function fetch_package(pk, tar,    i, r) {
    for (i = 1; i <= REPOS["length"]; i++) {
        if (REPOS[i]["name"] == pk["repo_id"]) {
            r = i;
            break;
        }
    }

    if (!r) {
        printf "Error: no repo %s\n", pk["repo_id"] > "/dev/stderr";
        return 1;
    }

    pk_url_path = sprintf("%s/%s/%s", REPOS[r]["url_path"], pk["location"], tar);
    pk_output = sprintf("%s/%s", REPOS[r]["cache"], tar);

    return pk_fetch_file(REPOS[r]["url_scheme"], REPOS[r]["url_host"],
        pk_url_path, pk_output, pk["checksum"]);
}

function elist_fetch(self,    i, p, failed) {
    for (i = 1; i <= self["length"]; i++) {
        p = self[i];
        failed += fetch_package(DB[p], self[i, "tar"]);
    }
    return failed;
}

function pkadd_main(    queries, results, er, eu, ei) {
    if (!pkadd_parse_arguments(queries)) {
        return 255;
    }

    pk_setup_dirs(OPTIONS["root"]);
    if (!pk_check_dirs()) {
        printf "Run `pkupd' first!\n";
        return 255;
    }
    pk_parse_options();

    printf "Reading packages index...";
    db_rebuild();
    printf " Done.\n";

    db_query(results, queries);
    if (results["length"] <= 0) {
        printf "No packages found.\n";
        return 0;
    }

    pk_parse_repos_list();

    er["action"] = "REINSTALLED";
    eu["action"] = "UPGRADED";
    ei["action"] = "INSTALLED";

    for (i = 1; i <= results["length"]; i++) {
        printf "Calculating dependencies for %s...\n", db_get_full_name(DB[results[i]]);
        delete dlist;
        make_dependency_list(results[i], dlist);
        printf "Done!\n";
        for (j = 1; j <= dlist["length"]; j++) {
            p = dlist[j];
            status = db_is_installed(p);
            if (status == 1) {
                if (OPTIONS["force"]) {
                    elist_add_package(er, p);
                } else {
                    printf "Package %s (%s) installed already.\n", DB[p]["name"], DB[p]["version"];
                }
            } else if (status > 65535) {
                elist_add_package(eu, status - 65535);
            } else {
                if (!OPTIONS["upgrade"]) {
                    elist_add_package(ei, p);
                }
            }
        }
    }

    if (er["length"] == 0 && eu["length"] == 0 && ei["length"] == 0) {
        printf "Nothing to do.\n";
        return 0;
    }

    elist_prompt(er);
    elist_prompt(eu);
    elist_prompt(ei);

    if (pk_answer("\nContinue?", "y") == 0) {
        printf "Exiting...\n";
        return 255;
    }

    failed += elist_fetch(er);
    failed += elist_fetch(eu);
    failed += elist_fetch(ei);

    if (failed > 0) {
        printf "Exiting...\n";
        return 255;
    }

    if (OPTIONS["fetch_only"]) {
        return 0;
    }

    return 0;
}

BEGIN {
    rc = pkadd_main();
    exit rc;
}
