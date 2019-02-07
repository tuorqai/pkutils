BEGIN {
    OFS = ":"
}

/^(pk|sb)/ && NF == 3 {
    RP_TYPE = $1
    RP_NAME = $2
    RP_URL = $3
    match(RP_URL, /(https?|ftp|rsync|file):\/\/([^\/]*)\/(.*)/, MATCH)

    RP_PROTOCOL = MATCH[1]
    RP_SERVER = MATCH[2]
    RP_ADDRESS = MATCH[3]

    # RP_NAME = toupper(RP_SERVER)"@"RP_ADDRESS
    # gsub(/\/|\.|:/, "_", RP_NAME)

    print RP_TYPE, RP_NAME, RP_PROTOCOL, RP_SERVER, RP_ADDRESS
}
