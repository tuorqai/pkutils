
@include "pkutils.foundation.awk"
@include "pkutils.query.awk"

# --------------------------------
# -- is_dependency_here
# Obidno, chto seiceas eta functia
# prosto legit bez dela.
# --------------------------------
function is_dependency_here(p, dlist,    i) {
    for (i = 1; i <= dlist["length"]; i++) {
        if (dlist[i] == p) {
            return 1;
        }
    }
    return 0;
}

# --------------------------------
# -- dqueue_push
# --------------------------------
function dqueue_push(dqueue, p,    k) {
    k = ++dqueue["length"];
    dqueue[k] = p;
}

# --------------------------------
# -- dqueue_pop
# --------------------------------
function dqueue_pop(dqueue,    k) {
    k = dqueue["length"]--;
    delete dqueue[k];
}

# --------------------------------
# -- is_in_queue
# --------------------------------
function is_in_queue(dqueue, p,    k) {
    k = dqueue["length"];
    while (k >= 1) {
        if (dqueue[k--] == p) {
            return 1;
        }
    }
    return 0;
}

# --------------------------------
# -- add_to_dependency_list
# Pomni, chto eta functia - recursivnaya.
# 4. argument ispolhzuetsea pri
# recursivnom vhizove.
# --------------------------------
# Renamed this function since it's purpose
# is slightly changed.
# --------------------------------
function add_to_dependency_list(p, dlist,    dqueue, i, k, d, deps, total) {
    dqueue_push(dqueue, p);

    total = split(DB[p]["required"], deps, /,/);
    for (i = 1; i <= total; i++) {
        # ubrath vsiu informatiu o versiach, t.c. sil net eto poddergivath
        sub(/[<>=][A-Za-z0-9\.]$/, "", deps[i]);

        # v SlackBuild'ax eto vstreceaetsea ceastenhco
        if (deps[i] == "%README%") {
            printf "WARNING: you should read README file for %s package!\n",
                DB[p]["name"] >> "/dev/stderr";
            # `break' zdesh facticeschi raven dobavleniu tecuscego packeta v spisoc
            break;
        }

        # teperh nughno polucith index zavisimosti v obsceache
        d = db_get_by_name(deps[i], OPTIONS["cordial_deps"] ? DB[p]["repo_id"] : "");
        if (d == 0) {
            printf "Warning: can't find dependency %s for %s\n",
                deps[i], DB[p]["name"] >> "/dev/stderr";
            break;
        }

        # primitivnaya systema opredelenia cycliceschix zavisimostei
        # na osnove obhichnoi oceredi
        if (is_in_queue(dqueue, d)) {
            printf "Warning: found dependency loop: %s <- ", DB[d]["name"] >> "/dev/stderr";
            for (k = dqueue["length"]; k >= 1; k--) {
                printf "%s", DB[dqueue[k]]["name"] >> "/dev/stderr";
                if (dqueue[k] == d) {
                    break;
                }
                printf " <- " >> "/dev/stderr";
            }
            printf "\n" >> "/dev/stderr";
            break;
        }

        # i sleduet recursia...
        add_to_dependency_list(d, dlist,    dqueue);
    }

    # TODO: vnimatelhnhy citatelh mog zametith, chto zavisimosti dobavleayutsea
    # v spisoc bez proverchi, chto oni uge tam, to esth v sloghnhix sluceayax
    # (naprimer, pandoc iz SBo) spisoc razbuxaet do nevidannhix masxhtabof.
    # Neobxodimo cachim-to obrazom eto delo ispravith. Nayvnhie pophitchi
    # provereath eto prosthim sposobom terpeat fiasco.

    k = ++dlist["length"];
    dlist[k] = p;
    dlist[k, "level"] = dqueue["length"] - 1;

    dqueue_pop(dqueue);
}
