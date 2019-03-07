#
# Copyright (c) 2019 Valery Timiriliyev timiriliyev@gmail.com
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

# pkutils.argparser.awk
# Overengineered argument parser.

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
                f = 0;
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
            f = 0;
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
