#!/usr/bin/gawk -f

function setup_dirs(dirs, root) {
    dirs["root"] = root
    dirs["lib"] = root "/var/lib/pkutils"
    dirs["cache"] = root "/var/cache/pkutils"
    dirs["etc"] = root "/etc/pkutils"

    if (system("mkdir -p " dirs["lib"]) != 0) return 0
    if (system("mkdir -p " dirs["cache"]) != 0) return 0
}

function make_current_state(dirs, installed,    cmd, line, m) {
    cmd = "find "dirs["root"]"/var/log/packages -type f -printf \"%f\n\""

    while ((cmd | getline line) > 0) {
        match(line, /^(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)$/, m)
        installed[m[1]]["name"] = m[1]
        installed[m[1]]["version"] = m[2]
        installed[m[1]]["arch"] = m[3]
        installed[m[1]]["build"] = m[4]
        installed[m[1]]["tag"] = m[5]
    }
    close(cmd)
}

function parse_repos_list(repos_list_file, repos,    n, m, name) {
    FS = " "; RS = "\n";

    while ((getline < repos_list_file) > 0) {
        if ((NF == 3) && ($0 ~ /^(pk|sb)/)) {
            name = $2;
            repos[name]["name"] = name;
            repos[name]["type"] = $1;

            match($3, /(https?|ftp|rsync|file):\/\/([^\/]*)\/(.*)/, m);
            repos[name]["url_scheme"] = m[1];
            repos[name]["url_host"] = m[2];
            repos[name]["url_path"] = m[3];

            repos[name]["dir"] = dirs["lib"]"/repo_"name;
            repos[name]["cache"] = dirs["cache"]"/"name;

            system("mkdir -p "repos[name]["dir"]);
            system("mkdir -p "repos[name]["cache"]);

            n++;
        }
    }

    close(repos_list_file);
    return n;
}

function check_md5sum(file, md5sum) {
    if (!file || !md5sum) {
        return 0;
    }

    cmd = sprintf("echo %s %s | /usr/bin/md5sum --check >/dev/null 2>&1", md5sum, file);
    if (system(cmd) == 0) {
        return 1;
    }

    return 0;
}

#
# Return 1 on failure, 0 on success
#
function fetch_file(scheme, host, path, output, md5sum,    cmd) {
    if (md5sum > 0 && check_md5sum(output, md5sum)) {
        printf "File %s is downloaded already.\n", output;
        return 0;
    }

    if (scheme ~ /https?|ftp/) {
        print "host: "host";"
        print "path: "path";"
        if (system("/usr/bin/wget -t 0 -c -O "output" "scheme"://"host"/"path) > 0) {
            print "Failed to download "scheme"://"host"/"path"!" > "/dev/stderr"
            return 1
        }
    } else if (scheme ~ /file|cdrom/) {
        if (host > 0) {
            print "-- Only local machine for file:// is supported." > "/dev/stderr"
            return 1
        }

        print "Linking /"path" to "output"..."
        if (system("ln -sf /"path" "output) > 0) {
            print "Failed to link!"
            return 1
        }
    } else {
        print "Internal error: Bad protocol "scheme"!" > "/dev/stderr"
        return 1
    }

    if (md5sum == 0 || check_md5sum(output, md5sum)) {
        return 0;
    }

    printf "Error: wrong MD5 checksum.\n" >> "/dev/stderr";
    return 1;
}

function copy_array(dest, src,    j) { for (j in src) dest[j] = src[j]; }