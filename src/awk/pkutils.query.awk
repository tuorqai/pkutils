
function do_query(index_dat, query, results, search_mode, strict,    j, n, got, stash) {
    FS = ":"; RS = "\n";

    if (strict) for (j in query) query[j] = "^" query[j] "$";

    while ((getline < index_dat) > 0) {
        got["repo_id"]  = $1;
        got["location"] = $2;
        got["series"]   = $3;
        got["name"]     = $4;
        got["version"]  = $5;
        got["arch"]     = $6;
        got["build"]    = $7;
        got["tag"]      = $8;
        got["type"]     = $9;
        got["checksum"] = $10;

        if (got["repo_id"]   ~ query["repo_id"]  &&
            got["series"]    ~ query["series"]   &&
            got["name"]      ~ query["name"]     &&
            got["version"]   ~ query["version"]  &&
            got["arch"]      ~ query["arch"]     &&
            got["tag"]       ~ query["tag"])
        {
            if (!search_mode) {
                if (got["name"] in stash) continue;
                stash[got["name"]] = 1;
            }

            n++;
            results[n]["repo_id"]     = got["repo_id"];
            results[n]["location"]    = got["location"];
            results[n]["series"]      = got["series"];
            results[n]["name"]        = got["name"];
            results[n]["version"]     = got["version"];
            results[n]["arch"]        = got["arch"];
            results[n]["build"]       = got["build"];
            results[n]["tag"]         = got["tag"];
            results[n]["type"]        = got["type"];
            results[n]["checksum"]    = got["checksum"];
        }
    }
    close(index_dat);
    return n;
}