
# --------------------------------
# -- usage
# --------------------------------
function usage(name, desc, usg,    i) {
    printf "%s (version %s)\n%s\n", name, pkutils_version_get(), desc;
    printf "usage: %s %s\n\n", name, usg;
    printf "Available options:\n\n";

    for (i = 1; i <= ARGS["length"]; i++) {
        printf("  ");
        if (ARGS[i]["short"] != "-") {
            printf("-%c", ARGS[i]["short"]);
            if (ARGS[i]["long"] != "--") {
                printf(", ");
            }
        }
        if (ARGS[i]["long"] != "--") {
            printf("%s", ARGS[i]["long"]);
            if (ARGS[i]["parm"]) {
                printf("=VALUE");
            }
        }
        printf("\n    %s\n\n", ARGS[i]["desc"]);
    }
}

# --------------------------------
# -- register_argument
# --------------------------------
function register_argument(short, long, funct, desc, parm,    k) {
    k = ++ARGS["length"];
    ARGS[k]["short"] = short;
    ARGS[k]["long"] = long;
    ARGS[k]["func"] = funct;
    ARGS[k]["desc"] = desc;
    ARGS[k]["parm"] = parm;
}

# --------------------------------
# -- parse_arguments3
# --------------------------------
function parse_arguments3(stray, flag,    i, j, k, t, a, s, f, p, v) {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] ~ /^-[^-]+$/) {
            t = split(ARGV[i], a, //);
            for (j = 2; j <= t; j++) {
                p = a[j];
                for (k = 1; k <= ARGS["length"]; k++) {
                    if (ARGS[k]["short"] == p) {
                        s = ARGS[k]["func"];
                        @s();
                        f = 65536;
                    }
                }
                if (f < 65536) {
                    printf "Unrecognized switch: -%s\n", a[j] >> "/dev/stderr";
                    return 0;
                }
            }
        } else if (ARGV[i] ~ /^--?.+$/) {
            split(ARGV[i], a, /=/);
            p = a[1];
            v = a[2];
            for (k = 1; k <= ARGS["length"]; k++) {
                if (ARGS[k]["long"] == p) {
                    s = ARGS[k]["func"];
                    if (ARGS[k]["parm"]) {
                        @s(v);
                    } else {
                        @s();
                    }
                    f = 65536;
                }
            }
            if (f < 65536) {
                printf "Unrecognized option: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            }
        } else {
            if (flag) {
                printf "Unrecognized argument: %s\n", ARGV[i] >> "/dev/stderr";
                return 0;
            } else {
                stray[++stray["length"]] = ARGV[i];
            }
        }
    }

    return 1;
}
