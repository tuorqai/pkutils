
function setup_dirs(dirs, root, user) {
    dirs["root"]    = root;
    dirs["lib"]     = sprintf("%s/var/lib/pkutils", root);
    dirs["cache"]   = sprintf("%s/var/cache/pkutils", root);
    dirs["etc"]     = sprintf("%s/etc/pkutils", root);

    if (user)
        return 1;

    if (system("mkdir -p " dirs["lib"]) != 0) return 0;
    if (system("mkdir -p " dirs["cache"]) != 0) return 0;

    return 1;
}

function make_current_state(dirs, installed,    cmd, name, m) {
    cmd = sprintf("find %s/var/log/packages -type f -printf \"%%f\n\"", dirs["root"]);
    while ((cmd | getline) > 0) {
        match($0, /^(.*)-([^-]*)-([^-]*)-([0-9])([^-]*)$/, m);
        name = m[1];
        installed[name]["name"]     = m[1];
        installed[name]["version"]  = m[2];
        installed[name]["arch"]     = m[3];
        installed[name]["build"]    = m[4];
        installed[name]["tag"]      = m[5];
    }
    close(cmd);
}

function parse_repos_list(repos_list_file, repos,    idx, m, name) {
    FS = " "; RS = "\n";

    idx = 1;

    while ((getline < repos_list_file) > 0) {
        if ((NF == 3) && ($0 ~ /^(pk|sb)/)) {
            repos[idx]["name"] = $2;
            repos[idx]["type"] = $1;

            match($3, /(https?|ftp|rsync|file):\/\/([^\/]*)\/(.*)/, m);
            repos[idx]["url_scheme"] = m[1];
            repos[idx]["url_host"] = m[2];
            repos[idx]["url_path"] = m[3];

            repos[idx]["dir"] = sprintf("%s/repo_%s", dirs["lib"], repos[idx]["name"]);
            repos[idx]["cache"] = sprintf("%s/%s", dirs["cache"], repos[idx]["name"]);

            system(sprintf("mkdir -p %s", repos[idx]["dir"]));
            system(sprintf("mkdir -p %s", repos[idx]["cache"]));

            idx++;
        }
    }

    close(repos_list_file);
}

function parse_lock_list(holdlist_file, holdlist,    i) {
    FS = " "; RS = "\n";

    while ((getline < holdlist_file) > 0) {
        i++;
        holdlist[i]["name"]      = "^" $1 "$";
        holdlist[i]["version"]   = "^" $2 "$";
        holdlist[i]["arch"]      = "^" $3 "$";
        holdlist[i]["build"]     = "^" $4 "$";
        holdlist[i]["tag"]       = "^" $5 "$";
    }
    close(holdlist_file);
}

function check_md5sum(file, md5sum) {
    if (!file || !md5sum)
        return 0;
    cmd = sprintf("echo %s %s | /usr/bin/md5sum --check >/dev/null 2>&1", md5sum, file);
    if (system(cmd) == 0)
        return 1;
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
        if (system(sprintf("test -L %s", output)) == 0) {
            printf "Found symbolic link %s. Removing...\n", output;
            system(sprintf("rm -rf %s", output));
        }

        cmd = sprintf("/usr/bin/wget -O %s %s://%s/%s", output, scheme, host, path);
        if (system(cmd) > 0) {
            printf "Failed to download %s://%s/%s!\n", scheme, host, path > "/dev/stderr";
            return 1;
        }
    } else if (scheme ~ /file|cdrom/) {
        if (host > 0) {
            printf "-- Only local machine for file:// is supported.\n" > "/dev/stderr";
            return 1;
        }

        printf "Linking /%s to %s...\n", path, output;
        cmd = sprintf("ln -sf /%s %s", path, output);
        if (system(cmd) > 0) {
            printf "Failed to link!\n"
            return 1;
        }
    } else {
        printf "Internal error: Bad URL scheme \"%s\"!\n", scheme > "/dev/stderr";
        return 1;
    }

    if (md5sum == 0 || check_md5sum(output, md5sum)) {
        return 0;
    }

    printf "Error: wrong MD5 checksum.\n" >> "/dev/stderr";
    return 1;
}

# function copy_array(dest, src,    j) { for (j in src) dest[j] = src[j]; }