--This is a custom snort3 lua file for use with either the Building Virtual Machine Labs: A Hands-On Guide (Second Edition) or the Applied Network Defense Training
--These configuration lines will perform the following tasks:
--enables tbe built-in preproc rules, and snort.rules file
--enables hyperscan as the search engine for pattern matching
--enables the DAQ for inline mode between snort_iface_1 and snort_iface_2 (defined in the full_autosnort.conf file)
--enables the IP reputation blacklist
--4/29:Reputation config is broken. Opened an issue on github because I think its a bug. Worked on 3.1.3.0, and suddenly stopped working on 3.1.4.0
--enables JSON alerting for snort alerts
--enables appid, the appid listener, and logging appid events.

ips =
{
    enable_builtin_rules = true,

    include = "/usr/local/etc/rules/snort.rules",

    variables = default_variables
}

search_engine = { search_method = "hyperscan" }

detection =
{
    hyperscan_literals = true,
    pcre_to_regex = true
}

daq =
{
    module_dirs =
    {
        '/usr/local/lib/daq',
    },
    modules =
    {
        {
            name = 'afpacket',
            mode = 'inline',
            variables =
            {
                'fanout_type=hash'
            }
        }
    },
    inputs =
    {
        'snort_iface1:snort_iface2',
    }
}

reputation =
{
    blocklist = '/usr/local/etc/lists/default.blocklist',
}

alert_json =
{
    file = true,
    limit = 1000,
    fields = 'seconds action class b64_data dir dst_addr dst_ap dst_port eth_dst eth_len \
    eth_src eth_type gid icmp_code icmp_id icmp_seq icmp_type iface ip_id ip_len msg mpls \
    pkt_gen pkt_len pkt_num priority proto rev rule service sid src_addr src_ap src_port \
    target tcp_ack tcp_flags tcp_len tcp_seq tcp_win tos ttl udp_len vlan timestamp',
}

appid =
{
    app_detector_dir = '/usr/local/lib',
}

appid_listener =
{
    json_logging = true,
    file = "/var/log/snort/appid-output.log",
}