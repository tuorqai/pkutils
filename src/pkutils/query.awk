
function do_query(index_dat, query, results, search_mode,    n, got, stash) {
    FS = ":"; RS = "\n";

    while ((getline < index_dat) > 0) {
        got["repo_id"]  = $2;
        got["location"] = $6;
        got["series"]   = $7;
        got["name"]     = $8;
        got["version"]  = $9;
        got["arch"]     = $10;
        got["build"]    = $11;
        got["tag"]      = $12;
        got["type"]     = $13;
        got["checksum"] = $14;

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